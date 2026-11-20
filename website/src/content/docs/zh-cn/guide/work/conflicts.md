---
title: "解决冲突"
description: "用冲突向导或外部合并工具解决合并、变基等进行中操作的冲突，然后继续或中止。"
---

两边改了文件的同一处，Git 判断不了该留哪一个，就产生了冲突。合并、变基、摘取、反转会停在这里，应用储藏也一样。你来决定每个文件里留下什么，再把操作做完。

::screenshot[把 “feature/units-toggle” 合并到 “main” 时的工作区。中间一栏顶部的横幅写着 1 个未解决冲突（已解决 0 个），带一个 “中止” 按钮。文件列表里的 src/units.ts 标着冲突。右边两张卡片是两个分支上的 units.ts，箭头指向下方空着的结果框，结果框下面是 “选择合并工具” 按钮。]{name="conflict" frame="window" markers="24,18 47,55 76,37 76,73 84,86"}

1. 横幅显示正在进行的操作，还剩几个冲突。
2. 一个有冲突的文件。选中它，就打开冲突向导。
3. 文件的两个版本，两边各一个。
4. 结果：文件最后的样子。
5. 解决这个文件、或打开合并工具的按钮。

## 进行中的操作 {#banner}

合并、变基、摘取或反转进行期间，工作区顶部有一条横幅：

- 标题写着正在做什么，比如 :ui[conflict.title.merge]{1="feature/units-toggle" 2="main"}。
- 下面是未解决冲突的个数。操作在冲突上停下过以后，括号里还会写已解决几个。
- 一句提示告诉你下一步做什么。变基或一连串提交的操作进行时，进度条显示到了第几步。
- :ui[working.onlyConflicts] 让文件列表只留下这次冲突的文件，已解决的也留着。Spooky 会记住这个选择，所有仓库都一样。
- :ui[working.abort] 取消这次操作。见 [继续或中止](#continue)。

冲突全部解决之前，提交区是隐藏的。

## 使用冲突向导 {#wizard}

在工作区里选中一个有冲突的文件，右边就打开冲突向导。两边各有一张卡片，比如 :ui[conflict.version]{1="main"}。卡片上写着文件、这一边对它做了什么（比如 :ui[conflict.change.modified]），以及它来自哪个提交。

想留下其中一边：

1. 点这一边的卡片，结果框里就显示这个版本。
2. 点 :ui[conflict.resolveUsing]{1="main"}。

Spooky 把这个版本写进文件并暂存，文件就算解决了。如果这一边删掉了文件，文件就会被删除。

想把两边合在一起，两张卡片都点上，再点结果框下面的按钮。它会打开合并工具，见 [在别的 App 里合并](#merge-tool)。

如果你已经自己改过文件，比如在文本编辑器里，结果框会显示 :ui[conflict.result]。点 :ui[conflict.resolveCurrent]，按文件现在的样子暂存。回到 Spooky 时，向导会重新读取文件。

卡片上的 “…” 按钮打开这个版本的菜单：

- :ui[conflict.open]{1="main"}，或者用别的 App 打开
- :ui[conflict.export]{1="main"}
- :ui[conflict.compareOther]{1="feature/units-toggle"}
- :ui[conflict.compareBase]

## 在别的 App 里合并 {#merge-tool}

合并工具把两个版本并排显示，可以一行一行挑改动。它一次处理一个文件，两边都有这个文件时才能用。

1. 在冲突向导里点 :ui[externalTool.chooseMergeTool]，选一个 App。以后这个按钮就是 :ui[externalTool.mergeIn]{1="FileMerge"}。
2. 在那个 App 里合并文件，保存结果，然后退出它。

Spooky 把结果写进文件，标记为已解决。App 没有保存结果的话，Spooky 会提示 :ui[externalTool.noResult]，冲突仍然留着。

FileMerge 稍有不同。它打开期间，Spooky 显示 :ui[externalTool.finishMerge]{1="FileMerge"}。在 FileMerge 里保存结果，再点 :ui[externalTool.done]。

Spooky 支持 Araxis Merge、Beyond Compare、DeltaWalker、FileMerge、Kaleidoscope、P4Merge 与 Visual Studio Code。想换一个，改 :ui[app.name > settings.title] › :ui[settings.gitConfig] 里的 :ui[externalTool.mergeTool]。在同一处打开 :ui[externalTool.keepBackups]，合并前的文件会留下来，比如存成 `src/units.ts.orig`。

合并期间文件在别处被改过的话，Spooky 会先问，再覆盖它。

:::note[服务器仓库]
合并工具拿到的是各个版本的副本，放在这台 Mac 上的一个临时文件夹里。Spooky 把结果写回服务器，再标记为已解决。关掉仓库时，这个文件夹会被删掉。
:::

## 其它解决方法 {#other-ways}

右键点按一个或几个有冲突的文件：

- :ui[conflict.menu.resolve]
  - :ui[conflict.markResolved.one]{1="src/units.ts"} 按文件现在的样子暂存。勾选文件的复选框也一样。
  - :ui[conflict.resolveUsingVersion]{1="main"} 留下其中一边，和向导里一样。
- :ui[conflict.menu.restore]
  - :ui[conflict.restoreUnmerged.one]{1="src/units.ts"} 让冲突重新出现，已经解决的文件也可以。
  - :ui[conflict.restoreVersion]{1="main"} 与 :ui[conflict.restoreAncestor] 把一个版本放进文件，文件仍然是未解决的。

:::caution
恢复会直接覆盖工作区里的文件，不会先问。你对它做的修改都会丢掉。
:::

应用储藏或补丁时停在冲突上，没有可以继续或中止的操作，也没有横幅。向导把应用进来的一边叫作 :ui[conflict.version.applied]。文件都解决以后，这些改动就和别的改动一样留在工作区里。

## 继续或中止 {#continue}

冲突全部解决以后，提交区重新出现，里面是 Git 为这次操作准备好的提交信息。

- **合并，或者只摘取、反转一个提交**：检查信息，点 :ui[working.commit]。
- **变基，或者摘取、反转好几个提交**：检查信息，点 :ui[working.continue]。Spooky 提交这一步，接着做下一步。下一步也可能再停在冲突上。
- **变基停下来编辑某个提交**：做好你的提交，再点横幅上的 :ui[working.endEditing]。

有时已经没有可提交的改动，比如你留下的正是原来的版本。这时点 :ui[working.commit] 或 :ui[working.continue]，Spooky 会问 :ui[commit.empty.title] 点 :ui[commit.empty.use] 就做一个空提交。另一个按钮会中止合并；在变基或一连串提交里，是跳过这一步。变基或一连串提交里，也可以点横幅上的 :ui[working.skip]。

想放弃，点横幅上的 :ui[working.abort]。仓库会回到操作开始之前的样子。

:::caution
中止会立刻执行，不会先问，也撤销不了。已经解决的冲突都会丢掉。
:::

## 相关页面

- [查看与挑选改动](/guide/work/diff/)
- [储藏](/guide/work/stash/)
- [撤销与找回](/guide/work/undo/)
