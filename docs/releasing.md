# 发布

## 版本号

- 版本号写在 `Sources/Spooky/Info.plist`：`CFBundleShortVersionString` 是对外版本号，`CFBundleVersion` 是正整数构建号
  - 构建号每次发布由 `mise run release` 增加 `1`，跨版本持续递增、从不回退；更新按它比较新旧
- 1.0.0 之前，完成里程碑 Mn 的 PR 把 `CFBundleShortVersionString` 改为 `0.n.0`，如 M5 为 `0.5.0`、M10 为 `0.10.0`
- 1.0.0 由维护者确认后手动发起发布，见 “发布流程”

## 发布流程

每个版本发往一个通道，对应 Settings → Updates 的三个选项：

- `stable`：所有用户都会收到
- `beta`：选了 Beta 或 Development 的用户会收到
- `development`：只有选了 Development 的用户会收到

发布一个新版本：

1. 写这一版的更新说明，放在 `docs/release-notes/X.Y.Z/`，见 “更新说明”；可以先合并进 `main`，也可以留在工作区，由下一步带进发布提交
2. 在 `main` 上运行 `mise run release X.Y.Z [stable|beta|development]`，通道默认为 `stable`；脚本先检查以下各项，任一不满足就报错退出，不做任何改动：
   - 版本号为 `X.Y.Z`，三段都是不带前导零的非负整数，不带 `v`；通道是三者之一
   - Info.plist 的当前构建号是正整数
   - 这一版的更新说明齐全：每种语言一份，都有内容
   - 标签 `vX.Y.Z` 在远端不存在
   - 当前在 `main` 分支，除 `docs/release-notes/X.Y.Z/` 下的新增或改动外工作区干净，本地 `main` 与 `origin/main` 一致
   - `gh` 已登录，`origin` 是本仓库而不是 fork：fork 的 PR 拿不到发布所需的写权限
   - 本地与远端都没有 `release/X.Y.Z` 分支
3. 检查通过后，脚本切出 `release/X.Y.Z` 分支，把 Info.plist 的版本号改成 `X.Y.Z`、构建号增加 `1`，连同这一版的更新说明一起提交并推送，再向 `main` 开 release PR
   - PR 标题为 `release: X.Y.Z`，测试与开发版本在后面加 ` (beta)` 或 ` (development)`
   - 推送或开 PR 失败时，脚本删掉本机与远端的发布分支，更新说明留在工作区
4. 标题以 `release:` 开头的 PR 由 “发布检查” workflow 运行 `scripts/check-release.sh`：标题格式、Info.plist 的版本号与标题一致、构建号比 `main` 增加 `1`、更新说明齐全、远端没有同名标签；改标题时也会重新检查
5. 检查通过后合并 PR；“发布” workflow 对合并提交再做一次同样的检查，然后：
   - 打包并压缩为 `Spooky-X.Y.Z.zip`，生成签名的更新清单，每种语言的更新说明都嵌在清单里
   - 测试与开发版本的清单带上最新 Release 清单里更稳定的各通道最新的条目，选了这些通道的用户仍能收到它们
   - 在合并提交上打标签 `vX.Y.Z`，创建标为 latest 的 GitHub Release：名称为 `vX.Y.Z`，测试与开发版本带上通道；正文是这一版的 `en.md`，附上 zip 与更新清单

失败时到仓库的 Actions 页面查看原因，修好后再运行一次 `mise run release X.Y.Z`。

也可以对 Claude Code 说 “发布 X.Y.Z”，由 [`release` skill](../.claude/skills/release/SKILL.md) 走完起草更新说明、开 PR、等检查、合并、等发布的全过程。

## 更新签名

- 更新包与更新清单都用 Sparkle 的 EdDSA 私钥签名；App 只接受签名的更新清单，下载的更新包先验证签名再解压安装，签名不符时不安装、保留当前版本
- 私钥须与 Info.plist 的 `SUPublicEDKey` 配对，由 Sparkle 的 `generate_keys` 管理；只存于仓库 secret `SPARKLE_PRIVATE_KEY` 与维护者本机钥匙串的 `com.rakuyo.spooky` 账户，不进仓库
- App 从标为 latest 的 Release 附带的 `appcast.xml` 读取更新清单
- 本机先运行 `mise run bundle`，再运行 `mise run appcast <通道> [<上一份更新清单>]`，在 `build/updates/` 生成更新包与签名的更新清单

## 更新说明

每个版本的更新说明放在 `docs/release-notes/X.Y.Z/`，每种语言一份：`en.md` `zh-Hans.md` `zh-Hant.md` `ja.md` `ko.md` `de.md` `fr.md` `es.md`，与 `Sources/Spooky/Resources/` 下的 `.lproj` 同名。

- `mise run appcast` 把每份说明嵌进签名的更新清单，App 的更新窗口按用户的语言显示其中一份
- `en.md` 同时是 GitHub Release 的正文
- `scripts/check-release.sh` 检查每份都存在且有内容：发版脚本、“发布检查” 与 “发布” 两个 workflow 都调用它

### 写法

- 写给用户看：只写用户能感知的改动
  - 不写 PR 编号与链接
  - 不写文档、CI、测试、重构这类与 App 行为无关的改动
- 不写顶层标题：更新窗口与 GitHub 都会显示版本号
- 按类别分节，节标题用 `###`，取下表中该语言的叫法，只保留有内容的节；每条列表项写一个改动
- Markdown 只用 `###` 标题、无序列表、粗体、链接
- 界面上的叫法与该语言的 `Localizable.strings` 一致
- `zh-Hans` `zh-Hant` 按 [AGENTS.md](../AGENTS.md) 的 “中文行文” 一节；`ja` `ko` 的引号等写法照各自 `Localizable.strings` 的现有用法
- `de` `fr` `es` 与 `en` 一样用粗体标出界面上的叫法；`de` 的 `…` 之前，`fr` 的 `:` `;` `!` `?` 之前与 `« »` 之内，用不换行空格（U+00A0），免得它们被折到行首

| 语言 | 新增 | 改进 | 修复 |
|---|---|---|---|
| `en` | New | Improved | Fixed |
| `zh-Hans` | 新增 | 改进 | 修复 |
| `zh-Hant` | 新增 | 改進 | 修正 |
| `ja` | 新機能 | 改善 | 修正 |
| `ko` | 새 기능 | 개선 | 수정 |
| `de` | Neu | Verbessert | Behoben |
| `fr` | Nouveautés | Améliorations | Corrections |
| `es` | Novedades | Mejoras | Correcciones |
