---
title: "安装 Spooky"
description: "查看系统要求、下载并第一次打开 Spooky、保持更新、选择界面语言和卸载。"
---

这一页从下载 Spooky 讲到第一次打开它。后面几节讲自动更新、界面语言和卸载。

## 系统要求 {#requirements}

- macOS 26 或更新版本
- Git 2.41 或更新版本

Spooky 默认用 `/usr/bin/git`。想换成别的 Git，打开 :ui[app.name > settings.title]（<kbd>⌘,</kbd>），点 :ui[settings.gitConfig]，在 :ui[settings.gitProgram] 菜单里选一个。菜单里列的是 Spooky 找到的、版本够新的 Git。Git 装在别处的话，选 :ui[settings.gitProgram.choose] 自己挑。菜单下方写着要求的最低版本。见 [Git 程序](/guide/settings/identity/#git-program)。

:::note[服务器仓库]
服务器上也要装 Git 2.41 或更新版本。Spooky 经 SSH 连服务器，用的是 `~/.ssh/config` 里的主机别名。设置里选的 Git 只管这台 Mac 上的仓库，服务器仓库用服务器上的 Git。详见 [系统要求](/reference/requirements/) 与 [准备 SSH](/guide/server/prepare-ssh/)。
:::

## 下载 {#download}

1. 打开 GitHub 上的 [Spooky 发布页](https://github.com/rakuyoMo/Spooky/releases)。
2. 找到最新的稳定版，它的名称是 `v` 加版本号。名称以 “(beta)” 或 “(development)” 结尾的是测试版本。
3. 下载名为 `Spooky-` 加版本号的 zip 文件。
4. 连按下载的 zip 文件，把它解压。
5. 把 Spooky 拖进 **应用程序** 文件夹。

## 第一次打开 {#first-launch}

Spooky 没有经过 Apple 公证。第一次打开时，macOS 会拦下它，弹出一条警告。这样放行：

1. 在 **应用程序** 文件夹里连按 Spooky。出现警告后，关掉它。
2. 选 **苹果菜单 › 系统设置**，然后点边栏中的 **隐私与安全性**。可能需要向下滚动。
3. 前往 **安全性**，然后点 **仍要打开**。这个按钮在你尝试打开 Spooky 后的大约一小时内可用。
4. 输入登录密码，然后点 **好**。

macOS 会记住这次选择，之后 Spooky 就能正常打开。它启动后先显示仓库管理窗口，那里有什么见 [界面一览](/guide/start/tour/)。

## 保持更新 {#updates}

Spooky 默认会自己检查更新。想马上检查，选 :ui[app.name > updates.check]。

每个更新都有签名。Spooky 安装前会先核对签名。没通过核对的更新，不会替换你现有的 Spooky。

想改更新方式，打开 :ui[app.name > settings.title]，点 :ui[settings.updates]：

| 设置 | 作用 |
|---|---|
| :ui[updates.channel] | 收到哪些版本，见 [更新通道](#channels) |
| :ui[updates.automaticChecks] | 在后台检查更新。默认打开 |
| :ui[updates.automaticDownloads] | 在后台下载更新，退出 Spooky 时安装。默认关闭。要先打开自动检查，Spooky 所在的文件夹也要能写入，才能打开这一项 |
| :ui[updates.interval] | 多久检查一次：:ui[updates.interval.hourly]、:ui[updates.interval.daily] 或 :ui[updates.interval.weekly]，默认每天。打开了自动检查才能选 |

最后一行 :ui[updates.lastCheck] 写着 Spooky 上次检查的时间。还没检查过的话，写的是 :ui[updates.never]。

### 更新通道 {#channels}

| 通道 | 收到的版本 |
|---|---|
| :ui[updates.channel.stable] | 稳定版。这是默认的通道 |
| :ui[updates.channel.beta] | 稳定版与测试版 |
| :ui[updates.channel.development] | 全部版本，包括开发版 |

### 新版本有什么变化 {#whats-new}

第一次启动新版本的 Spooky 时，仓库窗口的侧边栏底部会出现 :ui[whatsNew.card.title]。点 :ui[whatsNew.card.learnMore] 看这一版改了什么，不想看就关掉这张卡片。

之后想再看，选 :ui[menu.help > help.whatsNew]。:ui[menu.help > help.releaseNotes] 会打开 GitHub 上的发布页。

## 选择界面语言 {#language}

Spooky 有英文、简体中文、繁体中文、日文、韩文、德文、法文与西班牙文八种语言。它按你在 macOS 里设定的语言顺序显示。你的语言都不在其中时，显示英文。

只给 Spooky 换一种语言：

1. 选 **苹果菜单 › 系统设置**，然后点边栏中的 **通用**。
2. 点 **语言与地区**，然后前往 **应用程序**。
3. 点 **添加** 按钮，选 Spooky 和一种语言，然后点 **添加**。
4. Spooky 正开着的话，退出后重新打开。

想换回系统语言，在同一个列表里选中 Spooky，点 **移除** 按钮。

## 卸载 {#uninstall}

1. 选 :ui[app.name > menu.quit]（<kbd>⌘Q</kbd>）退出 Spooky。
2. 把 Spooky 从 **应用程序** 文件夹移到 **废纸篓**。

设置与数据还留在 Mac 上。想一起删掉：

- 设置：在 **终端** 里执行 `defaults delete com.rakuyo.spooky`。
- 主题、活动记录等其它数据：删除文件夹 `~/Library/Application Support/Spooky/`。
- 缓存：删除文件夹 `~/Library/Caches/com.rakuyo.spooky/`，以及 `~/Library/HTTPStorages/` 里名称以 `com.rakuyo.spooky` 开头的项目。
- Spooky 保存的密码与令牌：删除钥匙串里名称以 `com.rakuyo.spooky.` 开头的项目。
- 用过的每台服务器：删除那里个人文件夹下的 `~/.spooky/`。

仓库的 Git 配置里还留着 Spooky 写入的 `branch.<name>.spooky-*` 项。Spooky 存了哪些数据、存在哪里，见 [数据与隐私](/reference/data-privacy/)。

## 相关页面

- [界面一览](/guide/start/tour/)
- [系统要求](/reference/requirements/)
- [数据与隐私](/reference/data-privacy/)
