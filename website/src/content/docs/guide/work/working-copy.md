---
title: "Working Copy"
description: "Read the status of your changed files, show them as a list or a tree, sort and search them, handle untracked and ignored files, and use file actions and Quick Look."
---

The Working Copy shows what you changed since the last commit. Here you pick the changes for the next commit, look into files, and keep Git away from files it shouldn’t track.

To open it, click :ui[workspace.title] at the top of the sidebar, or choose :ui[menu.view > menu.showWorkingCopy] (<kbd>⌘1</kbd>). The commit area sits at the top of the middle column, and the changed files are listed below it. [Commit Changes](/guide/work/commit/) covers the commit area.

## Read the status {#status}

Each changed file has a row with a checkbox, two status badges, and its name.

- The checkbox shows whether the change is staged. A dash means only part of the file is staged.
- The left badge is the staged change. The right badge is the change that isn’t staged yet.
- The letters are Git’s status codes: M for modified, A for added, D for deleted, and R for renamed. A new file that Git doesn’t track yet shows ?, and an ignored file shows !.
- A file with a conflict shows two conflict codes, such as U U. See [Resolve Conflicts](/guide/work/conflicts/).

Hold the pointer over the badges to see the status in words.

The line above the list shows the current branch, followed by the remote branch it tracks. If it doesn’t track one, the line says :ui[branch.noTracking].

Spooky updates the list on its own when files change. To read everything again, click :ui[action.refresh] or press <kbd>⌘R</kbd>.

:::note[Server repositories]
Spooky checks the server for changes every 2 seconds while the repository’s window is in front, and every 10 seconds otherwise. A change made on the server can take that long to show up. See [How server repositories differ](/guide/server/overview/#differences).
:::

## Show a list or a tree {#view}

The :ui[menu.view > files.statusMenu] menu changes what the list shows. The button at the right end of the branch line has the same items.

| Item | What it does |
|---|---|
| :ui[working.list] (<kbd>⌃⌘L</kbd>) | One row per file, with its full path |
| :ui[working.tree] (<kbd>⌃⌘T</kbd>) | Files grouped in their folders. Double-click a folder to expand or collapse it. |
| :ui[files.showNonModified] (<kbd>⌃⌘M</kbd>) | Lists every file in the repository, not only the changed ones. Available in the tree. |
| :ui[files.showIgnored] (<kbd>⌃⌘I</kbd>) | Lists the files Git ignores |
| :ui[files.showAssumeUnchanged] | Lists the files marked assume-unchanged. See [Untracked and ignored files](#untracked-ignored). |

Each repository remembers whether it shows a list or a tree. A repository starts out as a list. The other items apply to all repositories.

## Sort {#sort}

Click the :ui[status.filename] or :ui[status.column] column header to sort by it. Click it again to reverse the order. The order is the same in all repositories and windows.

The first click on :ui[status.column] puts staged files first. Next come the other changes, then new files, and last the unchanged and ignored ones.

## Find a file {#search}

1. Press <kbd>⌘F</kbd>, or click the search field in the toolbar. It reads :ui[history.search.forFile].
2. Type part of the file’s path. Spooky suggests files that contain those letters in the same order.
3. Choose a file to list only that path. The last suggestion lists every file whose path contains what you typed.

Clear the search field to see all files again.

## Untracked and ignored files {#untracked-ignored}

A new file is untracked until you stage it and commit. Untracked files show ? and are listed with the other changes. To add one to the next commit, stage it like any other change.

Some files should never be committed, like build output or local notes. To keep Git from listing them, right-click the file and choose a rule:

- :ui[files.ignore] adds the rule to the `.gitignore` file at the repository root. Commit `.gitignore`, and the rule applies for everyone who uses the repository.
- :ui[files.exclude] adds the rule to `info/exclude` in the Git folder. The rule applies only to this copy of the repository and is never committed.

Both submenus let you ignore just this item, every item with the same name, every item with the same extension, or a pattern you type.

Ignore rules don’t apply to files Git already tracks. If you ignore a tracked file, Spooky asks whether to untrack it as well. Click :ui[files.untrack] to stop tracking it, or :ui[files.untrackIgnored.skip] to keep tracking it. The file stays in your folder either way.

To stop tracking a file without an ignore rule, right-click it and choose :ui[files.untrack]. The next commit removes it from the repository, and the file stays in your folder.

:ui[files.mark > files.assumeUnchanged.set] tells Git to leave out your local changes to a tracked file, for example a config file you edit only on your Mac. The file disappears from the list. To see it again, turn on :ui[files.showAssumeUnchanged], then choose :ui[files.mark > files.assumeUnchanged.unset].

## File actions {#file-actions}

Right-click a file for its actions. If you right-click a row inside the selection, the action applies to every selected file. Outside the selection, it applies only to the row you clicked.

::screenshot[The shortcut menu for src/readings.ts in the Working Copy. From top to bottom, it has items for opening the file and copying its path, Quick Look, staging and moving it to the Trash, conflicts, discarding and stashing, Blame and file history, ignoring it, and comparing.]{name="work-file-menu" frame="closeup"}

| To | Choose |
|---|---|
| Open the file | :ui[files.open], or an app from :ui[files.openWith]. You can also double-click the file. |
| Copy its path | :ui[workspace.copyPathMenu] or :ui[working.copyRelative] |
| Show it in Finder or Terminal | :ui[action.revealFinder] or :ui[action.openTerminal] |
| Move or rename it | :ui[files.move.menu] |
| Move it to the Trash | :ui[files.trash], or press <kbd>⌘⌫</kbd> |
| Throw away your changes | :ui[working.discard.menu] (see [Discard changes](/guide/work/diff/#discard)) |
| Put it on a stash | See [Stash some files](/guide/work/stash/#partial). |
| Restore an older version | :ui[files.revert.menu] |
| Look at its history | :ui[quickActions.showFileHistory] or :ui[quickActions.showBlame] (see [File History and Blame](/guide/history/file-views/)) |
| Compare it in another app | :ui[externalTool.compare] (see [Compare in another app](/guide/work/diff/#external)) |

:ui[files.trash] doesn’t ask first. A tracked file you move to the Trash shows up as a staged deletion. To bring it back, choose :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

:::note[Server repositories]
:ui[files.trash] moves files to the server’s Trash. If the server has no Trash, the item reads :ui[files.delete], and Spooky asks before it deletes the files for good. Most apps get a copy of the file, and Spooky writes your changes back to the server when you save. See [Terminal and other apps](/guide/server/local-location/#terminal).
:::

## Quick Look {#quick-look}

To preview a file without opening an app, right-click it and choose :ui[files.quickLook.single]{1="README.md"}.

If you use Quick Look often, have the Space bar open it: choose :ui[app.name > settings.title] › :ui[settings.general], then set :ui[files.spacebar] to :ui[files.spacebar.quickLook]. By default, Space stages or unstages the selected files. See [File list](/guide/settings/general/#file-list).

:::note[Server repositories]
Spooky first downloads the file to a temporary folder on your Mac. The folder is removed when you close the repository.
:::

## Settings for the file list {#settings}

These are in :ui[app.name > settings.title] › :ui[settings.general]:

| Setting | Choices |
|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] (default) or :ui[files.doubleClick.openDiff] |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] (default) or :ui[files.spacebar.quickLook] |
| :ui[files.fontSize] | :ui[files.fontSize.regular] or :ui[files.fontSize.medium] (default) |
| :ui[files.truncation] | :ui[files.truncation.beginning] (default) or :ui[files.truncation.middle] |

See [File list](/guide/settings/general/#file-list).

## See also

- [Review and Stage Changes](/guide/work/diff/)
- [Commit Changes](/guide/work/commit/)
- [File History and Blame](/guide/history/file-views/)
