---
title: "The Repositories Window"
description: "Bookmark, group, open, clone, create, scan for, and remove repositories, and find the ones that have gone missing."
---

The Repositories window keeps a list of the repositories you work with, on your Mac and on servers. Each entry is a bookmark that points to a repository. When you remove a bookmark, the repository folder stays where it is. Moving the folder to the Trash is a separate choice. This page covers adding, organizing, opening, and removing repositories.

To get to the list from a repository, click :ui[toolbar.bookmarks] in the toolbar or choose :ui[menu.view > menu.showRepositories] (<kbd>⌃⌘R</kbd>).

::screenshot[The Repositories window. The sidebar lists two groups, Driftwood Labs and Notes, with repositories inside; one of them is a server repository whose name starts with its host alias. On the right are the details of the selected repository, driftwood: its location, when it was last opened, its last commit, a description, the committer identity, the current branch, the number of changed files, and the remote.]{name="repositories" frame="window"}

## Add repositories {#add}

The add button at the bottom of the sidebar has a menu for adding to the list:

| Menu item | What it does |
|---|---|
| :ui[bookmarks.newGroup] | Adds a group below the selection, ready for you to type its name |
| :ui[bookmarks.add] | Adds repositories that are already on your Mac. You can select several folders at once. |
| :ui[action.addRemote] | Adds a repository on a server. See [Add Server Repository](/guide/server/add/). |
| :ui[bookmarks.create] | Creates an empty repository. See [Create a repository](#create). |
| :ui[clone.menu] | Copies a repository from a remote. See [Clone a repository](#clone). |
| :ui[scan.menu] | Finds the repositories inside a folder. See [Search for repositories](#scan). |

New entries go into the selected group. You can also drag repository folders from Finder into the list. If you open a repository with :ui[menu.file > action.openLocal] and it isn’t in the list yet, it’s added to the end.

### Create a repository {#create}

1. Choose :ui[bookmarks.create] from the add button’s menu.
2. In :ui[bookmarks.create.name], type the name of the new repository. It is also the name of its folder.
3. Next to :ui[bookmarks.create.location], click :ui[bookmarks.create.choose] to pick the folder to create it in. It starts at your home folder.
4. Click :ui[bookmarks.create.submit].

Spooky creates the folder, makes it an empty Git repository, adds it to the selected group, and opens it.

### Clone a repository {#clone}

Cloning copies a repository and its history from a remote into a new folder.

1. From the add button’s menu, choose :ui[clone.menu], or press <kbd>⌃⌘C</kbd>.
2. In :ui[clone.url], enter the address of the repository, for example one that starts with `https://` or `git@`.
3. In :ui[clone.to], choose :ui[clone.machine.local] or a server. Servers you already use are in the list. To use another one, choose :ui[clone.machine.other] and enter its :ui[remote.host].
4. In :ui[clone.directory], choose the folder to clone into. Spooky creates a folder named after the repository inside it.
5. Leave :ui[clone.submodules] selected to also check out the repository’s submodules. Select :ui[clone.lfs] if the repository keeps large files in Git LFS.
6. Click :ui[clone.submit].

Spooky first checks that it can reach the remote. If it can’t, the dialog stays open and shows why. Fix the address and try again. If it can, the dialog closes and the clone runs in the background. Its progress shows in the repository’s row in the list. When the clone finishes, Spooky posts a :ui[clone.notification.title] notification.

On your Mac, the folder starts at your home folder, or at the folder set in :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.cloneDirectory]. See [Cloning and Terminal](/guide/settings/general/#cloning).

While you have recent clones, :ui[toolbar.clone] appears in the toolbar. Click it to see :ui[clone.recent.title]. There you can stop a running clone, start a failed or cancelled one again with :ui[clone.retry], or :ui[clone.remove] it from the list. Double-click a finished clone to open it. :ui[clone.recent.clear] empties the list.

:::note[Server repositories]
When you clone to a server, Spooky checks the connection and runs the clone there. The new repository is added as a server repository. For the folder, type an absolute path on the server, or click :ui[clone.browse] to pick one. Spooky remembers the last folder you used on each server.
:::

You can also drag a repository’s address into the list to start a clone. A link can start one too. See [Windows and Navigation](/guide/repositories/navigation/).

### Search for repositories {#scan}

1. Choose :ui[scan.menu] from the add button’s menu.
2. In :ui[scan.in], choose :ui[clone.machine.local] or a server, then the folder to search.
3. Click :ui[scan.start]. Repositories show up as Spooky finds them. To stop, click :ui[scan.stop].
4. Every repository found is selected. Deselect the ones you don’t want, then click :ui[scan.add].

Repositories already in the list aren’t shown again. You can search several folders or servers one after another. The results add up.

## Organize the list {#organize}

- To add a group, choose :ui[bookmarks.newGroup] from the add button’s menu, then type a name.
- To reorder entries or move them into another group, drag them.
- To rename an entry, select it and press <kbd>↩</kbd>, or right-click it and choose :ui[bookmarks.rename]. Renaming a repository in the list doesn’t rename its folder.
- To sort by name, right-click and choose :ui[bookmarks.sortChildren] to sort the entries of a group, or :ui[bookmarks.sortParent] to sort the group an entry is in.

Two options in :ui[app.name > settings.title] › :ui[settings.general] change what the list shows:

- :ui[settings.showWorktreesInRepositoryList]: a repository with other worktrees can be expanded to list them. You open a worktree the same way as a repository. Off by default.
- :ui[settings.showHostAliasesInRepositoryList]: the names of server repositories start with their host alias. On by default.

See [Windows and the Repositories list](/guide/settings/general/#windows).

## Open a repository {#open}

Double-click a repository. It opens in the same window, in place of the list. If the repository is already open in another window, Spooky brings that window to the front instead.

Right-click a repository for more choices:

- :ui[bookmarks.open]{1="driftwood"} and :ui[bookmarks.openNewWindow]{1="driftwood"}
- :ui[action.revealFinder], :ui[action.copyPath], and :ui[action.openTerminal]

The details on the right also have :ui[action.open] and :ui[bookmarks.multiple.delete] buttons. Click :ui[bookmarks.detail.edit] there to change the :ui[bookmarks.detail.description] and the :ui[bookmarks.detail.identity]. :ui[bookmarks.detail.unset] removes the identity set just for this repository. Next to each remote, :ui[bookmarks.detail.viewInBrowser] opens its web page. The description and identity are the same ones you see in [Repository settings](/guide/settings/identity/#repository).

:::note[Server repositories]
:ui[action.copyPath] copies the path with the host alias in front, as in `alias:/path/to/repository`. Spooky reads a server repository’s details only when you select it. Selecting one may connect to the server.
:::

## Change a repository’s location {#location}

If a repository has moved, you don’t have to remove its entry and add it again.

1. Select the repository. In the details, move the pointer over the :ui[bookmarks.detail.location] row and click :ui[bookmarks.detail.edit].
2. Click :ui[localLocation.choose] and pick the folder the repository is in now.
3. Click :ui[action.ok].

Spooky first checks that the new location is a Git repository. If it isn’t, the dialog stays open and shows why. If it is, the entry points to the new location. It stays in its group and keeps a name you gave it. A name you never changed follows the new folder. You can’t change to a location that is already in the list.

::screenshot[The Edit Repository Location dialog for a server repository. Host alias is spooky-test. Repository path is /srv/git/driftwood, with a Browse button next to it. The buttons are Cancel and OK.]{name="repositories-edit-location" frame="dialog"}

:::note[Server repositories]
The dialog has :ui[remote.host] and :ui[remote.path] instead. You can change just one of them, for example only the host alias. Click :ui[clone.browse] to pick the path on the server. Spooky connects to the server to check the new location.
:::

## Missing repositories {#missing}

If a repository’s folder is moved, renamed, or deleted, its name in the list turns grey with a warning sign. Its details say :ui[bookmarks.detail.missing] Spooky checks the repositories on your Mac each time the list appears.

If you open a missing repository, the window shows :ui[missing.title]. Click :ui[action.refresh] to check again, for example after you reconnect a disk. Click :ui[action.close] to go back to the list.

To fix the entry, point it to where the repository is now. See [Change a repository’s location](#location).

:::note[Server repositories]
Spooky checks a server repository only when you select or open it. If Spooky can’t reach the server, the window says :ui[missing.unreachable.title]{1="alias"} and shows what SSH reported. See [Connection Status and Reconnecting](/guide/server/connection/).
:::

## Remove repositories {#delete}

Select one or more entries, then do one of the following:

- Press <kbd>⌫</kbd>.
- Right-click and choose :ui[bookmarks.delete]{1="driftwood"}, :ui[bookmarks.deleteFolder] for a group, or :ui[bookmarks.deleteMultiple]{1="2"} for several entries.
- Click :ui[bookmarks.multiple.delete] in the details.

If the repository folder still exists, Spooky asks :ui[bookmarks.delete.title]{1="driftwood"} first. Only the bookmarks are removed. The folders stay where they are. To move them to the Trash too, select :ui[bookmarks.delete.trash]. Click :ui[bookmarks.delete.submit] to confirm.

Empty groups and entries whose folders are gone are removed right away, without asking.

:::caution
Moving to the Trash takes the whole repository folder, including changes you haven’t committed. You can get it back until you empty the Trash. The Trash checkbox is cleared each time the dialog opens.
:::

If a folder can’t be moved, Spooky shows :ui[bookmarks.trashFailed.title] and lists the folders that stayed. Spooky never moves your home folder, a folder that contains it, or the top level of a disk to the Trash.

:::note[Server repositories]
Spooky always asks before removing a server repository. Its folder goes to the Trash on that server, not on your Mac. If the folder is no longer on the server, the Trash checkbox is dimmed and only the bookmark is removed.
:::

## See also

- [Windows and Navigation](/guide/repositories/navigation/)
- [Add Server Repository](/guide/server/add/)
- [Worktrees](/guide/advanced/worktrees/)
