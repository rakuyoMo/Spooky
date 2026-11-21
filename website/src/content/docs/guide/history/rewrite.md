---
title: "Rewrite History"
description: "Revert, cherry-pick, and reset commits, rebase interactively, and amend older commits."
---

Most commands here start from the [History](/guide/history/browse/) list: right-click a commit, or select several first. Reverting and cherry-picking add new commits. The rest rewrite commits that already exist.

:::caution
Rewritten commits get new hashes. If you already pushed them, your branch and its upstream diverge, and pushing again needs a force push. Anyone who already has the old commits has to reconcile their history. See [Force push](/guide/branches/sync/#force-push).
:::

Apart from cherry-picking and resetting, these commands only appear in a commit’s menu while the list shows just the branch you’re on. To get there, choose :ui[menu.view > history.showHead] (<kbd>⌘0</kbd>), or click the branch in the sidebar.

::screenshot[The shortcut menu for commit 2daa6982 while the list shows the branch you’re on. Among its items are Reset, Revert, and Rebase Onto, followed by Amend, Edit, Edit Commit Message, and Delete for this commit.]{name="history-commit-menu" frame="closeup"}

## Revert a commit {#revert}

Reverting adds a commit that undoes the changes of an earlier one. The earlier commit stays in the history, so this is the safe way to take back something you already pushed.

1. Right-click the commit and choose :ui[rewrite.menu.revert]{1="e2dda2bc"} in the menu. With several commits selected, the item is :ui[rewrite.menu.revertMany]{1="3"} instead.
2. :ui[rewrite.revert.commit] is on by default, so each reverted commit gets a commit of its own. Turn it off to leave the changes in the Working Copy. Spooky remembers this choice.
3. Click :ui[rewrite.revert.button].

Several commits are reverted from newest to oldest. To revert a merge commit, choose its :ui[rewrite.mainline]: the parent whose side counts as the main line. A merge commit can only be reverted on its own.

The commit details and the [multiple selection](/guide/history/commit-details/#multiple) have a :ui[rewrite.revert.button] button too.

## Cherry-pick a commit {#cherry-pick}

Cherry-picking copies the changes of commits from another branch onto the branch you’re on, as new commits.

1. Click the other branch in the sidebar to see its history.
2. Right-click the commit and choose :ui[rewrite.menu.cherryPick]{1="e2dda2bc"} in the menu. With several commits selected, the item is :ui[rewrite.menu.cherryPickMany]{1="3"}, and you can also click :ui[rewrite.cherryPick.button] on the right.
3. Choose the options. Spooky remembers them:
   - :ui[rewrite.cherryPick.commit] (on by default) commits each one. Turn it off to only apply the changes to the Working Copy.
   - :ui[rewrite.cherryPick.fastForward] moves your branch to the commit instead of copying it, when your branch is at the commit’s parent. It only applies while the first option is on.
4. Click :ui[rewrite.cherryPick.button].

The commits are applied from oldest to newest. A merge commit needs a :ui[rewrite.mainline], as with reverting.

While the list shows the branch you’re on, the item only appears for commits on the upstream that you haven’t pulled yet.

You can also drag commits from the list onto :ui[workspace.title] or the branch you’re on in the sidebar. Hold <kbd>⌥</kbd> as you drop to revert them instead.

## Reset to an older commit {#reset}

Resetting moves the branch you’re on to another commit. The commits after it leave the branch.

1. Right-click the commit and choose :ui[rewrite.menu.reset]{1="e2dda2bc"} in the menu. You can also click :ui[history.rollback] in the commit details, or choose :ui[workspace.title > rewrite.reset.menu] in the menu bar.
2. Check :ui[rewrite.revision]. You can pick a branch, remote branch, or tag, or type a hash. The dialog lists the commits that will leave the branch.
3. Choose a :ui[rewrite.reset.mode]:
   - :ui[rewrite.reset.soft] keeps the staging area and the Working Copy as they are. The changes from the commits that leave stay staged.
   - :ui[rewrite.reset.mixed] resets the staging area and keeps the Working Copy. Those changes become unstaged.
   - :ui[rewrite.reset.hard] resets both. Uncommitted changes, and the changes from the commits that leave, are discarded.
4. Click :ui[rewrite.reset.button].

The dialog starts at :ui[rewrite.reset.soft] every time. Resetting doesn’t offer to stash your changes.

:::caution
:ui[rewrite.reset.hard] discards uncommitted changes in tracked files. The dialog warns you when there are any. <kbd>⌘Z</kbd> brings them back, but only until you quit Spooky.
:::

## Rebase commits onto another base {#rebase-onto}

:ui[rewrite.rebaseOnto] moves commits to sit on top of a different commit.

- To move a whole stretch of your branch, choose :ui[workspace.title > rewrite.rebaseOnto.menu] in the menu bar. Fill in :ui[rewrite.rebaseOnto.current] and :ui[rewrite.rebaseOnto.new]. The commits after the current base are replayed on top of the new one.
- To move only some commits, select them and right-click. Choose :ui[rewrite.menu.rebaseOntoMany]{1="3"} in the menu, or :ui[rewrite.menu.rebaseOnto]{1="e2dda2bc"} for a single commit, then fill in :ui[rewrite.rebaseOnto.new]. Commits in the same stretch that you didn’t select are removed from the branch.

Neither base can be the commit you have checked out. The dialog lists the commits that will be rewritten, and warns you when some are already pushed or in other branches. :ui[sync.skipHooks] skips the repository’s pre-rebase hook this time. Click :ui[rewrite.rebaseOnto.button] to start.

To rebase a branch onto another branch, see [Rebase](/guide/branches/merge-rebase/#rebase).

## Squash, fixup, delete, and move {#interactive}

These commands rewrite a run of commits on the branch you’re on. Select the commits, right-click, and choose:

- :ui[rewrite.menu.squashMany]{1="3"} to fold them into the oldest one. Their messages are combined, and the list then selects the new commit.
- :ui[rewrite.menu.fixupMany]{1="3"} to fold them into the oldest one, keeping only its message.
- :ui[rewrite.menu.deleteMany]{1="3"} to remove them from the branch. With one commit selected, :ui[rewrite.menu.delete]{1="e2dda2bc"} does the same.

You can also drag commits within the list:

- Drop them on another commit to squash them into it. Hold <kbd>⌥</kbd> as you drop to fixup instead. The label at the drop point reads :ui[rewrite.squash.button] or :ui[rewrite.fixup.button].
- Drop them between two rows to move them there. The label reads :ui[branch.moveHere].

For all of these, Spooky asks before it rewrites anything. The dialog lists every commit that will be rewritten, with what happens to it, such as :ui[rewrite.note.squash] or :ui[rewrite.note.drop]. A yellow warning sign marks commits that are already pushed or in other branches, and a warning above the list explains. Deleting commits that are already on the upstream asks one extra question first.

::screenshot[The dialog that asks before squashing two commits into 10e44ab8. Two warnings at the top say that some of the commits are already on the upstream branch or in other branches. The list below shows the four commits that get rewritten, with what happens to each. The pushed commit has a yellow warning sign at the end of its row. The buttons are Cancel and Squash Revisions.]{name="history-rewrite-confirm" frame="dialog"}

## Edit a commit message {#reword}

1. Right-click the commit and choose :ui[rewrite.menu.reword]{1="e2dda2bc"} in the menu.
2. Change :ui[working.subject] and :ui[working.body]. Comment lines are handled as in the [commit area](/guide/work/commit/#comments).
3. Click :ui[rewrite.reword.button].

The commits after it are rewritten too, and the list then selects the commit under its new hash. If the commit is already on the upstream, Spooky asks before it opens the dialog.

## Edit a commit {#edit}

Editing stops at a commit and puts its changes back in the Working Copy, so you can split it up or redo it.

1. Right-click the commit and choose :ui[rewrite.menu.edit]{1="e2dda2bc"}. Confirm with :ui[rewrite.edit.button].
2. The banner reads :ui[conflict.title.edit]{1="e2dda2bc" 2="main"}. The commit’s changes are in the Working Copy, unstaged.
3. Stage and commit them as usual, in as many commits as you like.
4. Click :ui[working.endEditing] in the banner. The commits after it are replayed on top.

To give up, click :ui[working.abort] in the banner. The first commit of a repository can’t be edited.

## Amend an older commit {#amend}

Amending an older commit adds changes to it, the way [amending the last commit](/guide/work/commit/#amend) does.

1. Right-click the commit and choose :ui[rewrite.menu.amend]{1="e2dda2bc"}. Spooky starts right away, without a confirmation.
2. The rebase stops at that commit. Make your changes and stage them.
3. Select :ui[working.amend] in the commit area, and commit.
4. Click :ui[working.endEditing] in the banner. The commits after it are replayed on top.

If you have local changes when you start, Spooky offers to stash them first. They stay on the stash afterward, so you can apply them while the rebase is stopped, or later.

## Autosquash {#autosquash}

A commit can mark itself as a fix for an earlier one: start its subject with `fixup!`, `squash!`, or `amend!`, followed by the earlier commit’s subject. The commit area [completes the subject](/guide/work/commit/#autocomplete) for you.

When the list shows the branch you’re on without a search, and its latest 1,000 commits include such commits, a banner titled :ui[rewrite.autosquash] appears below the header. Click :ui[rewrite.autosquash.button] in the banner, and confirm. Each marked commit is folded into the commit it names:

- `fixup!` keeps the earlier commit’s message.
- `squash!` combines both messages.
- `amend!` replaces the earlier commit’s message with its own.

Click × to hide the banner for now.

## When rewriting can’t start {#errors}

Spooky checks the commits before it rewrites anything. If something is off, it explains, and nothing changes:

| Message | Why |
|---|---|
| :ui[rewrite.error.notInHead] | The commits must all be in the history of the branch you’re on, on one line. |
| :ui[rewrite.error.merges] | A merge commit is in the way, and rewriting would flatten it. Choose commits after the last merge. |
| :ui[rewrite.error.root] | The first commit of a repository has no parent to return its changes to. |
| :ui[rewrite.error.selection] | Squashing needs at least two commits, and the target can’t be one of the commits being folded in. |
| :ui[rewrite.error.autosquash] | No recent commit is marked for an earlier one. |
| :ui[rewrite.error.changed] | The branch changed after Spooky read it. Refresh the history and try again. |

## Local changes and conflicts {#local-changes}

Reverting, cherry-picking, and rebasing need a Working Copy that doesn’t get in the way. When your local changes block one of them, Spooky offers to [stash them first](/guide/work/stash/#auto-stash). Amending an older commit asks before it starts.

If a commit conflicts along the way, Spooky stops and shows the [operation banner](/guide/work/conflicts/#banner). Resolve the conflicts, then continue or abort there.

## Undo a rewrite {#undo}

Choose :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>) to take back a revert, cherry-pick, reset, or rewrite. While a rebase is stopped, for example to edit a commit, finish or abort it first. A rebase or cherry-pick that stopped on a conflict can’t be undone. See [Undo and Recovery](/guide/work/undo/).

The old commits also stay in the [Reflog](/guide/work/undo/#reflog) for a while.

:::note[Server repositories]
The commits are rewritten on the server. Every dialog that rewrites history names the server it runs on.
:::

## See also

- [Resolve Conflicts](/guide/work/conflicts/)
- [Undo and Recovery](/guide/work/undo/)
- [Merge and Rebase](/guide/branches/merge-rebase/)
