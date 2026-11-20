---
title: "数据与隐私"
description: "了解 Spooky 把什么存在哪里、会连接哪些网络地址，以及崩溃报告与诊断报告里有什么。"
---

Spooky 没有自己的账号，也不收集使用数据。这一页列出它存了什么、存在哪里，以及会连接哪些地址。

## 在你的 Mac 上 {#mac}

| 内容 | 位置 |
|---|---|
| 设置、仓库列表、身份档案、托管账号的列表，以及服务器仓库在这台 Mac 上的位置 | Spooky 的偏好设置 `com.rakuyo.spooky` |
| 主题，每个主题一个 `.spookytheme` 文件 | `~/Library/Application Support/Spooky/Themes/` |
| 让服务器仓库能出现在最近使用的文稿里的 `.spookyrepo` 小文件夹 | `~/Library/Application Support/Spooky/Locations/` |
| :ui[activity.title] 里获取、拉取、推送等远端操作的记录，保留 7 天 | `~/Library/Application Support/Spooky/Activity/` |
| :ui[activity.title] 统计增减时用来比较的内容，每个仓库一个文件 | `~/Library/Application Support/Spooky/Baselines/` |
| 你给服务器上的 Git 存下的用户名与密码 | 钥匙串里名为 `com.rakuyo.spooky.remote.<host alias>` 的项目 |
| 托管账号的令牌 | 钥匙串里名为 `com.rakuyo.spooky.hosting.<address>` 的项目 |
| macOS 为 Spooky 的网络请求留下的缓存与 Cookie，比如下载过的头像 | `~/Library/Caches/com.rakuyo.spooky/`，以及 `~/Library/HTTPStorages/` 里名称以 `com.rakuyo.spooky` 开头的项目 |
| 服务器仓库的连接文件 | `/tmp/spooky-*` 文件夹，连接关闭时删除 |
| 用快速查看或别的 App 打开的文件副本 | 名为 `spooky-files-*` 的临时文件夹，仓库关闭时删除 |

用用户名和密码登录私有部署的 GitLab 时，Spooky 存下换来的令牌，不存密码。

想把这些全删掉，见 [卸载](/guide/start/install/#uninstall)。

## 在服务器上 {#servers}

除了仓库本身，Spooky 只在服务器上写两个地方：

- 个人文件夹下的 `~/.spooky/bin/`：Spooky 经 SSH 执行的一个小脚本，以及询问与签名时用的指向它的链接。它会留着，下次连接还用。想删掉的话，删除这个文件夹。
- `/tmp/spooky-*`：本次连接的文件，连接关闭时删除。

Spooky 查找仓库的 [本机位置](/guide/server/local-location/#automatic) 时，会在仓库的 Git 文件夹里临时放一个空文件，核对完马上删掉。

服务器上的 Git 要密码时，Spooky 从 Mac 经 SSH 连接把回答交给提问的那条 Git 命令，不给别的命令。服务器上的 Git 不会存下它，因为 Spooky 给自己的命令关掉了 Git 的凭据助手。

## 在仓库里 {#repositories}

Spooky 在仓库自己的 Git 配置里存几样东西，写成 `branch.<name>.spooky-*` 项：

- 哪些分支置顶了、归档了
- 每个分支的父分支
- 自动归档用的标记

给分支改名时，这些项跟着分支走；删除分支时，它们一起删掉。在仓库的 :ui[repositorySettings.title] 里改的 Git 设置，比如签名，也写进同一份配置。

Git 配置不会被推送，所以这些都不会到远端。服务器仓库的这些内容存在服务器上。

## 网络连接 {#network}

| Spooky 连接的地址 | 什么时候 |
|---|---|
| 你的服务器，经 SSH | 打开服务器仓库期间。用的是 `~/.ssh/config` 里的主机别名。SMB 挂载还会连接服务器的文件共享。 |
| 仓库的 Git 远端 | 获取、拉取、推送、克隆时，以及自动获取时。服务器仓库由服务器上的 Git 去连远端，不经过 Mac。 |
| `github.com` 与 `api.github.com`，或者你的 GitLab 地址 | 添加或重新认证托管账号时，以及用到账号的功能时：Pull Request 与 Merge Request、Issue 编号的补全、分支整理里的状态、发布仓库。这些请求从 Mac 发出，见 [请求发往哪里](/guide/hosting/accounts/#network)。 |
| `gravatar.com` | 显示提交作者的头像 |
| `github.com` 上 Spooky 的发布页 | 检查更新 |

自动获取默认每 30 分钟一次。想改的话，打开 :ui[app.name > settings.title]，点 :ui[settings.general]，在 :ui[settings.autoFetch] 旁边选一项。选 :ui[settings.autoFetch.never]，就只在你自己操作时获取。

取提交作者的头像时，Gravatar 拿到的是作者邮箱的哈希值，不是邮箱本身。下载过的头像，macOS 会留一份在 Spooky 的缓存文件夹里。GitHub 与 GitLab 用户的头像来自这两个服务。设置里没有关掉头像的选项。

Spooky 默认每天检查一次更新。想停掉的话，在 :ui[app.name > settings.title] › :ui[settings.updates] 里关掉 :ui[updates.automaticChecks]。见 [保持更新](/guide/start/install/#updates)。

:ui[menu.help] 菜单里的 :ui[help.help]、:ui[help.support] 等项，会在浏览器里打开网页。

## 崩溃报告 {#crash-reports}

Spooky 上次意外退出的话，会读取 macOS 存在这台 Mac 上的崩溃报告。下次启动时，它会问你：:ui[crash.title]。

- 点 :ui[crash.report] 会在浏览器里打开 GitHub 的新问题页，里面填好了崩溃的摘要。
- 点 :ui[crash.dontReport] 就跳过。这次崩溃 Spooky 不会再问。

摘要里有 Spooky 的版本与构建号、macOS 版本、崩溃的类型，以及崩溃线程最多 30 行的调用栈。离开 Mac 之前，Spooky 会把你的个人文件夹、用户名、邮箱、IP 地址、令牌，以及网址里的密码换成占位文字。

要等你在浏览器里提交，问题才会建出来。提交前可以先改文字，也可以直接关掉页面。

下次不想再被问，在对话框里勾选 :ui[settings.crashReports.always]。之后 Spooky 会直接打开新问题页。同一个选项也在 :ui[app.name > settings.title] › :ui[settings.integration] 里。

## 诊断报告 {#diagnostic-reports}

报告问题时，附一份诊断报告能帮忙看清发生了什么。选 :ui[menu.help > help.diagnosticReport]，再选一个存放位置。Spooky 存下一个文本文件，并在访达里显示它。报告不会被发送到任何地方。

报告里有：

- Spooky 的版本与构建号、macOS 版本，以及你排在最前面的三种语言
- 这台 Mac 上的 Git 程序与它的版本
- 影响 Spooky 运行方式的设置，比如外观、更新通道、终端程序、Diff 与合并工具、SSH Agent、Git 程序，以及是否向登录 shell 请求环境变量
- 本机仓库与服务器仓库各有几个
- 最近 20 个操作的名称、时间与结果
- 本次运行最近一小时的 Spooky 日志，最多 500 行

报告里没有仓库路径、主机别名、密码，也没有环境变量的值。Spooky 会像处理崩溃报告一样，把个人文件夹、用户名、邮箱、IP 地址与令牌换成占位文字。分享之前，先打开文件看一遍。

Spooky 的日志记的是连接的变化，以及操作的开始、结束与失败，不记命令的参数与输出、提交信息、密码与令牌。

## 相关页面

- [安装 Spooky](/guide/start/install/)
- [服务器仓库怎样工作](/guide/server/overview/)
- [托管账号](/guide/hosting/accounts/)
- [系统要求](/reference/requirements/)
