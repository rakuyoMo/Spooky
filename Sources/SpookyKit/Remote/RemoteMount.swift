import Darwin
import Foundation

// MARK: - RemoteMount

/// B 上的一个目录在这台 Mac 上的位置：B 的目录经 SMB、NFS、AFP、WebDAV 或 sshfs 挂载到本机后，Finder 只能打开本机路径。
public struct RemoteMount: Sendable, Equatable {
    /// B 上的目录，不带末尾的 `/`；B 的根目录写作 `/`。
    public let remotePath: String

    /// 这个目录在这台 Mac 上的路径。
    public let localURL: URL

    /// 记下一组对应的目录。
    ///
    /// - Parameters:
    ///   - remotePath: B 上的绝对路径。
    ///   - localURL: 它在这台 Mac 上的目录。
    public init(remotePath: String, localURL: URL) {
        let components = remotePath.split(separator: "/")
        self.remotePath = "/" + components.joined(separator: "/")
        self.localURL = localURL
    }

    /// 把 B 上这个目录里的路径换算成本机路径；不在这个目录里时为 nil。
    ///
    /// - Parameter path: B 上的绝对路径。
    public func localURL(for path: String) -> URL? {
        let normalized = "/" + path.split(separator: "/").joined(separator: "/")

        guard normalized != remotePath else {
            return localURL
        }

        let base = remotePath == "/" ? "/" : remotePath + "/"

        guard normalized.hasPrefix(base) else {
            return nil
        }

        return localURL.appending(path: String(normalized.dropFirst(base.count)))
    }
}

// MARK: - RemoteMountLocator

/// 在这台 Mac 挂载的网络卷里找 B 上的目录，并经标记文件核对确实是同一个目录。
///
/// 只比 `.git` 里的 HEAD 与 config 不够：两个新建的空仓库会被认成同一个，所以经 SSH 在 B 的 Git 目录里临时放一个随机命名的空文件，
/// 经本机路径看得到才算。
public struct RemoteMountLocator: Sendable {
    /// 核对用的标记文件名前缀，后接随机的 UUID。
    static let markerPrefix = ".spooky-mount-"

    /// 可能挂载了 B 的目录的本机卷根目录，按路径排序。
    private let volumes: @Sendable () async -> [URL]

    /// 查找主机别名所指的那台机器挂载到这台 Mac 上的卷。
    ///
    /// - Parameter host: `~/.ssh/config` 里的主机别名。
    public init(host: String) {
        volumes = { await Self.networkVolumes(of: host) }
    }

    /// 用给定的目录代替挂载卷，测试用临时目录模拟挂载。
    init(volumes: @escaping @Sendable () async -> [URL]) {
        self.volumes = volumes
    }

    /// 核对 B 上的目录在本机的位置：经 SSH 在它的 Git 目录里写一个随机命名的空文件，看本机对应的 Git 目录里有没有，最后删掉它。
    ///
    /// - Parameters:
    ///   - path: B 上带 `.git` 的目录。
    ///   - mount: 包含 `path` 的一组对应目录；`.git` 是文件时，其中 B 上的 Git 目录同样按它换算。
    ///   - runner: 这个目录所在仓库的执行器。
    /// - Returns: 本机看得到标记文件时为 true。
    public static func verify(_ path: String, through mount: RemoteMount, runner: GitRunner) async -> Bool {
        guard
            let local = mount.localURL(for: path),
            let localGitDirectory = localGitDirectory(of: local, through: mount),
            let output = try? await runner.run(["-C", path, "rev-parse", "--absolute-git-dir"])
        else { return false }

        let gitDirectory = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        guard gitDirectory.hasPrefix("/") else {
            return false
        }

        let marker = markerPrefix + UUID().uuidString
        let remoteMarker = gitDirectory + "/" + marker
        let localMarker = localGitDirectory.appending(path: marker)
        let files = RepositoryFiles(runner: runner)

        let written = (try? await files.write(Data(), to: remoteMarker)) != nil
        let found = written && FileManager.default.fileExists(atPath: localMarker.path)

        // 写入中途取消时文件也可能已经建好；删除放在不随调用方取消的任务里，核对失败同样删掉
        await Task {
            try? await files.remove([remoteMarker])
        }.value

        return found
    }

    /// 从 `ssh -G` 的输出里取出 `hostname` 一行的值；没有这一行时为 nil。
    ///
    /// - Parameter output: `ssh -G <别名>` 的标准输出，每行是小写的选项名、一个空格与值。
    static func hostname(fromConfiguration output: String) -> String? {
        output
            .split(whereSeparator: \.isNewline)
            .first { $0.hasPrefix("hostname ") }
            .map { String($0.dropFirst("hostname ".count)) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    /// 在这台 Mac 上找 B 上的目录：从最长的后缀试起，在每个卷的根下找带 `.git` 的目录，核对通过的第一个就是。
    ///
    /// - Parameters:
    ///   - path: B 上带 `.git` 的目录，如仓库根目录或工作树。
    ///   - runner: 这个目录所在仓库的执行器，标记文件经它写进 B 的 Git 目录。
    /// - Returns: 这个目录与它在本机的位置；没有挂载或核对不通过时为 nil。
    public func locate(_ path: String, runner: GitRunner) async -> RemoteMount? {
        let roots = await volumes()
        let components = path.split(separator: "/").map(String.init)

        for count in stride(from: components.count, to: 0, by: -1) {
            let prefix = "/" + components.dropLast(count).joined(separator: "/")

            for root in roots {
                let mount = RemoteMount(remotePath: prefix, localURL: root)

                guard
                    let local = mount.localURL(for: path),
                    Self.localGitDirectory(of: local, through: mount) != nil
                else { continue }

                if await Self.verify(path, through: mount, runner: runner) {
                    return RemoteMount(remotePath: path, localURL: local)
                }
            }
        }

        return nil
    }
}

// MARK: - Private

extension RemoteMountLocator {
    /// 本机目录对应的 Git 目录：`.git` 是目录时就是它；是文件（工作树、子模块）时按其中的 `gitdir:` 找，B 上的绝对路径按 `mount` 换算。
    private static func localGitDirectory(of directory: URL, through mount: RemoteMount) -> URL? {
        let dotGit = directory.appending(path: ".git")
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: dotGit.path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            return dotGit
        }

        // `.git` 文件只有一行 `gitdir: <路径>`，只读开头一小段
        guard
            let handle = try? FileHandle(forReadingFrom: dotGit),
            let data = try? handle.read(upToCount: 4096)
        else { return nil }

        try? handle.close()

        let line = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline).first ?? ""

        guard line.hasPrefix("gitdir: ") else {
            return nil
        }

        let target = String(line.dropFirst("gitdir: ".count))

        return target.hasPrefix("/")
            ? mount.localURL(for: target)
            : directory.appending(path: target)
    }

    /// 与主机别名同一台机器挂载到这台 Mac 上的网络卷：按 `ssh -G` 得到的主机与卷的重新挂载地址里的主机，比较解析出的地址。
    private static func networkVolumes(of host: String) async -> [URL] {
        guard
            let result = try? await CommandExecutor.execute(
                executable: "/usr/bin/ssh",
                processArguments: ["-G", "--", host],
                arguments: ["ssh", "-G"]
            ),
            let name = hostname(fromConfiguration: String(decoding: result.standardOutput, as: UTF8.self))
        else { return [] }

        let server = addresses(of: name)

        guard !server.isEmpty else {
            return []
        }

        let keys: Set<URLResourceKey> = [.volumeURLForRemountingKey, .volumeIsLocalKey]
        let mounted = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys)) ?? []

        return mounted
            .filter { volume in
                guard
                    let values = try? volume.resourceValues(forKeys: keys),
                    !(values.volumeIsLocal ?? true),
                    let remount = values.volumeURLForRemounting?.host(percentEncoded: false)
                else { return false }

                return !addresses(of: remount).isDisjoint(with: server)
            }
            .sorted { $0.path < $1.path }
    }

    /// 主机名解析出的全部地址，写成数字形式；解析不了时为空。
    private static func addresses(of name: String) -> Set<String> {
        var hints = addrinfo()
        hints.ai_socktype = SOCK_STREAM

        var list: UnsafeMutablePointer<addrinfo>? = nil

        guard getaddrinfo(name, nil, &hints, &list) == 0, let list else {
            return []
        }

        defer { freeaddrinfo(list) }

        var result: Set<String> = []

        for entry in sequence(first: list, next: { $0.pointee.ai_next }) {
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))

            let status = getnameinfo(
                entry.pointee.ai_addr,
                entry.pointee.ai_addrlen,
                &buffer,
                socklen_t(buffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            if status == 0 {
                let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                result.insert(String(decoding: bytes, as: UTF8.self))
            }
        }

        return result
    }
}
