---
title: "托管账号"
description: "连接 GitHub、GitLab.com 与私有部署的 GitLab 账号，了解令牌存在哪里、用在哪里。"
---

添加 GitHub 或 GitLab 账号之后，就能在 Spooky 里处理 Pull Request 和 Merge Request。Git 访问这个服务上的 HTTPS 远端时也用这个账号登录，不再问你用户名和密码。

## 添加账号 {#add}

打开 :ui[app.name > settings.title]，点 :ui[settings.accounts]。点列表下方的添加按钮，选账号所在的地方：

| 选择 | 用于 | 登录方式 |
|---|---|---|
| :ui[accounts.add.github] | github.com | 在浏览器里授权，或个人访问令牌 |
| :ui[accounts.add.gitlab] | GitLab.com | 个人访问令牌 |
| :ui[accounts.add.gitlabSelfManaged] | 你自己服务器上的 GitLab | 个人访问令牌，或用户名和密码 |

::screenshot[添加私有部署 GitLab 账号的对话框。主机地址是 https://gitlab.example.com，认证方式是用户名和密码。]{name="hosting-add-account" frame="dialog" markers="79.2,57.4 83.3,48.2"}

1. 主机地址
2. 认证方式

Spooky 核对账号时，对话框底部写着 :ui[accounts.validating]。点 :ui[action.cancel] 会停止核对，对话框留着，方便你改填的内容。核对失败时会弹出提示说明原因，填过的内容都还在。

添加好的账号列在表里，写着服务、实例和用户名。同一个服务上可以添加多个账号。

### GitHub {#github}

:ui[accounts.authentication] 选 :ui[accounts.authentication.oauth] 时，点 :ui[accounts.add.submit]：

1. Spooky 显示一个一次性验证码，把它复制好，并在浏览器里打开 GitHub。
2. 在网页上粘贴验证码，授权 Spooky。中途复制过别的东西的话，点 :ui[accounts.copyCode] 再复制一次。
3. 授权之后，对话框关闭，账号出现在列表里。

验证码过期，或者你在浏览器里拒绝了授权，就重新开始，拿一个新的验证码。

想改用令牌，在 :ui[accounts.authentication] 里选 :ui[accounts.authentication.token]。令牌需要 `repo` 和 `read:org` 两个权限范围。

### GitLab.com {#gitlab-com}

粘贴一个带 `api` 权限范围的个人访问令牌。

### 私有部署的 GitLab {#self-managed}

在 :ui[accounts.host] 里填 GitLab 服务器的地址，有端口和路径的一起写上，比如 `https://example.com:8443/gitlab`。然后选登录方式：

- :ui[accounts.authentication.token]：带 `api` 权限范围的令牌。
- :ui[accounts.authentication.password]：Spooky 只用密码换一个令牌，不保存密码。

用户名和密码只有在下面几条都满足时才能登录：

- 服务器上是 GitLab 18.11 或更早的版本。GitLab 19.0 起不再用密码换令牌。
- 服务器不要求 OAuth 应用凭据。GitLab 13.9 一定要求，GitLab 17.8 起可以设置成要求。
- 服务器允许用密码经 HTTPS 访问 Git。
- 你的账号有 GitLab 或 LDAP 密码，没有开双重验证，也不是只能经单点登录登录。

这样换来的令牌会过期，Spooky 会自己续期。GitLab 不再给续期时，账号会被标成需要重新认证。

Spooky 需要 GitLab 9.0 或更新的版本。服务器要能从你的 Mac 访问到，它的证书也要受这台 Mac 信任；不受信任时，在 **钥匙串访问** 里信任这个证书。

## 管理账号 {#manage}

所有窗口共用同一组账号。在 :ui[app.name > settings.title] › :ui[settings.accounts] 里：

- 想重新认证账号，选中它，点列表下方的 :ui[accounts.reauthenticate]，重新登录或填一个新令牌。必须还是同一个用户；想用别的用户登录，就添加一个新账号。
- 想移除账号，选中它，点列表下方的移除按钮并确认。Spooky 会把它的令牌从钥匙串里删掉。

标着 :ui[accounts.needsReauthentication] 的账号，令牌已经不被服务接受，比如过期了或被撤销了。重新认证之后才能接着用。

改动马上生效。打开着的 Pull Request 或 Merge Request 列表会重新读取，不用重开窗口。

## 账号用在哪里 {#uses}

账号作用于它所在服务上的远端：

- [Pull Request 与 Merge Request](/guide/hosting/pull-requests/) 列表
- 提交信息里 `#` 后面的 Issue 编号，见 [自动补全](/guide/work/commit/#autocomplete)。
- [分支整理](/guide/branches/review/) 里 Pull Request 和 Merge Request 的状态
- 把仓库 [发布](#publish) 到这个服务上
- [登录 HTTPS 远端](#git)

## 远端用哪个账号 {#remotes}

Spooky 拿每个远端的地址和每个账号的实例对照：github.com、GitLab.com，或者你自己的 GitLab 服务器。

- **这个实例上有一个账号**：就用它。
- **这个实例上有几个账号**：Pull Request 列表会请你选一个。Spooky 会为这个远端记住你的选择。
- **还没有账号**：远端在 github.com 或 GitLab.com 上时，列表会说明，并提供 :ui[pullRequests.openAccounts]。
- **地址对不上**：比如远端写的是 `~/.ssh/config` 里的主机别名。列表顶部会出现说明和 :ui[pullRequests.associate]。远端确实属于你的某个账号时，点它，选好账号和项目。

同一个项目的 HTTPS 地址和 SSH 地址对应到同一个账号。

## 登录 HTTPS 远端 {#git}

HTTPS 远端属于你的某个账号时，Git 用这个账号的令牌登录。克隆、获取、拉取、推送和自动获取都是这样。

- SSH 远端照旧用你的 SSH 密钥，账号不影响它们。
- 在这些地址上，Spooky 代替你给 Git 设置的凭据助手回答，比如 macOS 的钥匙串助手。这些助手看不到令牌，也存不走令牌。
- 同一个实例上有几个账号、又没有为这个远端选过账号时，Git 照常问你用户名和密码。

Git 拒绝了令牌时，这一次的命令会失败。之后 Git 访问这个账号的远端时会问你用户名和密码，对话框里写明这个账号的令牌没有被接受。重新认证账号之后，就又用它登录了。

:::note[服务器仓库]
服务器上的 Git 同样用令牌登录。每次需要时，它从你 Mac 上的 Spooky 取令牌，令牌不会存到服务器上。
:::

## 令牌存在哪里 {#storage}

- 账号列表存在 Spooky 的偏好设置里，不含令牌。
- 令牌存在钥匙串里，条目名是 `com.rakuyo.spooky.hosting.<address>`。
- 用用户名和密码登录私有部署的 GitLab 时，Spooky 存下换来的令牌，不存密码。

令牌不会写进 :ui[activity.title] 的记录和 Spooky 的日志。

## 请求发往哪里 {#network}

Spooky 从你的 Mac 访问托管服务，服务器仓库也一样：

- GitHub：在浏览器里授权时访问 `github.com`，其余都访问 `api.github.com`。
- GitLab：`gitlab.com`，或者你自己的 GitLab 的地址。

添加或重新认证账号时会访问，用到账号的功能时也会访问：Pull Request 和 Merge Request 列表以及在那里做的操作、`#` 后面的 Issue 编号、分支整理里的状态，以及发布仓库。用用户名和密码登录的账号还会去那里续期令牌。

这些请求每一个都会出现在 :ui[activity.title] 窗口的 :ui[activity.service] 页里。

GitHub 和 GitLab 用户的头像来自这些服务给出的地址。下载过的头像只留在内存里，退出 Spooky 就没有了。

Git 本身从仓库所在的地方连接远端，服务器仓库就是从服务器上连接。见 [数据与隐私](/reference/data-privacy/#network)。

## 发布仓库 {#publish}

想用打开着的仓库在 GitHub 或 GitLab 上新建一个仓库，选 :ui[menu.repository > publish.menu]，或者在侧边栏右键点按 :ui[workspace.title]，选 :ui[workspace.publishMenu]。仓库还没有远端时，:ui[sync.push] 也会打开这个对话框。至少要有一个账号。

| 栏目 | 作用 |
|---|---|
| :ui[publish.remote] | 新远端的名字。一开始是 `origin`，仓库里已经有 `origin` 时是 `origin-2`。 |
| :ui[pullRequests.account] | 仓库建在哪里：你自己的用户下，或者你所在的某个组织或群组 |
| :ui[publish.name] | 在服务上的名字，一开始是仓库文件夹的名字。 |
| :ui[pullRequests.description] | 可以不填 |
| :ui[publish.visibility] | :ui[publish.visibility.private] 或 :ui[publish.visibility.public]。GitLab 另有 :ui[publish.visibility.internal]。 |
| :ui[publish.target] | 新远端会用的 HTTPS 地址 |

点 :ui[publish.submit] 之后，Spooky 会：

1. 在服务上新建一个空仓库。
2. 用 HTTPS 地址把它添加为远端。
3. 把全部本地分支和标签推送过去。没有上游的分支改为跟踪新远端上的同名分支，已经有上游的不变。

同名的仓库已经存在时，Spooky 会提示，不会覆盖它，换个名字即可。推送失败时，新加的远端和服务上新建的仓库都会保留，你可以再推送一次。

发布仓库不能用 <kbd>⌘Z</kbd> 撤销，在它之前的操作也不能再撤销。

## 相关页面

- [Pull Request 与 Merge Request](/guide/hosting/pull-requests/)
- [密码与口令的询问](/guide/server/connection/#prompts)
- [数据与隐私](/reference/data-privacy/)
