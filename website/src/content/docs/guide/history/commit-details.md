---
title: "Commit Details"
description: "Inspect a commit’s details, changeset, file tree, and signature status, compare revisions, and export files."
---

Select a commit in [History](/guide/history/browse/) and the right column shows its details: who made it and when, the full message, and the files it changed.

## The header {#header}

The bar at the top shows the commit’s short hash and the :ui[history.changeset] and :ui[history.tree] buttons. You can select and copy the hash. Below the bar, the header lists:

- :ui[history.author] and :ui[history.committer], with their dates. The avatar on the right is the author’s. If someone else committed it, the committer’s avatar sits to its left.
- :ui[history.refs], the branches and tags that point at the commit
- :ui[history.hash], the full hash
- :ui[history.parentHash], one row for each parent
- :ui[history.treeHash]
- The signature, if the commit is signed. See [Signatures](#signatures).

Click the arrow at the top right to collapse the header to the author, the date, and the refs. Spooky remembers your choice. The full message follows the header.

### Action buttons {#actions}

Hold the pointer over the details, and a row of buttons fades in on the line between the header and the message:

- :ui[history.rollback] opens the dialog for resetting the current branch to this commit. See [Reset to an older commit](/guide/history/rewrite/#reset).
- :ui[rewrite.revert.button] opens the dialog for adding a commit that undoes this one. See [Revert a commit](/guide/history/rewrite/#revert).
- :ui[history.diffTool] opens all the commit’s changes in your diff tool. See [Compare in another app](/guide/work/diff/#external).

:ui[history.rollback] and :ui[rewrite.revert.button] only appear while the list shows the branch you’re on.

## The changeset {#changeset}

:ui[history.changeset] lists the files the commit changed, sorted by path. The line above the list counts the files, additions, and deletions.

- Click the arrow next to a file to show its changes. To show or hide the changes of every file, click :ui[history.expandAll] or :ui[history.collapseAll] at the start of the line above the list, or press <kbd>⌃⌘→</kbd> or <kbd>⌃⌘←</kbd>.
- Click a file to select it. <kbd>⇧</kbd>-click or <kbd>⌘</kbd>-click selects several. <kbd>↑</kbd> <kbd>↓</kbd> move the selection.

Files start collapsed. To have them open on their own, choose a number under :ui[history.autoExpand.title] in :ui[menu.view > history.diffs]. A commit that changes no more files than that opens every diff. :ui[history.autoExpand.always] opens them all the time.

For a merge commit, :ui[history.mergeDiff] in :ui[app.name > settings.title] › :ui[settings.general] decides what the changeset shows:

- :ui[history.mergeDiff.firstParent] (the default) shows the changes the merge brought into the branch.
- :ui[history.mergeDiff.mergedFilePaths] shows only the files that differ from every parent.
- :ui[history.mergeDiff.off] shows no changes.

See [History and diffs](/guide/settings/general/#history).

Right-click a file to:

- Copy its path, or its path inside the repository
- View the file as it was in this commit, its Blame, or its history. See [File History and Blame](/guide/history/file-views/).
- Open it in your diff tool, compared with the commit’s first parent
- Restore it in the Working Copy to this commit’s version. See [Restore a file from a revision](/guide/history/file-views/#restore).
- Save this commit’s version of it on your Mac

With several files selected, you can open them in your diff tool, restore them, or export them together.

## The file tree {#tree}

:ui[history.tree] shows every file in the repository as it was in this commit, not just the changed ones. Click the arrow next to a folder to open it.

Right-click a file or folder to:

- Open the file in its default app, or in an app you choose
- View the file, its Blame, or its history
- Restore it in the Working Copy to this commit’s version
- Export it, or save it as a zip archive

Opening and viewing work on files only. With several items selected, you can open, restore, export, or archive them together. Exported items go into a folder you choose. If items with the same names are already there, Spooky asks before it overwrites them.

## Full-page details {#full-page}

Double-click a commit in the list to give its details the whole window. The left column shows the commit, with the list of changed files below it. The right column shows the changes in the selected file.

- Click the short hash at the top left to pick another commit. Double-click a commit in the list to switch to it.
- Double-click a file, or press <kbd>Return</kbd>, to open this commit’s version of it in its default app.

To go back to the history, choose :ui[menu.view > navigation.back] (<kbd>⌘[</kbd>), or click :ui[toolbar.previous] in the toolbar.

## Several commits {#multiple}

Select more than one commit, and the right column shows how many. Below that are these buttons:

- :ui[rewrite.cherryPick.button] applies the commits to the branch you’re on. While the list shows that branch, the button is :ui[rewrite.revert.button] instead. See [Rewrite History](/guide/history/rewrite/).
- :ui[compare.submit] appears when exactly two commits are selected. It shows what changed from the older commit to the newer one. Hold <kbd>⌥</kbd> to compare the other way.

## Signatures {#signatures}

The details check the signature of the commit you select. The expanded header shows the key and the status, such as :ui[signature.good].

To see signatures in the list too, turn on :ui[signature.verify] in the [view options](/guide/history/browse/#view-options). Signed commits then get a dot at the end of the row:

- Green: the signature is good.
- Red: the signature is bad.
- Yellow: any other status, such as an expired key or a signature Spooky can’t check.

Click the dot to see the key and the status.

## Compare two revisions {#compare}

To see what changed between any two commits, branches, or tags:

1. Choose :ui[menu.repository > compare.menu] in the menu bar. Or right-click a commit and choose :ui[compare.menuFrom]{1="e2dda2bc"} to start from it.
2. Fill in :ui[compare.base] and :ui[compare.target]. The menus list your branches, remote branches, and tags. You can also type a hash.
3. Click :ui[compare.submit].

The right column shows the comparison. :ui[compare.commits] lists the commits that the second revision has and the first doesn’t. :ui[history.changeset] shows the changes from the first to the second. To close it, click × at the top right, or select another commit.

With two commits selected, the menu offers :ui[compare.menuPair]{1="e2dda2bc" 2="f6b437e0"} directly.

## Export files {#export}

To save all the files of a commit as they were at that point:

1. Right-click a commit and choose :ui[export.menuFrom]{1="e2dda2bc"} in the menu. :ui[menu.repository > export.menu] in the menu bar starts from the selected commit.
2. Check the revision. To get a single zip file, select :ui[export.createArchive].
3. Click :ui[export.submit] and choose where to save.

Without an archive, you get a folder named after the repository and the short hash.

The export shows up in the [Activity window](/guide/advanced/queue-activity/), where you can cancel it.

## Save a patch {#patch}

A patch is a text file with a commit’s changes. You can apply it in another repository with `git am`.

1. Right-click a commit and choose :ui[patch.menu]{1="e2dda2bc"} in the menu. With several commits selected, the item saves a patch for each.
2. Select :ui[patch.omitPrefixes] to leave out the `a/` and `b/` before each path.
3. Click :ui[patch.save] and choose a folder.

Each commit gets its own file, numbered from oldest to newest, like `0001-Add-a-theme-toggle-to-the-header.patch`. When it’s done, Finder opens with the files selected. Saving also shows up in the Activity window.

Hold <kbd>⌥</kbd> in the menu for :ui[patch.quickMenu]{1="e2dda2bc"}. It saves into the repository’s folder right away, with your last :ui[patch.omitPrefixes] choice.

:::note[Server repositories]
Exports and patches you save with :ui[patch.save] go to your Mac. A quick-saved patch goes into the repository’s folder on the server.
:::

## Copy commit information {#copy}

Right-click a commit to copy:

- :ui[history.copyHash], the full hash
- :ui[history.copyInfo], the short hash and the first line of the message

With several commits selected, you get one line for each.

## See also

- [Browse History](/guide/history/browse/)
- [File History and Blame](/guide/history/file-views/)
- [Rewrite History](/guide/history/rewrite/)
