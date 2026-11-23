---
title: "Merge and Rebase"
description: "Merge and rebase branches, preview conflicts before you start, update a branch from its parent, and drag and drop branches in the sidebar."
---

Merging and rebasing both bring the commits of another branch into the branch you’re on:

- A merge joins the two histories, usually with a merge commit.
- A rebase moves your commits so they come after the commits of the other branch. The history stays a straight line, but your commits are rewritten.

Both start from the :ui[workspace.title] menu. To put :ui[sync.merge] and :ui[sync.rebaseHead] in the toolbar, choose :ui[menu.view > menu.customizeToolbar] and drag them in.

## Merge {#merge}

1. Choose :ui[workspace.title > sync.mergeMenu] (<kbd>⇧⌘M</kbd>). In the sidebar, you can also right-click the branch you’re on and choose :ui[workspace.mergeMenu] from the menu, or drag another branch onto it.
2. Pick what to merge in :ui[branch.target]: a local branch, a remote branch, or a tag. At first it’s the upstream of the branch you’re on.
3. Choose how to commit:
   - :ui[merge.squash] stages all the changes for a single commit of your own, without a merge commit.
   - :ui[merge.alwaysCommit] creates a merge commit even when Git could just move your branch forward.
   - :ui[merge.autoCommit] commits the merge right away. You can only clear it while :ui[merge.alwaysCommit] is selected. Then the merged changes wait in the Working Copy for you to commit.
4. If the merge would run into conflicts, a line below says so. See [Preview conflicts](#preview).
5. Set the options:
   - :ui[merge.verify] stops the merge unless the merged commit has a trusted signature.
   - :ui[sync.skipHooks] skips the repository’s Git hooks this time.
6. Click :ui[sync.merge].

Spooky remembers :ui[merge.alwaysCommit], :ui[merge.autoCommit], and :ui[merge.verify].

If the merge stops on conflicts, Spooky switches to the Working Copy and shows a banner. See [Resolve Conflicts](/guide/work/conflicts/#banner).

<kbd>⌘Z</kbd> undoes a merge. If the merge stopped on conflicts, undoing it aborts the merge.

## Rebase {#rebase}

1. Choose :ui[workspace.title > sync.rebaseMenu] (<kbd>⇧⌘R</kbd>). You can also right-click the branch you’re on and choose :ui[workspace.rebaseMenu] from the menu.
2. Pick the branch to rebase onto in :ui[branch.target]. At first it’s the upstream of the branch you’re on.
3. Check the preview, and select :ui[sync.skipHooks] if you need to.
4. Click :ui[sync.rebaseHead].

<kbd>⌘Z</kbd> undoes a rebase that finished. A rebase that stops on a conflict can’t be undone: resolve the conflict and continue, or abort it from the banner.

To move only some of your commits onto another base, see [Rebase commits onto another base](/guide/history/rewrite/#rebase-onto).

:::caution
Rebasing rewrites your commits. If you already pushed them, the next push has to be a [force push](/guide/branches/sync/#force-push).
:::

## Local changes {#local-changes}

A merge needs your tracked files to be unchanged. New files only get in the way when the merge would overwrite them.

Rebasing and updating a branch from its parent need a Working Copy with no changes at all, new files included.

When local changes block one of them, Spooky offers to stash the changes first. See [Auto stash](/guide/work/stash/#auto-stash).

## Preview conflicts {#preview}

Before you start, the merge, rebase, pull, and sync dialogs check whether the branches conflict, and show the result in the dialog:

- :ui[merge.checking] while Spooky compares them.
- How many files conflict. Hold the pointer over the line to see which files.
- :ui[merge.clean] or :ui[merge.unchanged].
- :ui[merge.unavailable] when the check didn’t work. Hold the pointer over the line to see why.

The merge dialog leaves out :ui[merge.clean] and :ui[merge.unchanged]. The others show every result.

## Quick versions {#quick}

Hold <kbd>⌥</kbd>, and :ui[sync.merge] and :ui[sync.rebaseHead], once you’ve added them to the toolbar, turn into :ui[sync.quickMerge] and :ui[sync.quickRebase]. They run right away, without the dialog:

- :ui[sync.quickMerge] merges the upstream of the branch you’re on.
- :ui[sync.quickRebase] rebases the branch you’re on onto its upstream.

Quick merge uses the commit and signature options you last chose in the merge dialog. Both offer to stash local changes, as the dialogs do.

The items in the sidebar menu change the same way. For example, :ui[workspace.mergeMenu] becomes :ui[sync.quickMergeInto]{1="origin/main" 2="main"}.

## Update a branch from its parent {#update}

When a branch has a [parent branch](/guide/branches/branches/#parent), Update brings in the parent’s new commits.

1. Right-click the branch and choose :ui[branch.updateNamed]{1="feature/units-toggle"} from the menu. When you view the branch’s history and the parent has new commits, the banner :ui[history.parentBanner.title] has a :ui[review.updateBranch.menu] button too.
2. Check :ui[review.update.branch]. The line below says how many commits will come in from the parent.
3. In :ui[review.update.strategy], choose :ui[review.update.merge] or :ui[review.update.rebase]. With :ui[review.update.merge], you can also select :ui[merge.alwaysCommit].
4. Check the preview: :ui[review.update.conflicts], :ui[review.update.clean], or :ui[review.update.noChanges].
5. Set the options: :ui[merge.verify] (for merging only) and :ui[sync.skipHooks].
6. Click :ui[review.update.button].

Spooky checks out the branch first, then merges or rebases. Update is only available when the parent has commits the branch doesn’t, and no other operation is in progress.

For the branch you’re on, :ui[branch.mergeWith]{1="main"} and :ui[branch.rebaseOn]{1="main"} in the sidebar menu open the merge and rebase dialogs with the parent already picked.

:::tip
Hold <kbd>⌥</kbd> while the menu is open, and :ui[branch.updateNamed]{1="feature/units-toggle"} turns into :ui[branch.quickUpdateNamed]{1="feature/units-toggle"}. It merges the parent right away, without the dialog.
:::

## Drag and drop {#drag-and-drop}

Many branch operations start by dragging in the sidebar. While you drag, the label next to the pointer says what will happen. Hover over a collapsed folder or remote for a moment, and it opens.

| Drag | Onto | What happens |
|---|---|---|
| A local branch | :ui[workspace.title] or the branch you’re on | The merge dialog. Hold <kbd>⌥</kbd> for the rebase dialog. |
| A remote branch | :ui[workspace.title] or the branch you’re on | The pull dialog |
| A remote branch, holding <kbd>⌥</kbd> | The branch you’re on | It becomes the upstream of your branch. |
| A local branch, a tag, or a commit | :ui[branch.group] | The dialog to create a branch from it |
| A remote branch | :ui[branch.group] | The dialog to track it |
| A local branch | A remote | The publish dialog |
| A local branch | A remote branch | The :ui[sync.pushBranch] dialog |
| A local branch or a commit | :ui[sidebar.tags] or a tag folder | The dialog to create a tag |
| A tag | A remote | The dialog to publish the tag |
| A local branch | :ui[sidebar.pinned] or :ui[sidebar.archived] | The branch is pinned or archived. |
| A local branch | :ui[worktree.group] | The dialog to create a worktree for it |

To move a branch into a folder, drag it onto the folder. The branch is renamed to the folder plus the last part of its name, with no dialog. A remote branch can only move into folders of its own remote. To move a branch out of its folder, drag it to the top or bottom edge of the list. You can undo the rename with <kbd>⌘Z</kbd>.

You can also drag commits from the history onto :ui[workspace.title] or the branch you’re on to cherry-pick them. Hold <kbd>⌥</kbd> to revert them instead. See [Cherry-pick a commit](/guide/history/rewrite/#cherry-pick). Drag a single file from a commit’s changeset there, and only that file’s changes are applied to the Working Copy, without staging them.

## See also

- [Resolve Conflicts](/guide/work/conflicts/)
- [Rewrite History](/guide/history/rewrite/)
- [Fetch, Pull, and Push](/guide/branches/sync/)
- [Branches](/guide/branches/branches/)
