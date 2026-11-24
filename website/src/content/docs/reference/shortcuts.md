---
title: "Keyboard Shortcuts"
description: "Look up every keyboard shortcut in Spooky."
---

Menu items show their shortcuts next to them. This page collects them all, along with the keys that work in particular places, such as the commit area, lists, and dialogs. The symbols are explained in [Keyboard shortcuts](/guide/#shortcuts).

A shortcut works only while its menu item is available. When an item is dimmed, its shortcut does nothing.

## Menus {#menus}

### App and windows {#app-windows}

| Shortcut | Menu item |
|---|---|
| <kbd>⌘,</kbd> | :ui[app.name > settings.title] |
| <kbd>⌘H</kbd> | :ui[app.name > menu.hide] |
| <kbd>⌥⌘H</kbd> | :ui[app.name > menu.hideOthers] |
| <kbd>⌘Q</kbd> | :ui[app.name > menu.quit] |
| <kbd>⌘N</kbd> | :ui[menu.file > menu.newWindow] |
| <kbd>⌘T</kbd> | :ui[menu.file > menu.newTab] |
| <kbd>⌘W</kbd> | :ui[menu.file > menu.closeWindow] |
| <kbd>⌃⌘F</kbd> | :ui[menu.view > menu.fullscreen] |
| <kbd>⌘M</kbd> | :ui[menu.window > menu.minimize] |
| <kbd>⌃⌘0</kbd> | :ui[menu.window > activity.title] |
| <kbd>⌘?</kbd> | :ui[menu.help > help.help] |

### Repositories {#repositories}

| Shortcut | Menu item |
|---|---|
| <kbd>⌘O</kbd> | :ui[menu.file > action.openLocal] |
| <kbd>⌃⌘C</kbd> | :ui[menu.file > clone.menu] |
| <kbd>⇧⌘A</kbd> | :ui[menu.file > quickActions.menu] |
| <kbd>⌃⌘R</kbd> | :ui[menu.view > menu.showRepositories] |

### Views {#views}

| Shortcut | Menu item |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.view > menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.view > menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[menu.view > stash.show] |
| <kbd>⌘4</kbd> | :ui[menu.view > pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[menu.view > review.show] |
| <kbd>⌘6</kbd> | :ui[menu.view > reflog.show] |
| <kbd>⌘0</kbd> | :ui[menu.view > history.showHead] |
| <kbd>⌘[</kbd> | :ui[menu.view > navigation.back] |
| <kbd>⌘]</kbd> | :ui[menu.view > navigation.forward] |
| <kbd>⌘R</kbd> | :ui[menu.view > action.refresh] |
| <kbd>⌃⌘T</kbd> | :ui[menu.view > files.statusMenu > working.tree] |
| <kbd>⌃⌘L</kbd> | :ui[menu.view > files.statusMenu > working.list] |
| <kbd>⌃⌘M</kbd> | :ui[menu.view > files.statusMenu > files.showNonModified] |
| <kbd>⌃⌘I</kbd> | :ui[menu.view > files.statusMenu > files.showIgnored] |
| <kbd>⌃⌘G</kbd> | :ui[menu.view > history.title > history.showGraph] |
| <kbd>⌃⌥⌘C</kbd> | :ui[menu.view > history.title > history.compareBranches] |
| <kbd>⌃⌘→</kbd> | :ui[menu.view > history.diffs > history.expandAll] |
| <kbd>⌃⌘←</kbd> | :ui[menu.view > history.diffs > history.collapseAll] |

### Edit and find {#edit}

| Shortcut | Menu item |
|---|---|
| <kbd>⌘Z</kbd> | :ui[menu.edit > menu.undo] |
| <kbd>⇧⌘Z</kbd> | :ui[menu.edit > menu.redo] |
| <kbd>⌘X</kbd> | :ui[menu.edit > menu.cut] |
| <kbd>⌘C</kbd> | :ui[menu.edit > menu.copy] |
| <kbd>⌘V</kbd> | :ui[menu.edit > menu.paste] |
| <kbd>⌥⇧⌘V</kbd> | :ui[menu.edit > menu.pasteAndMatchStyle] |
| <kbd>⌘⌫</kbd> | :ui[menu.edit > menu.delete] |
| <kbd>⌘A</kbd> | :ui[menu.edit > menu.selectAll] |
| <kbd>⇧⌘W</kbd> | :ui[menu.edit > commit.reformatParagraph] |
| <kbd>⌘F</kbd> | :ui[menu.edit > menu.find > action.find] |
| <kbd>⌥⌘F</kbd> | :ui[menu.edit > menu.find > action.search] |
| <kbd>⌘G</kbd> | :ui[menu.edit > menu.find > menu.findNext] |
| <kbd>⇧⌘G</kbd> | :ui[menu.edit > menu.find > menu.findPrevious] |
| <kbd>⌘E</kbd> | :ui[menu.edit > menu.find > menu.useSelectionForFind] |
| <kbd>⌘J</kbd> | :ui[menu.edit > menu.find > menu.jumpToSelection] |
| <kbd>⌘:</kbd> | :ui[menu.edit > menu.spelling > menu.showSpelling] |
| <kbd>⌘;</kbd> | :ui[menu.edit > menu.spelling > menu.checkDocument] |

- See [Undo and redo](/guide/work/undo/#undo) for what :ui[menu.undo] can undo.
- :ui[menu.delete] also deletes what’s selected in some lists. See [Lists](#lists).
- :ui[action.find] and :ui[action.search] both put the cursor in the search field in the toolbar. See [Search and filter](/guide/history/browse/#search) and [Find a file](/guide/work/working-copy/#search).
- :ui[commit.reformatParagraph] works in the commit message. See [Write the message](/guide/work/commit/#write).

### Branches and sync {#sync}

| Shortcut | Menu item |
|---|---|
| <kbd>⌘B</kbd> | :ui[menu.repository > branch.createMenu] |
| <kbd>⇧⌘T</kbd> | :ui[menu.repository > tag.createMenu] |
| <kbd>⌃⌘P</kbd> | :ui[menu.repository > pr.create.menu] |
| <kbd>⇧⌘F</kbd> | :ui[menu.repository > sync.fetchMenu] |
| <kbd>⌥⇧⌘F</kbd> | :ui[menu.repository > sync.quickFetch] |
| <kbd>⇧⌘P</kbd> | :ui[menu.repository > sync.pullMenu] |
| <kbd>⌥⇧⌘P</kbd> | :ui[menu.repository > sync.quickPull] |
| <kbd>⇧⌘Y</kbd> | :ui[menu.repository > sync.syncMenu] |
| <kbd>⌥⇧⌘Y</kbd> | :ui[menu.repository > sync.quickSync] |
| <kbd>⇧⌘U</kbd> | :ui[menu.repository > sync.pushMenu] |
| <kbd>⌥⇧⌘U</kbd> | :ui[menu.repository > sync.quickPushMenu] |
| <kbd>⌃⌘U</kbd> | :ui[menu.repository > sync.forcePushMenu] |
| <kbd>⇧⌘B</kbd> | :ui[workspace.title > rewrite.checkout.menu] |
| <kbd>⇧⌘M</kbd> | :ui[workspace.title > sync.mergeMenu] |
| <kbd>⌥⇧⌘M</kbd> | :ui[workspace.title > sync.quickMerge] |
| <kbd>⇧⌘R</kbd> | :ui[workspace.title > sync.rebaseMenu] |
| <kbd>⌥⇧⌘R</kbd> | :ui[workspace.title > sync.quickRebase] |
| <kbd>⌃⇧⌘R</kbd> | :ui[workspace.title > rewrite.rebaseOnto.menu] |

The items with <kbd>⌥⇧⌘</kbd> are quick versions. They take the place of the item above them while you hold <kbd>⌥</kbd> with the menu open. They run right away, without a dialog. Their shortcuts work without opening the menu. See the quick versions in [Fetch, Pull, and Push](/guide/branches/sync/#quick) and [Merge and Rebase](/guide/branches/merge-rebase/#quick).

### Changes and commits {#changes}

| Shortcut | Menu item |
|---|---|
| <kbd>⇧⌘C</kbd> | :ui[workspace.title > working.commitMenu] |
| <kbd>⇧⌘E</kbd> | :ui[workspace.title > working.stageAllMenu] |
| <kbd>⌥⇧⌘E</kbd> | :ui[workspace.title > working.unstageAllMenu] |
| <kbd>⇧⌘⌫</kbd> | :ui[workspace.title > working.discardMenu] |
| <kbd>⇧⌘S</kbd> | :ui[workspace.title > stash.saveMenu] |
| <kbd>⌥⇧⌘S</kbd> | :ui[workspace.title > stash.applyMenu] |
| <kbd>⌃⇧⌘S</kbd> | :ui[workspace.title > stash.snapshotMenu] |
| <kbd>⌃⇧⌘D</kbd> | :ui[workspace.title > externalTool.compare > externalTool.compare.workingTreeToBase] |
| <kbd>⇧⌘D</kbd> | :ui[menu.repository > externalTool.openDiffTool] |

## Hold Option {#option}

Holding <kbd>⌥</kbd> changes some buttons and menus. Let go, and they change back.

| Where | What changes |
|---|---|
| The fetch, pull, and push buttons in the toolbar, and sync, merge, and rebase once you’ve added them | They turn into quick versions. See [Fetch, Pull, and Push](/guide/branches/sync/#quick). |
| The commit area, while neither message field is being edited | It switches to amending the last commit. See [Amend the last commit](/guide/work/commit/#amend). |
| :ui[working.stageAll] above the file list, while only some changes are staged | It turns into :ui[working.unstageAll]. See [Stage whole files](/guide/work/diff/#stage-file). |
| The menu of files in the Working Copy | The stash items turn into quick versions. See [Stash some files](/guide/work/stash/#partial). |
| The menu of a submodule | Fetching and updating turn into quick versions. See [Fetch and update](/guide/advanced/submodules/#update). |
| The menu of a branch with a parent branch | Updating from the parent turns into a quick version. See [Update a branch from its parent](/guide/branches/merge-rebase/#update). |
| The menu of a commit | Saving a patch turns into a quick version. With two commits selected, comparing them goes the other way. See [Save a patch](/guide/history/commit-details/#patch). |
| :ui[compare.submit] with two commits selected | It compares the other way. See [Several commits](/guide/history/commit-details/#multiple). |
| Dragging | See [Drag with Option](#drag). |

## Commit area {#commit-area}

| Keys | What they do |
|---|---|
| <kbd>↩</kbd> or <kbd>Tab</kbd> in the subject | Moves to the description |
| <kbd>Tab</kbd> in the description | Moves to the file list |
| <kbd>⇧Tab</kbd> in the description | Moves back to the subject |
| <kbd>⌘↩</kbd> while you’re typing in the message | Clicks the main button of the commit area, such as :ui[working.commit]. <kbd>Enter</kbd> on a numeric keypad does the same. |
| <kbd>⌥⌘↩</kbd> while neither message field is being edited | Amends the last commit. See [Amend the last commit](/guide/work/commit/#amend). |
| <kbd>↑</kbd> <kbd>↓</kbd>, <kbd>↩</kbd>, <kbd>Esc</kbd> in the autocomplete list | Choose a match, insert it, and close the list |

See [Commit Changes](/guide/work/commit/).

## File list {#file-list}

These keys work in the Working Copy’s file list:

| Keys | What they do |
|---|---|
| <kbd>Space</kbd> | Stages or unstages the selected files. With :ui[files.spacebar] set to :ui[files.spacebar.quickLook], it shows them in Quick Look instead. See [File list](/guide/settings/general/#file-list). |
| <kbd>⌘⌫</kbd> | Moves the selected files to the Trash |
| <kbd>⇧Tab</kbd> | Moves back to the description of the commit message |

## Lines in a diff {#diff-lines}

In the Working Copy, press <kbd>Tab</kbd> until the line numbers of a chunk have keyboard focus. Then:

| Keys | What they do |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Move between the lines you can select |
| <kbd>Space</kbd> | Selects or deselects the line |
| <kbd>Tab</kbd> or <kbd>⇧Tab</kbd> | Leaves the line numbers |

With the mouse, hold <kbd>⇧</kbd> and click a line number to select every line in between. See [Stage lines](/guide/work/diff/#lines).

## Lists {#lists}

| Where | Keys | What they do |
|---|---|---|
| The commit list in the history | <kbd>⌘C</kbd> | Copies the full hashes of the selected commits |
| The changeset of a commit | <kbd>↑</kbd> <kbd>↓</kbd> | Move the selection |
| The changed files in full-page details | <kbd>↩</kbd> | Opens the selected files in their default apps |
| The file tree of a commit | <kbd>↩</kbd> | Opens or closes the selected folder |
| File history | <kbd>↩</kbd> | Opens the selected commit in full-page details |
| The sidebar | <kbd>⌘⌫</kbd> | Deletes the selected branches, tags, remote, or submodule, after asking |
| The filter field of the sidebar | <kbd>Esc</kbd> | Clears the field |
| Stashes | <kbd>⌘⌫</kbd> | Deletes the selected stashes, after asking |
| Branches Review | <kbd>⌘⌫</kbd> | Deletes the selected branches, after asking |
| The Repositories window | <kbd>↩</kbd> | Renames the selected entry |
| The Repositories window | <kbd>⌫</kbd> or <kbd>⌦</kbd> | Removes the selected entries. See [Remove repositories](/guide/repositories/manager/#delete). |
| The window shown at launch | <kbd>↩</kbd> | Opens the selected repository. See [Pick up where you left off](/guide/repositories/navigation/#restore). |
| The conversation of a pull request | <kbd>↩</kbd> | Opens the selected commit |
| The conversation of a pull request | <kbd>⌘S</kbd> | Clicks :ui[pullRequests.addComment] |
| :ui[settings.themes] in Settings | <kbd>↩</kbd> | Renames the selected theme |
| :ui[settings.appIcon.label] in Settings | Arrow keys, <kbd>Space</kbd> | Move between the icons, and use the one you’re on |
| :ui[settings.sshHosts] in Settings | <kbd>↩</kbd> | Opens the selected alias for editing |

In lists where you can select several items, <kbd>⇧</kbd>-click selects a range. <kbd>⌘</kbd>-click adds or removes a single item. In the sidebar, <kbd>⌘</kbd>-click branches and tags to see their history together. See [Open the history](/guide/history/browse/#open).

Hold <kbd>⌘</kbd> and double-click a branch that’s checked out in another worktree. That worktree opens in a new tab. See [Check out a branch](/guide/branches/branches/#checkout).

## Quick Actions {#quick-actions}

These keys work in the [Quick Actions](/guide/repositories/navigation/#quick-actions) panel:

| Keys | What they do |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Move the selection |
| <kbd>↩</kbd> | Runs the default action of the selected item |
| <kbd>Tab</kbd>, or <kbd>→</kbd> at the end of the text | Lists all actions for the selected item |
| <kbd>←</kbd> with no text, or <kbd>⇧Tab</kbd> | Goes back from the list of actions |
| <kbd>Esc</kbd> | Clears the text. With no text, goes back from the list of actions or closes the panel. |

## Dialogs {#dialogs}

In a dialog, <kbd>↩</kbd> clicks the highlighted button. <kbd>Esc</kbd> clicks the button that cancels. If a dialog has no such button, <kbd>Esc</kbd> clicks the highlighted button too.

## Drag with Option {#drag}

Hold <kbd>⌥</kbd> as you drop to do something else:

| Drag | Onto | Without <kbd>⌥</kbd> | With <kbd>⌥</kbd> |
|---|---|---|---|
| A local branch | :ui[workspace.title] or the branch you’re on | The merge dialog | The rebase dialog |
| A remote branch | The branch you’re on | The pull dialog | It becomes the upstream of your branch. |
| Commits from the history | :ui[workspace.title] or the branch you’re on | Cherry-pick them | Revert them |
| Commits in the history | Another commit in the list | Squash them into it | Fixup instead |

See [Drag and drop](/guide/branches/merge-rebase/#drag-and-drop) and [Squash, fixup, delete, and move](/guide/history/rewrite/#interactive).

## See also

- [Windows and Navigation](/guide/repositories/navigation/)
- [Commit Changes](/guide/work/commit/)
- [Review and Stage Changes](/guide/work/diff/)
- [Merge and Rebase](/guide/branches/merge-rebase/)
