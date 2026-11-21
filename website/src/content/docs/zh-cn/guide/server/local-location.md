---
title: "本机位置"
description: "通过自动查找、SMB 挂载、sshfs 挂载或指定文件夹，给服务器仓库一个本机位置，让 “在访达中显示”、终端与外部编辑器能打开它。"
---

访达只能显示 Mac 上的文件夹，服务器仓库的文件却在服务器上。要在访达里看到它们，Spooky 需要 Mac 上有一个能看到服务器文件的文件夹，通常是挂载的网络卷。这个文件夹就是仓库的本机位置。

这一页讲 Spooky 怎样找到或挂载这个文件夹，以及终端和别的 App 怎样打开服务器仓库。

## 在访达中显示 {#show-in-finder}

在服务器仓库里，:ui[action.revealFinder] 一直可以点。它在这些地方：

- :ui[menu.file] 菜单
- 工具栏上的 :ui[toolbar.finder]。要把它加进工具栏，选 :ui[menu.view > menu.customizeToolbar]，把它拖上去。
- 右键点按侧边栏的 :ui[workspace.title] 一行
- [快捷操作](/guide/repositories/navigation/#quick-actions)
- 在仓库管理窗口里右键点按服务器仓库
- 在工作区里右键点按文件，访达会选中这些文件。

已经知道本机位置、文件夹也在时，访达直接打开。不然的话，Spooky 会弹出一个面板，按这几步走：

1. 仓库没连上的话，先连接。
2. 查找文件夹；方式是 SMB 或 sshfs 时，先挂载。
3. 还是找不到文件夹，面板就换成设置本机位置的表单，顶部写着原因，见 [设置本机位置](#set)。

点 :ui[action.cancel] 关掉面板，设置不会变。

## 设置本机位置 {#set}

1. 在侧边栏的 :ui[workspace.group] 下，点 :ui[repositorySettings.title]。
2. 在 :ui[repositorySettings.general] 页找到 :ui[repositorySettings.localLocation]。这一行写着方式与文件夹，或者没有文件夹的原因，比如 :ui[localLocation.notMounted]。
3. 把指针移到这一行上，出现 :ui[localLocation.change] 后点它。仓库要先连上。
4. 在 :ui[localLocation.title] 对话框里，从 :ui[localLocation.method] 选一种方式。
5. 挂载的方式点 :ui[localLocation.mount]，其余的方式点 :ui[localLocation.save]。

Spooky 挂载或核对文件夹期间，表单不能改。点 :ui[action.cancel] 可以停下，原来的设置保持不变。

本机位置按服务器仓库分别存在这台 Mac 上，不会写进仓库，也不会写到服务器上。

SMB 或 sshfs 挂载的卷被推出后，这一行会出现 :ui[localLocation.mountAgain]，点它重新挂载。

## 方式 {#methods}

:ui[localLocation.method] 菜单只列出现在能用的方式，当前用的方式总会列出。

### 自动查找 {#automatic}

默认是 :ui[localLocation.method.automatic]。Spooky 在 Mac 已经挂载的网络卷里找，比如 SMB、NFS、AFP、WebDAV 与 sshfs 卷，不管是哪个 App 挂上的。卷所在的服务器和主机别名是同一个地址，才算数。

接着 Spooky 在卷里找仓库文件夹。为了确认是同一个仓库，Spooky 会在服务器上仓库的 Git 文件夹里临时放一个空文件，看卷里能不能看到它，然后删掉。

### SMB 挂载 {#smb}

:ui[localLocation.method.smbMount] 用 SMB 挂载服务器上的共享文件夹。SMB 是 macOS 用来共享文件的协议。服务器 2 秒内在 SMB 端口上有回应，菜单里才会列出这一项。

1. 选 :ui[localLocation.method.smbMount]，点 :ui[localLocation.mount]。
2. macOS 显示服务器上的共享文件夹，或者先请你登录。选含有这个仓库的那个共享。

Spooky 会记住这个共享，下次直接挂载，不再询问。选的共享里没有这个仓库时，表单会写 :ui[localLocation.notInShare] 换一个共享再试。

服务器是一台 Mac 的话，在那台 Mac 的 **苹果菜单 › 系统设置 › 通用 › 共享** 里打开 **文件共享**。

### sshfs 挂载 {#sshfs}

:ui[localLocation.method.sshfsMount] 经 SSH 挂载仓库文件夹，用的是和 Spooky 相同的主机别名。这台 Mac 上要装有 sshfs，以及 macFUSE 或 FUSE-T。Spooky 会在 `/opt/homebrew/bin`、`/usr/local/bin` 与你的 `PATH` 里找 `sshfs`。没装的话，菜单里不会有这一项。

1. 选 :ui[localLocation.method.sshfsMount]。
2. 点 :ui[localLocation.mountAt] 旁边的 :ui[localLocation.choose]，选 Mac 上的一个空文件夹。服务器上的文件会出现在这里。
3. 点 :ui[localLocation.mount]。

### 指定文件夹 {#chosen-folder}

:ui[localLocation.method.chosenFolder] 让你自己选文件夹，比如你用别的办法挂上的文件夹。

1. 选 :ui[localLocation.method.chosenFolder]。
2. 点 :ui[localLocation.folder] 旁边的 :ui[localLocation.choose]，选仓库文件夹。
3. 点 :ui[localLocation.save]。Spooky 会先核对这个文件夹，再保存。

Spooky 从不推出它挂载的卷。之后再打开这个仓库时，Spooky 会在后台重新挂载，什么都不问。

## 添加时挂载 {#when-adding}

[添加服务器仓库](/guide/server/add/) 时，:ui[remote.mount] 可以顺手设好本机位置。它一开始是 :ui[remote.mount.none]。填好主机别名后，能用的话，菜单会列出 :ui[remote.mount.smb] 与 :ui[remote.mount.sshfs]。两个都不能用时，显示 :ui[remote.mount.unavailable]。

- **SMB**：仓库打开后，macOS 显示服务器上的共享文件夹或登录窗口。取消的话，仓库照常打开，仓库设置里的 :ui[repositorySettings.localLocation] 会写出没挂上的原因。
- **sshfs**：多出一行 :ui[localLocation.mountAt]，选一个空文件夹。仓库打开后，Spooky 把它挂到那里。

改了主机别名，菜单会回到 :ui[remote.mount.none]。

## 终端与其它 App {#terminal}

下面这些在服务器仓库里不需要本机位置也能用：

- **:ui[action.openTerminal]** 打开 :ui[app.name > settings.title] › :ui[settings.general] 里选的终端 App，用 `ssh -t` 和主机别名登录，进入仓库文件夹。服务器不给终端的话，Spooky 会不要终端再连一次。命令照样能执行，只是没有行编辑，也用不了全屏程序。它在 :ui[menu.file] 菜单里，也是工具栏上的 :ui[toolbar.terminal]；右键点按工作区或仓库管理窗口里的仓库也能找到。
- **:ui[action.copyPath]** 复制的路径前面带着主机别名，比如 `driftwood-server:/srv/git/driftwood`。
- 工作区里的 **:ui[files.open] 与 :ui[files.openWith]** 用别的 App 打开文件。装了 Remote SSH 扩展的 Visual Studio Code、Visual Studio Code Insiders 与 Cursor 会直接打开服务器上的文件。别的 App 拿到的是 Mac 上的副本，保存后 Spooky 把副本写回服务器。

在这期间服务器上的文件也被改过的话，Spooky 写回前会先问你：:ui[externalTool.fileChanged]。点 :ui[externalTool.overwrite]，用你的副本替换它。关闭仓库时，Spooky 会删掉这些副本。

快速查看和外部的 Diff 与合并工具，用的也是副本。合并工具完成后，Spooky 把结果写回服务器并暂存。

## 相关页面

- [服务器仓库怎样工作](/guide/server/overview/)
- [添加服务器仓库](/guide/server/add/)
- [集成](/guide/settings/integration/)
