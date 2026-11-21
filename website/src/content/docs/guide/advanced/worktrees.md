---
title: "Worktrees"
description: "Check out branches in additional worktrees, and open, move, repair, and remove them."
---

A worktree is another folder checked out from the same repository. Each worktree has its own checked-out branch and Working Copy. They all share the repository’s commits and branches. That way you can work on a second branch without stashing or switching in the first folder.

A branch can be checked out in only one worktree at a time.

## In the sidebar {#sidebar}

Worktrees are listed under :ui[worktree.group] in the sidebar, sorted by name. The name is the last part of the worktree’s path. The worktree open in the window isn’t listed. Hold the pointer over one to see where it’s checked out.

Click a worktree to see its name, path, current revision, and branch. Double-click it to open it in the same window.

A branch that’s checked out in another worktree has a small badge on its icon. When you right-click it, the menu says which worktree it’s in. It also has items to open or remove that worktree. See [Check out a branch](/guide/branches/branches/#checkout).

To list worktrees in the Repositories window too, see [Organize the list](/guide/repositories/manager/#organize).

## Add a worktree {#add}

Start in one of these ways:

- Choose :ui[menu.repository > menu.addWorktree] in the menu bar.
- Click the add button at the bottom of the sidebar, or right-click :ui[worktree.group], and choose :ui[worktree.add.menu] from the menu.
- Right-click a local branch and choose :ui[worktree.checkoutBranch]{1="feature/units-toggle"} from the menu.
- Drag a local branch onto :ui[worktree.group].

In the dialog:

1. Next to :ui[worktree.revision], choose or type the branch or revision to check out. If you started from a branch, it’s already filled in.
2. Next to :ui[worktree.destination], enter the full path of the new folder. The :ui[submodule.path.select] button starts next to the repository’s folder. It suggests a name made of the repository’s name and the revision. The folder mustn’t exist yet, or must be empty.
3. Select :ui[worktree.detach] to check out a detached HEAD at that revision. Then the worktree doesn’t take up any branch.
4. Click :ui[worktree.add.submit].

If the branch is already checked out in a worktree, the dialog says so. Select :ui[worktree.detach], or :ui[worktree.force] under :ui[dialog.options], to create the worktree anyway.

The repository needs at least one commit. After the worktree is created, the window stays on the repository you had open. The new worktree shows up in the sidebar.

## Open a worktree {#open}

You open a worktree like any other repository. Right-click it in the sidebar and choose from the menu:

- :ui[worktree.open.current], :ui[worktree.open.newTab], or :ui[worktree.open.newWindow]
- :ui[worktree.reveal], :ui[action.copyPath], or :ui[action.openTerminal]

## Move a worktree {#move}

Right-click a worktree and choose :ui[worktree.move.menu] from the menu. Enter the new path, or click the :ui[submodule.path.select] button. Changes in the worktree move along with it.

## Remove a worktree {#remove}

Right-click a worktree and choose :ui[worktree.remove.menu] from the menu. This deletes the worktree’s folder. The branch it had checked out stays in the repository.

If the worktree has changes or untracked files, Git refuses to remove it. Select :ui[worktree.remove.force] to delete it along with them.

The repository’s main worktree, the folder that holds its `.git` directory, can’t be moved or removed. It’s in the list when you have another worktree open.

## Repair a worktree {#repair}

If a worktree’s folder is moved or deleted outside Spooky, the worktree stops working. It gets a warning icon in the sidebar. You can’t open it. Its details say :ui[worktree.invalid], with Git’s reason, and two buttons:

- :ui[worktree.invalid.repair]: if you moved the folder, choose :ui[submodule.path.select] in the :ui[worktree.location] menu, and find where the folder is now. Spooky checks that the folder is this worktree of this repository. Then click :ui[worktree.relocate.submit].
- :ui[worktree.invalid.remove]: if the folder is gone, this removes what’s left of the worktree from the repository.

You’ll find both in the worktree’s right-click menu too.

## Undo {#undo}

Adding, moving, removing, and repairing worktrees can’t be undone with <kbd>⌘Z</kbd>. After one of them, operations before it can’t be undone anymore either. See [Undo and Recovery](/guide/work/undo/).

:::note[Server repositories]
Worktrees are created on the server. Their paths are paths on the server. :ui[submodule.path.select] browses the server’s folders.

:ui[worktree.reveal] is available when Spooky can find the worktree’s folder on your Mac. If the worktree is inside the repository’s folder, Spooky finds it through the repository’s location. Otherwise it looks among the volumes mounted on your Mac. See [Location on This Mac](/guide/server/local-location/).
:::

## See also

- [Branches](/guide/branches/branches/)
- [Submodules](/guide/advanced/submodules/)
- [The Repositories Window](/guide/repositories/manager/)
