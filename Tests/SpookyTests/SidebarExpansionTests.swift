import SpookyKit
import Testing
import TestSupport

@testable import Spooky

// MARK: - SidebarExpansionTests

/// 侧边栏按仓库记住展开状态：再打开仓库时回到上次的样子，过滤与拖动悬停的展开只是临时的。
@MainActor
struct SidebarExpansionTests {
    /// 本机仓库与同一路径的服务器仓库各记各的；换走再换回、重新打开都回到记下的状态，没有记录时用默认；
    /// 过滤时的改动不生效，拖动悬停的临时展开即使之后有别的改动记下也不进记录。
    @Test("按仓库记下与恢复展开状态，过滤与拖动悬停不记下")
    func remembersPerRepository() {
        let defaults = MemoryDefaults()

        let local = RepositoryLocation.local(path: "/tmp/仓库 “a”")
        let server = RepositoryLocation.remote(host: "spooky-test", path: "/tmp/仓库 “a”")
        let folder = SidebarNodeID(value: "branches|folder|feature")
        let origin = SidebarNodeID.remote("origin")
        let upstream = SidebarNodeID.remote("upstream")

        let expansion = SidebarExpansion()
        expansion.load(local, defaults: defaults)

        /// 不过滤时一个分组是否展开。
        func expanded(_ group: SidebarExpansion.Group) -> Bool {
            expansion.binding(for: group, filtering: false).wrappedValue
        }

        /// 不过滤时一个远端或文件夹是否展开。
        func expanded(_ node: SidebarNodeID) -> Bool {
            expansion.binding(for: node, filtering: false).wrappedValue
        }

        // 没有记录：Tags 收起，其余分组展开；远端只展开 origin，文件夹收起
        #expect(!expanded(.tags))
        #expect(expanded(.branches))
        #expect(expanded(origin))
        #expect(!expanded(upstream))
        #expect(!expanded(folder))

        // 拖动中悬停展开 upstream，之后展开 Tags 与文件夹、收起 origin，每次改动都立即记下
        expansion.springBinding(for: upstream, filtering: false).wrappedValue = true
        #expect(expanded(upstream))

        expansion.binding(for: .tags, filtering: false).wrappedValue = true
        expansion.binding(for: folder, filtering: false).wrappedValue = true
        expansion.binding(for: origin, filtering: false).wrappedValue = false

        // 过滤时固定展开，收起不生效，清空过滤后仍是记下的状态
        let filtered = expansion.binding(for: .branches, filtering: true)
        #expect(filtered.wrappedValue)
        filtered.wrappedValue = false
        #expect(expanded(.branches))

        // 换到同一路径的服务器仓库：键不同，没有记录，回到默认；收起 Branches 记在它自己的键下
        expansion.load(server, defaults: defaults)
        #expect(!expanded(.tags))
        #expect(expanded(origin))
        #expect(!expanded(folder))
        #expect(!expanded(upstream))

        expansion.binding(for: .branches, filtering: false).wrappedValue = false

        // 换回本机仓库：回到记下的状态，拖动悬停的临时展开不在其中
        expansion.load(local, defaults: defaults)
        #expect(expanded(.tags))
        #expect(expanded(.branches))
        #expect(expanded(folder))
        #expect(!expanded(origin))
        #expect(!expanded(upstream))

        // 重新打开（新的实例）：两个仓库都读出各自的记录
        let reopened = SidebarExpansion()

        reopened.load(local, defaults: defaults)
        #expect(reopened.binding(for: .tags, filtering: false).wrappedValue)
        #expect(reopened.binding(for: folder, filtering: false).wrappedValue)
        #expect(!reopened.binding(for: origin, filtering: false).wrappedValue)

        reopened.load(server, defaults: defaults)
        #expect(!reopened.binding(for: .branches, filtering: false).wrappedValue)
        #expect(!reopened.binding(for: .tags, filtering: false).wrappedValue)
    }
}
