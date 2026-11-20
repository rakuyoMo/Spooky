---
title: "使用手册"
description: "了解这份手册怎样组织、从哪里开始读。"
---

这份手册讲怎样在 Spooky 里做日常的 Git 工作。仓库可以在这台 Mac 上，也可以留在另一台机器上、经 SSH 访问。每页讲一类任务，开头先说这页能帮你做什么。

第一次用 Spooky，按顺序读 “开始使用” 的几页。仓库放在服务器上的，接着读 “服务器仓库”。

在 Spooky 里选 :ui[menu.help > help.help]（<kbd>⌘?</kbd>）会打开这个网站。

## 手册的结构 {#organization}

| 分组 | 内容 |
|---|---|
| [开始使用](/guide/start/install/) | 安装与更新 Spooky，认识窗口的各个部分，完成第一次提交与推送 |
| [管理仓库](/guide/repositories/manager/) | 管理你的仓库，窗口与标签页，后退与前进，快捷操作 |
| [服务器仓库](/guide/server/overview/) | Spooky 怎样处理服务器上的仓库，准备 SSH，添加服务器仓库，连接，本机位置 |
| [日常工作](/guide/work/working-copy/) | 工作区，查看与暂存改动，提交，储藏，冲突，撤销 |
| [历史](/guide/history/browse/) | 浏览历史，提交详情，文件历史与 Blame，改写历史 |
| [分支与同步](/guide/branches/branches/) | 分支，标签与远端，获取、拉取与推送，合并与变基，整理分支 |
| [协作](/guide/hosting/accounts/) | 托管账号，Pull Request 与 Merge Request |
| [更多仓库功能](/guide/advanced/submodules/) | 子模块，工作树，Git LFS，操作怎样排队 |
| [设置与集成](/guide/settings/general/) | 设置，外观与主题，身份档案与 Git 配置，与其它 App 配合 |
| [参考](/reference/shortcuts/) | 键盘快捷键，系统要求，数据与隐私，常见问题与排查 |

## 约定 {#conventions}

### 界面上的叫法 {#names}

按钮、菜单、选项与窗口的名称用粗体，例如 :ui[working.commit]。这些名称直接取自 Spooky。Spooky 用这一页的语言运行时，你在屏幕上看到的就是这些字。

:ui[menu.file > action.openLocal] 这样的菜单路径，意思是先点菜单栏里的第一个名称，再在展开的菜单里选下一个。

少数几页还会提到 macOS 的界面，例如 **系统设置**。这些名称照 macOS 的显示写。

### 键盘快捷键 {#shortcuts}

快捷键写成键帽的样子，例如 <kbd>⇧⌘A</kbd>。按住前面的修饰键，再按最后一个键。符号和 macOS 菜单里显示的一样。

| 符号 | 按键 |
|---|---|
| <kbd>⌘</kbd> | Command |
| <kbd>⇧</kbd> | Shift |
| <kbd>⌥</kbd> | Option |
| <kbd>⌃</kbd> | Control |
| <kbd>↩</kbd> | Return |
| <kbd>⌫</kbd> | Delete |

全部快捷键列在 [键盘快捷键](/reference/shortcuts/) 里。

### 关于服务器仓库的提示 {#server-notes}

服务器仓库留在另一台机器上，Spooky 经 SSH 打开它。大多数操作在那里的做法一样。有不同的地方，页面会用下面这样的提示框写出来：

:::note[服务器仓库]
标题是 “服务器仓库” 的提示框，写的是服务器仓库里有什么不同。只用这台 Mac 上的仓库，可以跳过这些提示框。
:::

## 相关页面

- [安装 Spooky](/guide/start/install/)
- [界面一览](/guide/start/tour/)
- [服务器仓库怎样工作](/guide/server/overview/)
