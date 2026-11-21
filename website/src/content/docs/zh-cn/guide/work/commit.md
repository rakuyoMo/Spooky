---
title: "提交改动"
description: "写提交的标题与正文，使用自动补全，修补上一次提交，选择提交的身份与签名。"
---

提交把已暂存的改动连同一段说明存进仓库的历史。先按 [查看与挑选改动](/guide/work/diff/) 暂存改动，再在工作区顶部的提交区里写提交信息。

## 写提交信息 {#write}

提交信息分两部分：

- :ui[working.subject] 是一行简短的概括。按 <kbd>Return</kbd> 或 <kbd>Tab</kbd> 就到了正文。
- :ui[working.body] 可以不写，用来说明改了什么、为什么改。

::screenshot[展开的提交区。标题是 Add a units toggle，下面是两行正文。正文底部有图钉和折行两个按钮。再往下是 “修补最近提交” 和 “署名” 两个复选框，右边是作者的姓名、邮箱和头像。最下面是 “全部暂存” 与 “提交” 两个按钮。]{name="work-commit-area" frame="closeup" markers="62,12 24,56 94.6,69.1"}

1. :ui[working.subject]
2. 图钉按钮与折行按钮
3. 作者的头像

在任一个框里输入时，提交区会展开；正文里有文字时，它一直保持展开。想让它始终展开，点正文框底部的图钉按钮。拖动正文框的下边缘，可以调整它的高度。

开始输入以后，标题框末尾的数字显示还能输入几个字。超出上限的字会标上底色。

正文框底部的另一个按钮在两种折行方式之间切换：

- :ui[editor.softWrap] 在框的边缘折行。
- :ui[editor.hardWrap] 使用等宽字体，不自动折行。一条参考线标出字数上限，超长的行会标上底色。想把光标所在的段落按上限断行，选 :ui[menu.edit > commit.reformatParagraph]（<kbd>⇧⌘W</kbd>）。

这些选项在 :ui[app.name > settings.title] › :ui[settings.editor] 里：

| 设置 | 默认 |
|---|---|
| :ui[editor.showsCounter] | 打开 |
| :ui[editor.subjectLimit] | 50 |
| :ui[editor.wrapping] | :ui[editor.softWrap] |
| :ui[editor.bodyLimit] | 72。选了 :ui[editor.hardWrap] 时可以修改 |
| :ui[editor.showsGuide] | 打开。用于 :ui[editor.hardWrap] |
| :ui[editor.warnsComments] | 打开。见 [提交信息里的注释](#comments) |
| :ui[editor.stripsComments] | 关闭。提示关闭时可用 |
| :ui[editor.completesIssues] | 打开。见 [自动补全](#autocomplete) |

见 [编辑器](/guide/settings/appearance/#editor)。

## 提交 {#commit}

信息写好以后，点 :ui[working.commit]，或者在输入信息时按 <kbd>⌘↩</kbd>。标题里有文字、并且暂存了改动以后，这个按钮才能点。

不管焦点在窗口的哪里，选 :ui[workspace.title > working.commitMenu]（<kbd>⇧⌘C</kbd>）都能跳到标题框。

正文下面有两个复选框，会改变这次提交：

- :ui[commit.signOff] 在信息末尾加一行 `Signed-off-by`，写上你的姓名与邮箱。勾选与否会保持下去，所有仓库都一样。
- :ui[commit.skipHooks] 提交时不运行仓库的 `pre-commit` 与 `commit-msg` 钩子。只有仓库里有这些钩子时才显示，每次提交以后自动取消勾选。

提交失败时，写好的信息仍留在提交区里。想收回刚做的提交，选 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。见 [撤销与找回](/guide/work/undo/)。

### 提交信息里的注释 {#comments}

在 Git 里，以 `#` 开头的行算作注释，除非你改过注释字符。Spooky 按你写的原样提交，所以信息里有这样的行时，它会先问：:ui[commit.comments]

- :ui[commit.removeComments] 去掉这些行再提交。
- :ui[commit.keepComments] 原样提交。

勾选 :ui[commit.doNotAskAgain]，下次就按这次的选择处理。想恢复这个提问，在 :ui[app.name > settings.title] › :ui[settings.editor] 里打开 :ui[editor.warnsComments]，见 [编辑器](/guide/settings/appearance/#editor)。

信息里只有注释时，Spooky 会问 :ui[commit.commentsOnly]点 :ui[commit.keepCommentsAndCommit] 照样提交。

## 自动补全 {#autocomplete}

在标题或正文里输入下面的内容，Spooky 会随着你继续输入列出匹配的项：

| 输入 | 插入 |
|---|---|
| `c:` | 最近 100 个提交之一的短哈希。可以输入哈希、标题或作者的一部分 |
| `\` | 一个已暂存文件的路径 |
| `#` | GitHub 或 GitLab 上一个打开着的 Issue 的编号 |
| 标题开头的 `fixup!` 或 `squash!` | 之前某个提交的标题，表示这个提交是对它的修正 |

::screenshot[在提交标题里输入 c: 之后的样子。下面的列表列出最近的提交，每一项写着作者、日期、短哈希和标题，第一项已选中。]{name="work-commit-completion" frame="closeup"}

按 <kbd>↑</kbd> 或 <kbd>↓</kbd> 选一项，按 <kbd>Return</kbd> 插入，按 <kbd>Esc</kbd> 关掉列表。

补全 Issue 编号需要仓库的远端有对应的 [托管账号](/guide/hosting/accounts/)，并且在 :ui[app.name > settings.title] › :ui[settings.editor] 里打开了 :ui[editor.completesIssues]，见 [编辑器](/guide/settings/appearance/#editor)。标了 `fixup!` 或 `squash!` 的提交，之后可以并进它修正的那个提交，见 [改写历史](/guide/history/rewrite/)。

## 修补上一次提交 {#amend}

修补就是用一个新的提交替换上一次提交。可以用它改提交信息，或者补上忘了加的改动。

1. 勾选正文下面的 :ui[working.amend]。Spooky 填入上一次提交的信息，复选框上显示那个提交的短哈希。
2. 修改信息，把要补上的改动暂存好。
3. 点 :ui[working.amend]。

取消勾选，就回到之前正在写的信息。

想快速修补，在没有编辑任何信息框时按住 <kbd>⌥</kbd>。松开之前，提交区都处在修补上一次提交的状态。按住的同时点 :ui[working.amend]，或者按 <kbd>⌥⌘↩</kbd>，提交会保留原来的信息，并加入已暂存的改动。

:::caution
上一次提交已经推送过的话，修补以后它就和远端上的那个不一样了，推送时需要强制推送。见 [安全强推](/guide/branches/sync/#force-push)。
:::

想修改更早的提交，见 [改写历史](/guide/history/rewrite/)。

## 选择提交人 {#identity}

复选框右边的姓名与邮箱会作为作者记进提交。它们来自 Git 的 `user.name` 与 `user.email` 设置。旁边的头像按邮箱地址查找，见 [数据与隐私](/reference/data-privacy/)。

想换个身份提交，比如用工作邮箱，可以用身份档案：

1. 点头像。菜单里列出你的身份档案，正在用的那个前面有勾。
2. 选一个档案。
3. 看一下 Spooky 将要写入哪些设置，点 :ui[profiles.apply.submit]。

档案里的姓名、邮箱与签名密钥写进这个仓库自己的 Git 设置，不影响别的仓库。

当前身份还不是档案时，菜单里有 :ui[profiles.addCurrent]{1="alex@example.com"}，可以把它存成档案。想管理档案，在同一个菜单里选 :ui[profiles.manage]。见 [身份档案](/guide/settings/identity/#profiles)。

:::note[服务器仓库]
档案写进服务器上这个仓库的设置。服务器上在这个仓库里提交的其它工具也会用它。
:::

## 为提交签名 {#signing}

签过名的提交能证明它出自某把密钥的主人。Spooky 支持 SSH 与 OpenPGP 密钥。

把指针停在提交区的头像上，可以看到下一个提交会不会签名，用的是哪把密钥。

- **所有仓库**：在 :ui[app.name > settings.title] › :ui[settings.gitConfig] 里打开 :ui[gitConfig.signCommits]，选好 :ui[gitConfig.signingKey]，见 [签名](/guide/settings/identity/#signing)。
- **单个仓库**：点侧边栏里的 :ui[repositorySettings.title]，在 :ui[repositorySettings.signing] 一组里设置 :ui[repositorySettings.signCommits] 与 :ui[repositorySettings.signingKey]，见 [仓库设置](/guide/settings/identity/#repository)。

密钥需要口令时，Spooky 会弹出 :ui[signing.unlock] 对话框来问。

## 相关页面

- [查看与挑选改动](/guide/work/diff/)
- [撤销与找回](/guide/work/undo/)
- [身份档案与 Git 配置](/guide/settings/identity/)
