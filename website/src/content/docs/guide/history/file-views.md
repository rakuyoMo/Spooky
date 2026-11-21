---
title: "File History and Blame"
description: "Follow a file through its history, see who changed each line with Blame, view a file as it was at a revision, and restore it from that revision."
---

These views look at one file at a time: the commits that changed it, who wrote each line, and how it read at any point in the past.

## File history {#file-history}

To see every commit that changed a file:

- In the Working Copy, right-click the file and choose :ui[fileHistory.showHistoryOf]{1="units.ts"}.
- Or hold the pointer over the file name at the top of the right column, and click :ui[fileHistory.title].
- In [commit details](/guide/history/commit-details/#changeset), right-click a file in the changeset or the file tree, and choose the same item.

In the Working Copy, you can also select a folder and click :ui[fileHistory.title] at the top of the right column. The history then covers every file inside it.

The left column lists the commits, newest first, grouped by month. At the top are the file name and the number of commits. Click the file name to switch to another file.

Select a commit to see what it changed in the file on the right. Switch to :ui[showFile.raw] to see the whole file as it was in that commit, or back to :ui[fileHistory.diff]. Hold the pointer over the short hash at the top for more:

- :ui[blame.title] shows who wrote each line at that commit. See [Blame](#blame).
- :ui[fileHistory.showCommit] opens the commit in [full-page details](/guide/history/commit-details/#full-page).
- :ui[externalTool.action.diffTool] opens the change in your diff tool.

::screenshot[The file history of src/units.ts. The left column shows the file name and the number of commits, with the commits that changed it grouped by month. On the right is what the selected commit changed in the file. The pointer rests on the short hash. The Blame, Show Commit, and Diff Tool buttons show at the top right, next to the Diff and Raw switch.]{name="history-file-history" frame="window" markers="28.5,9 94.6,13.25 86,13.25"}

1. The file name and the number of commits
2. The switch between :ui[fileHistory.diff] and :ui[showFile.raw]
3. The buttons that show while the pointer is on the short hash

Double-click a commit, or press <kbd>Return</kbd>, to open it in full-page details as well. Right-click a commit for the same actions, plus restoring and exporting the file at that commit.

### Search the file history {#file-history-search}

Type in the search field in the toolbar to narrow the list. Click the magnifying glass in the field to choose what to search: :ui[fileHistory.scope.message], :ui[fileHistory.scope.hash], :ui[fileHistory.scope.author], or :ui[fileHistory.scope.committer].

- Messages, authors, and committers match the text you type, ignoring case. Authors and committers match by name or email.
- A commit hash, branch, or tag shows the most recent commit up to that point that changed the file.

## Blame {#blame}

Blame shows the whole file, with a column on the right that says which commit last changed each block of lines. Each block shows the author’s avatar, the first line of the commit message, the author, and how long ago it was.

- In the Working Copy, right-click a file and choose :ui[blame.show]{1="units.ts"}. Or hold the pointer over the file name at the top of the right column, and click :ui[blame.title].
- In the changeset or file tree of a commit, choose :ui[fileHistory.blameAt]{1="units.ts" 2="e2dda2bc"} to see the file as it was then.

::screenshot[Blame for src/units.ts. The file is on the left. The column on the right shows the avatar, message, author, and age of the commit that last changed each block. The blocks from Drop trailing zeros from temperatures are highlighted.]{name="history-blame" frame="window" markers="84,22 84,82.5"}

1. The column that shows which commit last changed each block
2. The highlighted blocks of the commit you clicked

Click a block to see a summary of its commit. Every block from that commit lights up. Double-click a block to open its commit in full-page details. To make the column wider or narrower, drag its left edge. Spooky remembers the width.

Blame needs a file that’s already committed. It can’t show new or untracked files, binary files, or submodules.

## View a file at a revision {#show-file}

To read a file as it was in any commit, without changing your Working Copy:

- In the Working Copy, right-click a file and choose :ui[showFile.show]{1="units.ts"}. This shows the version in HEAD.
- In the changeset or file tree of a commit, choose :ui[fileHistory.showAt]{1="units.ts" 2="e2dda2bc"}.

The header reads like a path: revision › file.

- Click the revision to pick another commit. Double-click a commit in the list to switch to it.
- Click the file name to pick another file from the same commit.
- :ui[showFile.raw] and :ui[blame.title] switch between the plain file and [Blame](#blame).
- Hold the pointer over the header for :ui[fileHistory.title] and :ui[fileHistory.showCommit].

Below the header, Spooky counts the people who have changed the file, with their avatars. The text uses your theme and the settings in :ui[app.name > settings.title] › :ui[settings.text]. See [Text](/guide/settings/appearance/#text).

Like Blame, this view can’t show new or untracked files, binary files, or submodules.

## Restore a file from a revision {#restore}

To put a file back the way it was in an older commit:

1. Right-click the commit in the file history and choose :ui[fileHistory.restoreAt]{1="units.ts" 2="e2dda2bc"} in the menu. In [commit details](/guide/history/commit-details/#changeset), the item is :ui[fileHistory.restoreInWorkingCopy]{1="units.ts" 2="e2dda2bc"} instead.
2. Spooky asks first. Click :ui[fileHistory.restore.submit].

Both the staged and unstaged changes in the file are replaced. If the file didn’t exist in that commit, it’s deleted. Nothing is committed: the restored file shows up in the Working Copy as a staged change.

To take it back, choose :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

You can restore several files or folders at once from the changeset or the file tree.

:::note[Server repositories]
The file is overwritten on the server. Select :ui[dialog.doNotAskAgain] to skip the question next time. To be asked again, turn on :ui[settings.warnRestoringOnServer] in :ui[app.name > settings.title] › :ui[settings.general]. See [Confirmations](/guide/settings/general/#confirmations).
:::

## See also

- [Commit Details](/guide/history/commit-details/)
- [Working Copy](/guide/work/working-copy/)
- [Undo and Recovery](/guide/work/undo/)
