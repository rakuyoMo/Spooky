import Foundation

// MARK: - HostDirectoryEntry

/// 目录浏览里的一个子目录。
public struct HostDirectoryEntry: Sendable, Hashable {
    /// 目录名。
    public let name: String

    /// 绝对路径。
    public let path: String

    /// 登录用户能否打开并列出这个目录。
    public let isReadable: Bool

    /// 目录里有 `.git`（目录或文件），即已是 Git 工作区。
    public let isRepository: Bool
}

// MARK: - HostPathStatus

/// 目标路径在所在机器上的情况，新建与克隆前据此判断能否使用。
public struct HostPathStatus: Sendable, Equatable {
    /// 路径存在；符号链接按它指向的目标判断。
    public let exists: Bool

    /// 路径是目录。
    public let isDirectory: Bool

    /// 目录能打开列出，文件能读取。
    public let isReadable: Bool

    /// 登录用户能在这里写入。
    public let isWritable: Bool

    /// 是目录，且除 “.” 与 “..” 外没有任何条目。
    public let isEmpty: Bool

    /// 目录里有 `.git`，即已是 Git 工作区。
    public let isRepository: Bool
}

// MARK: - HostDirectories

/// 仓库还不存在时浏览与检查目标机器上的目录；服务器经主机连接在 B 上执行，取消所在的任务即停止。
public enum HostDirectories {
    /// 列出目录里的子目录：每条记录是可读、Git 工作区两个 0 / 1 标记加目录名，以 NUL 结尾。
    ///
    /// 退出码沿用目录检查的约定：2 不存在、3 不能读取、4 不是目录。
    static let listScript = """
        my ($directory) = @ARGV;
        -e $directory or do { print STDERR "No such file or directory\\n"; exit 2 };
        -d _ or do { print STDERR "Not a directory\\n"; exit 4 };
        opendir(my $handle, $directory) or do { print STDERR "$!\\n"; exit 3 };
        while (defined(my $name = readdir $handle)) {
            next if $name eq '.' || $name eq '..';
            my $path = "$directory/$name";
            next unless -d $path;
            my $readable = opendir(my $child, $path) ? 1 : 0;
            my $repository = -e "$path/.git" ? 1 : 0;
            print $readable, $repository, $name, "\\0";
        }
        """

    /// 输出一行六个 0 / 1 标记：存在、目录、可读、可写、空目录、Git 工作区。
    static let statusScript = """
        my ($path) = @ARGV;
        my $exists = -e $path ? 1 : 0;
        my $directory = -d $path ? 1 : 0;
        my $writable = -w $path ? 1 : 0;
        my $repository = -e "$path/.git" ? 1 : 0;
        my ($readable, $empty) = (0, 0);
        if ($directory) {
            if (opendir(my $handle, $path)) {
                ($readable, $empty) = (1, 1);
                while (defined(my $name = readdir $handle)) {
                    next if $name eq '.' || $name eq '..';
                    $empty = 0;
                    last;
                }
            }
        } else {
            $readable = -r $path ? 1 : 0;
        }
        print $exists, $directory, $readable, $writable, $empty, $repository, "\\n";
        """

    /// 列出目录里的子目录，按名称排序；文件与 “.”、“..” 不列出，隐藏目录照常列出。
    ///
    /// - Parameter directory: 本机或服务器上的目录，路径必须是绝对路径。
    /// - Throws: 目录不存在、不是目录或不能读取时抛出 ``HostOperationError``。
    public static func list(_ directory: RepositoryLocation) async throws -> [HostDirectoryEntry] {
        let path = try HostOperationError.normalized(directory.path)

        do {
            let result = try await HostExecution.run(
                ["/usr/bin/perl", "-e", listScript, "--", path],
                at: location(directory, path: path)
            )
            return parseList(result.standardOutput, in: path)
        } catch {
            throw HostOperationError.classify(error)
        }
    }

    /// 检查路径的存在性与权限，不存在不算错误。
    ///
    /// - Parameter location: 本机或服务器上的路径，必须是绝对路径。
    public static func status(of location: RepositoryLocation) async throws -> HostPathStatus {
        let path = try HostOperationError.normalized(location.path)
        let result = try await HostExecution.run(
            ["/usr/bin/perl", "-e", statusScript, "--", path],
            at: Self.location(location, path: path)
        )

        guard let status = parseStatus(result.standardOutput) else {
            throw RepositoryReadError.malformedOutput("status-script")
        }

        return status
    }

    /// 解析列目录脚本的输出，按名称的本地化标准顺序排序。
    static func parseList(_ data: Data, in directory: String) -> [HostDirectoryEntry] {
        let prefix = directory == "/" ? "/" : directory + "/"

        return data
            .split(separator: 0)
            .compactMap { record -> HostDirectoryEntry? in
                guard record.count > 2 else { return nil }

                let flags = Array(record.prefix(2))
                let name = String(decoding: record.dropFirst(2), as: UTF8.self)

                return HostDirectoryEntry(
                    name: name,
                    path: prefix + name,
                    isReadable: flags[0] == UInt8(ascii: "1"),
                    isRepository: flags[1] == UInt8(ascii: "1")
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 解析路径检查脚本的一行标记；格式不符时返回 nil。
    static func parseStatus(_ data: Data) -> HostPathStatus? {
        let flags = Array(data)

        guard
            flags.count == 7, flags[6] == 10,
            flags.prefix(6).allSatisfy({ $0 == UInt8(ascii: "0") || $0 == UInt8(ascii: "1") })
        else { return nil }

        let value = flags.prefix(6).map { $0 == UInt8(ascii: "1") }

        return HostPathStatus(
            exists: value[0],
            isDirectory: value[1],
            isReadable: value[2],
            isWritable: value[3],
            isEmpty: value[4],
            isRepository: value[5]
        )
    }

    /// 用规范后的路径替换位置里的路径，机器不变。
    private static func location(_ location: RepositoryLocation, path: String) -> RepositoryLocation {
        guard let host = location.host else { return .local(path: path) }
        return .remote(host: host, path: path)
    }
}
