import AppKit
import SpookyKit
import UniformTypeIdentifiers

// MARK: - WorkingCopyFileDrag

/// 应用内拖动的一个工作区文件：所在仓库与仓库内路径，供应用内的落点识别来源。
struct WorkingCopyFileDrag: Codable {
    /// 拖动类型，内容是本结构的 UTF-8 JSON；其它程序不认识这个类型。
    static let type = NSPasteboard.PasteboardType("com.rakuyo.spooky.working-copy-file")

    /// 文件所在的仓库。
    let repository: RepositoryLocation

    /// 仓库内的相对路径。
    let path: String
}

// MARK: - Dragging Source

extension WorkingCopyFileList.Coordinator {
    /// 每个文件一项：本机文件写文件 URL，服务器文件写 file promise，都附带相对路径与应用内类型；目录行不拖动。
    func outlineView(_: NSOutlineView, pasteboardWriterForItem item: Any) -> (any NSPasteboardWriting)? {
        guard
            let node = item as? WorkingCopyFileList.Node,
            let entry = node.entry,
            let repository = session.repository
        else { return nil }

        let payload = try? JSONEncoder().encode(WorkingCopyFileDrag(repository: repository, path: entry.path))

        // 服务器文件交给落点之前要先取到本机，用 file promise 延后到落下时再传输
        if repository.host != nil, entry.isOpenable, let cache = session.fileCache {
            return WorkingCopyFilePromise(path: entry.path, payload: payload, cache: cache)
        }

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(entry.path, forType: .string)

        // 已删除的文件只有相对路径
        if let root = repository.localURL, entry.isOpenable {
            pasteboardItem.setString(root.appending(path: entry.path).absoluteString, forType: .fileURL)
        }

        if let payload {
            pasteboardItem.setData(payload, forType: WorkingCopyFileDrag.type)
        }

        return pasteboardItem
    }
}

// MARK: - WorkingCopyFilePromise

/// 服务器文件的拖出：落点给出目标位置后，先经 SFTP 取到会话缓存，再复制过去，远端路径不交给落点。
final class WorkingCopyFilePromise: NSFilePromiseProvider, NSFilePromiseProviderDelegate {
    /// 仓库内的相对路径。
    private let path: String

    /// 应用内拖动类型的内容。
    private let payload: Data?

    /// 会话的本机副本缓存。
    private let cache: RepositoryFileCache

    /// 按文件扩展名登记类型，落点据此决定是否接受。
    init(path: String, payload: Data?, cache: RepositoryFileCache) {
        self.path = path
        self.payload = payload
        self.cache = cache
        super.init()

        let suffix = WorkingCopyOperations.pathExtension(of: WorkingCopyFileList.fileName(of: path))
        fileType = (UTType(filenameExtension: suffix) ?? .data).identifier
        delegate = self
    }

    /// 在 file promise 之外再提供相对路径与应用内类型。
    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        super.writableTypes(for: pasteboard) + [.string] + (payload == nil ? [] : [WorkingCopyFileDrag.type])
    }

    /// 相对路径与应用内类型的内容，其余类型交给 file promise。
    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .string:
            path

        case WorkingCopyFileDrag.type:
            payload

        default:
            super.pasteboardPropertyList(forType: type)
        }
    }

    /// 落点创建的文件沿用原文件名。
    @MainActor
    func filePromiseProvider(_: NSFilePromiseProvider, fileNameForType _: String) -> String {
        WorkingCopyFileList.fileName(of: path)
    }

    /// 先取到会话缓存，再复制到落点给出的位置。
    func filePromiseProvider(
        _: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping @Sendable (Error?) -> Void
    ) {
        let path = path
        let cache = cache

        Task {
            do {
                let local = try await cache.workingTreeFile(path)
                try FileManager.default.copyItem(at: local, to: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
