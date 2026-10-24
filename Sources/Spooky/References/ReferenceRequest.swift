import SpookyKit

// MARK: - ReferenceRequest

/// 分支、标签与远端管理的对话框与询问；菜单、远端详情与写入失败共用，由仓库窗口以 sheet 呈现。
enum ReferenceRequest {
    /// 重命名本地分支或远端分支。
    case renameBranch(RepositoryReference)

    /// 删除若干本地分支。
    case deleteBranches([RepositoryReference])

    /// 在远端删除若干远端分支。
    case deleteRemoteBranches([RepositoryReference])

    /// 为本地分支选择父分支。
    case setParent(RepositoryReference)

    /// 新建标签；版本为 nil 时从 HEAD 开始。
    case createTag(revision: String?)

    /// 发布一个本地标签；标签为 nil 时由对话框选择，远端为 nil 时预选 HEAD 跟踪的远端。
    case publishTag(String?, remote: String? = nil)

    /// 删除若干本地标签，可选同时从远端删除。
    case deleteTags([String])

    /// 添加远端。
    case addRemote

    /// 重命名远端。
    case renameRemote(String)

    /// 删除若干远端。
    case deleteRemotes([String])

    /// 修改远端的获取地址或推送地址。
    case editURL(remote: String, push: Bool)

    /// 添加或修改远端的一条 refspec；原值为 nil 表示添加。
    case refspec(remote: String, push: Bool, original: String?)

    /// 普通删除因未合并失败后，询问是否按原选项强制删除这些分支；带上失败的说明与 Git 原文。
    case forceDelete(ForceDeletionOffer, AppFailure)
}
