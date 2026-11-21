---
title: "Branches"
description: "Create, check out, track, rename, delete, pin, and archive branches, set parent branches, and filter and group branches in the sidebar."
---

Your local branches are listed in the sidebar under :ui[branch.group]. Most of what you do with a branch starts there: right-click it for its menu, or drag it somewhere.

::screenshot[The bottom of the sidebar. Under Branches, main has a HEAD badge with ↑3, and a feature folder holds dark-mode, station-map, and units-toggle. Archived Branches is empty. Tags lists v0.1.0 to v0.4.0. Under Remotes, origin has main with a house icon and a collapsed feature folder. The bar at the bottom has the filter field on the left, and the Add and view settings buttons on the right.]{name="branches" frame="closeup" markers="57,7 57,12.1 75,33.6 17,96.8 73,96.8"}

1. The branch you’re on, with its HEAD badge and the commits not pushed yet
2. A folder for the branches whose names start with `feature/`
3. :ui[sidebar.archived]
4. :ui[sidebar.filter]
5. The add button and the view settings button

## In the sidebar {#sidebar}

Click a branch to see its commits in the history. Double-click it to check it out.

A branch that tracks a remote branch shows how far apart the two are. ↑ counts your commits that aren’t on the remote yet. ↓ counts the commits on the remote that you don’t have. Hold the pointer over a branch to see what it tracks.

A branch that hasn’t had a new commit for a while is stale. Its name is dimmed, followed by a clock and how long it’s been. `main`, `master`, `trunk`, `dev`, `develop`, `next`, and any branch that is another branch’s parent are never stale.

Under :ui[remote.group], a house icon marks the default branch of each remote.

## Create a branch {#create}

1. Choose :ui[menu.repository > branch.createMenu] (<kbd>⌘B</kbd>). You can also click the add button at the bottom of the sidebar, or right-click :ui[branch.group], and choose it from the menu.
2. Type the name in :ui[reference.name].
3. Pick where the branch starts in :ui[branch.start]. At first it’s the branch you’re on, or what you right-clicked to get here.
4. Set the options:
   - :ui[branch.trackStart] makes the new branch track its starting point. It’s only available when the starting point is a branch.
   - :ui[branch.pin] puts the new branch under :ui[sidebar.pinned].
   - :ui[branch.checkoutCreated] switches to the new branch right away. Spooky remembers this choice.
   - :ui[branch.parentOption] sets the starting point as the new branch’s [parent](#parent).
5. Click :ui[branch.create].

To start a branch from a particular branch, tag, or commit, right-click it and choose :ui[branch.createFromMenu]{1="main"} from the menu. You can also drag it onto :ui[branch.group].

While you type, Spooky fixes the name for Git: spaces and characters that Git doesn’t allow become `-` or are dropped. To type names as they are, turn off :ui[branch.cleanNames] in :ui[app.name > settings.title] › :ui[settings.general]. See [Operations](/guide/settings/general/#operations).

A `/` in a name puts the branch in a folder, such as `feature/units-toggle` in `feature`. Right-click a folder and choose :ui[branch.createMenu] from the menu, and the name starts with the folder for you.

## Check out a branch {#checkout}

Double-click a branch, or right-click it and choose :ui[branch.checkoutNamed]{1="feature/dark-mode"} from the menu.

Double-clicking a remote branch works too:

- If a local branch already tracks it, Spooky checks out that branch.
- If there’s a local branch with the same name that doesn’t track it, Spooky asks first in :ui[branch.trackExisting.title]. It then checks out that branch and makes it track the remote branch.
- Otherwise, Spooky creates a local branch with the same name that tracks the remote branch. Then it checks the branch out.

When you have changes to tracked files, Spooky asks whether to stash them first. See [Auto stash](/guide/work/stash/#auto-stash).

A branch that’s checked out in another worktree can’t be checked out here. Double-click it and Spooky opens that worktree instead. Hold <kbd>⌘</kbd> while you double-click to open it in a new tab.

### Check out a tag or a commit {#checkout-revision}

Double-click a tag to check out its commit. To check out anything else, choose :ui[workspace.title > rewrite.checkout.menu] (<kbd>⇧⌘B</kbd>), pick a branch, tag, or commit, and click :ui[rewrite.checkout.button].

When what you pick isn’t a local branch, the dialog warns that HEAD will be detached. A detached HEAD means you’re on a commit, not on a branch. To keep commits you make there, create a branch from them.

## Track a remote branch {#track}

A local branch can track a branch on a remote, its upstream. Pull and push use the upstream unless you pick something else. The ↑ and ↓ counts compare against it.

To get a local branch for a remote branch:

1. Right-click the remote branch and choose :ui[branch.trackMenu]{1="origin/feature/station-map"} from the menu, or drag it onto :ui[branch.group].
2. :ui[branch.remoteField] shows the remote branch. Change the name in :ui[reference.name] if you like.
3. :ui[branch.track.checkout] is selected each time. Clear it to stay on the current branch.
4. Click :ui[branch.track.submit].

To change what an existing branch tracks, right-click it and choose a branch under :ui[branch.tracking]. :ui[branch.tracking.remove] stops tracking. For the branch you’re on, you can also hold <kbd>⌥</kbd> and drag a remote branch onto it.

When a branch you’re not on is behind its upstream and has no commits of its own, its menu has :ui[branch.fastForward]{1="main"}. It moves the branch up to the upstream without checking it out.

## Rename a branch {#rename}

Right-click the branch and choose :ui[reference.renameMenu]{1="feature/dark-mode"} from the menu. Type the new name and click :ui[reference.rename].

The pin, archive, and parent settings go with the branch. Renaming a remote branch renames it on the remote.

To move a branch into a folder, drag it onto the folder. See [Drag and drop](/guide/branches/merge-rebase/#drag-and-drop).

## Delete a branch {#delete}

Right-click the branch and choose :ui[reference.deleteMenu]{1="feature/dark-mode"} from the menu. You can also select one or more branches and press <kbd>⌘⌫</kbd> while the sidebar is focused.

Spooky always asks first. The dialog has two options:

- :ui[branch.forceDelete] deletes the branch even if it isn’t fully merged. Without it, Spooky lists the branches that aren’t fully merged and asks again.
- :ui[branch.deleteUpstream] also deletes the remote branch it tracks. It’s there when you delete a single branch whose remote branch still exists.

You can’t delete the branch you’re on. Check out another branch first.

Deleting a remote branch deletes it on the remote.

To get a deleted local branch back, choose :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>). This works even with :ui[branch.deleteUpstream] selected. Deleting only a remote branch can’t be undone. See [Undo and Recovery](/guide/work/undo/).

## Pin a branch {#pin}

Pinned branches move from :ui[branch.group] to :ui[sidebar.pinned], at the top of the list. Use it for the branches you go back to often.

Right-click a branch and choose :ui[branch.pinNamed]{1="feature/station-map"} from the menu, or drag it onto :ui[sidebar.pinned]. With several branches selected, the item is :ui[branch.pinMultiple]{1="2"}. To move a branch back, choose :ui[branch.unpinNamed]{1="feature/station-map"} instead.

## Archive a branch {#archive}

Archiving puts a branch out of the way without deleting it. It moves from :ui[branch.group] to :ui[sidebar.archived]. You can still use it as before.

Right-click a branch and choose :ui[branch.archiveNamed]{1="feature/dark-mode"} from the menu, or drag it onto :ui[sidebar.archived]. To bring it back, choose :ui[branch.unarchiveNamed]{1="feature/dark-mode"} instead.

Spooky can also find branches worth archiving, and archive them for you. See [Branches Review](/guide/branches/review/#archive-suggestions).

:::note[Server repositories]
Pinning, archiving, and parent branches are saved in the repository’s Git config. For a server repository, they’re saved on the server.
:::

## Parent branch {#parent}

A parent branch is the branch yours is based on and should keep up with, such as `main` for `feature/units-toggle`.

To set it, right-click the branch and choose a suggested branch under :ui[branch.parent]. For any other branch, choose :ui[branch.parent.setMenu], pick it in :ui[branch.parent.field], and click :ui[branch.parent.set]. You can also set it when you create the branch. :ui[branch.parent.remove] clears it.

Once a branch has a parent:

- Comparing branches in the history starts with the parent. See [Compare with another branch](/guide/history/browse/#compare-branches).
- When the parent has commits your branch doesn’t, the history of your branch shows :ui[history.parentBanner.title]. The branch’s menu has :ui[branch.updateNamed]{1="feature/units-toggle"} to bring them in. See [Update a branch from its parent](/guide/branches/merge-rebase/#update).
- For the branch you’re on, :ui[branch.mergeWith]{1="main"} and :ui[branch.rebaseOn]{1="main"} in the menu open the merge and rebase dialogs with the parent picked.
- The parent itself is never stale.

## Filter and group {#filter}

Type in :ui[sidebar.filter] at the bottom of the sidebar to show only matching branches, tags, remote branches, submodules, and worktrees. The letters don’t have to be next to each other: `stm` finds `station-map`. Case and accents don’t matter. Folders open while you filter, and <kbd>Esc</kbd> clears the field.

Click the view settings button at the bottom right, or choose :ui[menu.view > sidebar.menu], to set what the sidebar shows. The settings apply to every window.

- :ui[sidebar.groupRefs] puts names with a `/` in folders. It’s on at first. :ui[sidebar.groupedRefsOnTop] lists the folders before the other branches.
- :ui[sidebar.showStaleInfo] shows which branches are stale. :ui[sidebar.staleInterval] sets how long a branch can go without a commit, 6 months at first.
- :ui[sidebar.remoteFilter] and :ui[sidebar.tagsFilter] limit the list to the newest few under :ui[sidebar.showNewest]. The limit counts for each remote separately. Tags can also be sorted under :ui[sidebar.sortBy]. While you filter, every match shows.
- :ui[sidebar.autoArchive] is described in [Branches Review](/guide/branches/review/#auto-archive).

## See also

- [Fetch, Pull, and Push](/guide/branches/sync/)
- [Merge and Rebase](/guide/branches/merge-rebase/)
- [Branches Review](/guide/branches/review/)
- [Worktrees](/guide/advanced/worktrees/)
