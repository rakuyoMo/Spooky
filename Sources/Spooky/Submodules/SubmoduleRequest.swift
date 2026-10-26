import SpookyKit

// MARK: - SubmoduleRequest

/// 子模块的对话框与询问；菜单、侧边栏、子模块详情与写入失败共用，由仓库窗口以 sheet 呈现。
enum SubmoduleRequest {
    /// 添加子模块。
    case add

    /// 获取一个子模块；为 nil 时由对话框选择。
    case fetch(Submodule?)

    /// 更新一个子模块；为 nil 时由对话框选择。
    case update(Submodule?)

    /// 初始化子模块。
    case initialize(Submodule)

    /// 同步子模块的地址。
    case synchronize(Submodule)

    /// 移动子模块。
    case move(Submodule)

    /// 修改子模块名称。
    case rename(Submodule)

    /// 删除子模块。
    case delete(Submodule)

    /// 修复配置不完整的子模块。
    case repair(Submodule)

    /// 修改子模块在 `.gitmodules` 或本地配置里的地址。
    case editURL(Submodule, SubmoduleConfigurationScope)

    /// 普通删除遇到本地改动后，询问是否强制删除。
    case forceDelete(SubmoduleDeletionOffer)

    /// 添加时父仓库里已有同名子模块的 Git 目录，询问复用还是覆盖。
    case forceAdd(SubmoduleAdditionOffer)

    /// 操作改动了这些已初始化子模块的指针，询问是否更新它们。
    case autoUpdate([Submodule])
}

// MARK: - SubmoduleDeletionOffer

/// 普通删除因子模块里有本地改动而停下：带上原来的选项，询问后强制删除。
struct SubmoduleDeletionOffer: Error {
    /// 要删除的子模块。
    let submodule: Submodule

    /// 原来是否保留工作区。
    let keepsWorkingTree: Bool
}

// MARK: - SubmoduleAdditionOffer

/// 添加因已有同名 Git 目录而停下：带上原来的地址与路径，询问后复用或覆盖。
struct SubmoduleAdditionOffer: Error {
    /// 子模块仓库的地址。
    let url: String

    /// 工作区里的相对路径，也是子模块名称。
    let path: String
}
