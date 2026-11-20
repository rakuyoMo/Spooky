---
title: "Review and Stage Changes"
description: "Read the changes in a file, adjust how diffs are shown, and stage or discard changes by file, by chunk, or by line."
---

Select a file in the Working Copy, and the right column shows its diff: what changed, line by line. From there, you can stage only the parts that belong in the next commit and throw away the rest.

## Read a diff {#read}

A diff is split into chunks. A chunk is a group of changed lines with a few unchanged lines around them. Its header line tells where the chunk is in the file.

- Added lines are green, and removed lines are red. The two columns of line numbers are for the old and the new version of the file.
- When a file has both staged and unstaged changes, switch between them with :ui[working.unstaged] and :ui[working.staged] at the top of the column. A side with no changes is dimmed.
- The bar below the diff shows the number of chunks and how many lines were added and removed.
- For an image, the diff shows the old and new picture. :ui[diff.twoUp] puts them side by side. :ui[diff.oneUp] shows one at a time, and you switch between :ui[diff.old] and :ui[diff.new].

A very large diff can make the window slow, so Spooky asks first: :ui[working.largeDiff] Click :ui[working.showDiff] to see it. The size limit is :ui[working.diffThreshold] in :ui[app.name > settings.title] › :ui[settings.general]. It’s 20,000 kB by default.

## Diff options {#options}

The bar below the diff has the options you change most often:

- At its left end are two buttons. Hold the pointer over them to see their names.
  - :ui[diff.ignoreWhitespace] leaves out changes that only touch spaces and tabs. If nothing else changed in the file, the diff says :ui[diff.onlyWhitespace]
  - :ui[diff.showEntireFile] shows the whole file with the changes in place. It applies only to the diff you’re looking at.
- At its right end, :ui[diff.context] sets how many unchanged lines appear around each change. The default is 3. You can also choose it from :ui[menu.view > diff.contextMenu].

The whitespace and context settings apply everywhere: in all repositories, in the Working Copy, and in the history.

More options are in :ui[app.name > settings.title] › :ui[settings.text]:

| Setting | What it does |
|---|---|
| :ui[text.enableSyntaxColoring] | Colors code by its language. On by default. |
| :ui[text.syntaxColoringInDiffs] | Uses syntax colors in diffs too. Off by default. |
| :ui[text.showInvisibles] | Shows spaces, tabs, and line endings as symbols |
| :ui[text.tabWidth] | How wide a tab is, in spaces |

The colors come from the theme. See [Appearance and Themes](/guide/settings/appearance/).

## Stage whole files {#stage-file}

Staging picks the changes that go into the next commit. To stage whole files, do one of the following:

- Select the checkbox in front of the file. If the file is selected, all selected files are staged.
- Select files and press <kbd>Space</kbd>. If a selected file has unstaged changes, Space stages it. Otherwise it unstages it.
- Click :ui[working.stageAll] above the list, or choose :ui[workspace.title > working.stageAllMenu] (<kbd>⇧⌘E</kbd>).

To unstage, clear the checkbox, press <kbd>Space</kbd> again, or choose :ui[workspace.title > working.unstageAllMenu] (<kbd>⌥⇧⌘E</kbd>). When everything is staged, the :ui[working.stageAll] button turns into :ui[working.unstageAll]. While only some changes are staged, hold <kbd>⌥</kbd> to switch it.

## Stage chunks {#chunks}

Each chunk has buttons at the right end of its header line:

- On the :ui[working.unstaged] side: :ui[working.discardChunk] and :ui[working.stageChunk]
- On the :ui[working.staged] side: :ui[working.unstageChunk]

The chunk moves to the other side right away. The rest of the file stays where it was.

## Stage lines {#lines}

When a chunk mixes changes for different commits, stage only some of its lines.

1. Click the line number of a changed line to select it. Click it again to deselect it.
2. To select more lines, click their numbers too. Drag across line numbers to select a run of lines, or hold <kbd>⇧</kbd> and click to select every line in between.
3. Click :ui[working.stageLines] in the chunk header.

::screenshot[A chunk in the diff of src/readings.ts. Five lines are selected by their line numbers, and the chunk header shows the Discard Lines and Stage Lines buttons.]{name="staging" frame="closeup"}

Only changed lines can be selected. Each chunk has its own selection, and its buttons work on the lines selected in it. On the :ui[working.staged] side, the button is :ui[working.unstageLines].

## Discard changes {#discard}

Discarding throws away changes you don’t want to keep.

- **A file**: right-click it and choose :ui[working.discard.menu] from the menu, or choose :ui[workspace.title > working.discardMenu] (<kbd>⇧⌘⌫</kbd>).
- **Everything**: choose :ui[workspace.title > working.discardAllMenu] from the menu bar.
- **A chunk or some lines**: click :ui[working.discardChunk] or :ui[working.discardLines] in the chunk header.

For files, Spooky asks first. Tracked files go back to how they were in the last commit, including any staged changes. New files go to the Trash. Click :ui[working.discard] or :ui[working.discardAll.submit] to go ahead.

For chunks and lines, Spooky asks :ui[working.discardContent.title] Select :ui[dialog.doNotAskAgain] to skip the question next time. To get it back, turn on :ui[settings.warnDiscardingChunks] in :ui[app.name > settings.title] › :ui[settings.general].

:::caution
Discarded changes aren’t in any commit. The only way back is :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>), and only until the repository changes again. New files come back from the Trash as long as they’re still there.
:::

:::note[Server repositories]
Discarding overwrites the files on the server. New files go to the server’s Trash. If the server has no Trash, they’re deleted for good. The question has :ui[dialog.doNotAskAgain]. To get it back, turn on :ui[settings.warnDiscardingOnServer] in :ui[settings.general].
:::

## Compare in another app {#external}

To look at a change in a diff app, such as FileMerge or Kaleidoscope:

- Hold the pointer over the file name at the top of the right column, and click :ui[externalTool.action.diffTool]. It compares the side you’re looking at.
- Or right-click the file and choose from the :ui[externalTool.compare] submenu: :ui[externalTool.compare.workingTreeToBase], :ui[externalTool.compare.workingTreeToIndex], or :ui[externalTool.compare.indexToBase].

The first time, Spooky asks which app to use. To change it later, use :ui[externalTool.diffTool] in :ui[app.name > settings.title] › :ui[settings.gitConfig]. Spooky works with Araxis Merge, BBEdit, Beyond Compare, DeltaWalker, FileMerge, Kaleidoscope, P4Merge, TextMate, and Visual Studio Code.

:::note[Server repositories]
The diff app gets copies of the files in a temporary folder on your Mac. The folder is removed when you close the repository.
:::

## See also

- [Working Copy](/guide/work/working-copy/)
- [Commit Changes](/guide/work/commit/)
- [Undo and Recovery](/guide/work/undo/)
