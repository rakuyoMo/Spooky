---
title: "Undo and Recovery"
description: "Learn what ⌘Z can undo and why some operations can’t be undone, and recover lost commits with the Reflog."
---

Most things you do to a repository in Spooky can be taken back with <kbd>⌘Z</kbd>. For the rest, Git’s Reflog remembers where your branches have been, so a commit is rarely lost for good.

## Undo and redo {#undo}

Choose :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>) to take back the last operation. The menu item includes the operation’s name. Choose :ui[menu.edit > menu.redo] (<kbd>⇧⌘Z</kbd>) to do it again. You can step back through several operations, newest first.

You can undo, for example:

- Staging, committing, and amending
- Discarding changes and moving files to the Trash
- Saving, applying, and deleting stashes
- Checking out, creating, renaming, and deleting branches, and creating tags
- Pinning and archiving branches, setting the upstream, and fast-forwarding
- Merging, rebasing, cherry-picking, reverting, and resetting
- Adding, renaming, and removing remotes, and changing their settings
- Publishing branches and tags, and renaming remote branches
- Marking files as assume-unchanged, turning on Git LFS, and changing submodules

Files that went to the Trash are put back from the Trash. If you undo a reset while tracked files have changes, Spooky first asks whether to stash them. The new stash stays in the list.

While you’re typing in a text field, such as the commit message, <kbd>⌘Z</kbd> undoes your typing instead.

Each repository has one undo history, shared by all its windows. Spooky keeps it until you quit. The snapshots it needs are stored in the repository’s own Git database, and aren’t pushed anywhere.

:::note[Server repositories]
The snapshots are stored in the repository on the server. Files that went to the server’s Trash are put back from there.
:::

## What can’t be undone {#cant-undo}

Undo puts the repository back the way it was. Some changes are outside what Spooky can restore:

- Deleting branches and tags on a remote. Deleting a local branch together with its remote branch is an exception: undo recreates both.
- Changing the committer identity, ignore rules, or other Git settings.
- Anything you do while a merge, rebase, or other operation is in progress, including continuing or aborting it.
- A rebase or cherry-pick that stops on a conflict. A merge or revert that stops on conflicts can be undone, which aborts it.
- New files that were deleted for good, for example on a server without a Trash.
- Initializing, syncing, and repairing submodules; anything you do with worktrees; updating the Git LFS hooks; and publishing a repository to a hosting service. See [Submodules](/guide/advanced/submodules/#undo), [Worktrees](/guide/advanced/worktrees/#undo), [Git LFS](/guide/advanced/lfs/#undo), and [Publish a repository](/guide/hosting/accounts/#publish).

After one of these, the menu item says that the operation can’t be undone. Operations before it can’t be undone anymore either.

Fetch, pull, push, and sync aren’t recorded. They can’t be undone. The same goes for fetching and updating submodules, and for fetching, pulling, and pushing LFS content.

## When undo is blocked {#blocked}

Undo only works while the repository is still as the operation left it. When it isn’t, the menu item is dimmed and gives a reason in parentheses:

| Reason | What to do |
|---|---|
| :ui[undo.reason.busy] | Wait for the running operation to finish, or finish the merge, rebase, or other operation in progress. |
| :ui[undo.reason.disconnected] | Reconnect to the server. |
| :ui[undo.reason.changed] | The repository has changed since the operation: a pull or sync brought in commits, or Terminal or another app changed it. Put it back, and undo works again. |

Spooky checks the repository once more right before it undoes anything. If something is in the way, it stops and tells you why. Nothing is changed.

| Message | Why |
|---|---|
| :ui[undo.error.changed] | The repository no longer matches what Spooky recorded. |
| :ui[undo.error.untracked] | Restoring would overwrite or delete untracked files. |
| :ui[undo.error.hidden] | Files marked as assume-unchanged have local changes, or the repository uses skip-worktree. |
| :ui[undo.error.inProgress] | Finish or abort the merge, rebase, cherry-pick, or revert first. |
| :ui[undo.error.conflicts] | Resolve the conflicts first. See [Resolve Conflicts](/guide/work/conflicts/). |
| :ui[undo.error.trash] | Some files are no longer in the Trash, or other files are now where they were. |

## Recover commits with the Reflog {#reflog}

Git keeps a log of where HEAD and each local branch have pointed. A commit you lost by resetting, rebasing, or deleting a branch is usually still listed there. Changes you never committed aren’t.

1. Choose :ui[menu.view > reflog.show] (<kbd>⌘6</kbd>).
2. In :ui[reflog.ref] at the top, choose HEAD or a local branch.
3. Find the entry. Each one shows the short hash, what happened, and when, with Git’s description below. To filter the list, type in the search field in the toolbar.
4. Select the entry to see the commit’s details.

::screenshot[The Reflog view for HEAD. Each entry shows a short hash, an action such as commit, checkout, or reset, and a date, with the message below. The selected entry’s commit details are on the right.]{name="work-reflog" frame="window" markers="33.5,9 44.1,37.1 84.4,21.3"}

1. The :ui[reflog.ref] menu
2. The selected entry
3. The commit’s details

Right-click the entry to bring the commit back:

- :ui[reflog.createBranch]{1="9e0d36a7"} starts a new branch there. Your current branches stay as they are.
- :ui[reflog.restore]{1="feature/units-toggle" 2="9e0d36a7"} moves the branch you’re viewing back to that commit. The Working Copy and the staging area don’t change. Spooky asks first, and you can undo it.
- :ui[reflog.cherryPick]{1="9e0d36a7"} copies the commit onto the current branch. You can also drag the entry onto :ui[workspace.title] or the current branch in the sidebar.
- :ui[reflog.reset]{1="9e0d36a7"} opens the reset dialog, to move the current branch to that commit.
- :ui[patch.menu]{1="9e0d36a7"} saves the commit as a patch file.

To have :ui[reflog.title] in the sidebar, turn on :ui[sidebar.showReflog] in :ui[sidebar.viewSettings].

:::caution
Git removes old Reflog entries over time. By default, entries are kept for 90 days, and for 30 days when their commit is no longer on the branch. Recover lost commits soon.
:::

:::note[Server repositories]
The Reflog lives in the repository on the server. Spooky reads it there.
:::

## See also

- [Commit Changes](/guide/work/commit/)
- [Resolve Conflicts](/guide/work/conflicts/)
- [Rewrite History](/guide/history/rewrite/)
