---
title: "A Tour of Spooky"
description: "Get to know the Repositories window and the repository window: the sidebar, the toolbar, the three columns, and Quick Actions."
---

Spooky’s windows show one of two things. The Repositories view lists your repositories. A repository window is where you do the actual work. This page names the parts of both. The rest of the guide uses these names.

## The Repositories window {#repositories-window}

When you first open Spooky, it shows the Repositories view. The sidebar lists your repositories under :ui[repositories.title]. You can sort them into groups.

- Select a repository to see its details on the right: where it is, when you last opened it, its last commit, its current branch and changes, and its remotes.
- Select a group, or nothing, to see an area that says :ui[bookmarks.dropZone.title], with the buttons :ui[bookmarks.dropZone.add], :ui[action.addRemote], :ui[bookmarks.dropZone.create], and :ui[bookmarks.dropZone.clone].
- The add button at the bottom of the sidebar adds groups and repositories.

Double-click a repository to open it. It opens in the same window, in place of the Repositories view. To get the list back, click :ui[toolbar.bookmarks] at the top of the sidebar. [The Repositories Window](/guide/repositories/manager/) covers the list in detail.

## The repository window {#repository-window}

Once a repository is open, the window title shows its name. Below the name is the current view with a short summary, such as the branch and the number of changed files.

::screenshot[A repository window. The sidebar on the left lists the repository’s views, branches, tags, and remotes. The toolbar runs across the top. The middle column shows the commit area above a list of changed files, and the right column shows the changes in the selected file.]{name="tour-window" frame="window" markers="16.5,47 50,3.25 36,72 85,31"}

1. The sidebar
2. The toolbar
3. The middle column: the list for the current view
4. The right column: details of what is selected in the middle column

:::note[Server repositories]
The window title starts with the host alias, as in `alias:name`. The toolbar also shows the host alias in a :ui[toolbar.host] item. [Connection Status and Reconnecting](/guide/server/connection/) explains what the window shows when the connection drops.
:::

### Sidebar {#sidebar}

The :ui[workspace.group] section at the top switches between the views of the repository:

| View | What it shows |
|---|---|
| :ui[workspace.title] | Your uncommitted changes. The number next to it counts the changed files. |
| :ui[history.title] | The commits |
| :ui[stash.title] | Changes you set aside |
| :ui[pr.title] | Pull requests or merge requests from the hosting service |
| :ui[review.title] | Your branches, to find the ones you can clean up |
| :ui[reflog.title] | Where HEAD has been. Shown after you turn on :ui[sidebar.showReflog] in :ui[sidebar.viewSettings]. |
| :ui[repositorySettings.title] | Settings for this repository. See [Repository settings](/guide/settings/identity/#repository). |

Below it come :ui[sidebar.pinned] (once you pin a branch), :ui[branch.group], :ui[sidebar.archived], :ui[sidebar.tags], :ui[remote.group], :ui[submodule.group], and :ui[worktree.group]. In :ui[branch.group], a HEAD badge marks the branch you’re on. An arrow with a number, such as ↑3, counts the commits you haven’t pushed yet.

The bar at the bottom of the sidebar has a :ui[sidebar.filter] field, an :ui[reference.addMenu] button for creating branches and other references, and :ui[sidebar.viewSettings] for choosing what the sidebar shows.

### Toolbar {#toolbar}

From left to right, the toolbar has these buttons:

- :ui[toolbar.bookmarks]: back to the Repositories view
- :ui[toolbar.previous] and :ui[toolbar.next]: move back and forward through the views you visited
- :ui[toolbar.finder] and :ui[toolbar.terminal]: show the repository folder in Finder, or open it in a terminal
- :ui[sync.fetch], :ui[sync.pull], and :ui[sync.push]: exchange commits with remotes
- :ui[toolbar.forcePush]: replace a remote branch with yours after you rewrite commits
- :ui[toolbar.applyStash] and :ui[toolbar.saveStash]: bring back changes you set aside, or set your current changes aside
- :ui[toolbar.createBranch]: start a new branch
- :ui[action.refresh]: read the repository again
- :ui[action.search]: filter the list of the current view

Hold <kbd>⌥</kbd> and :ui[sync.fetch], :ui[sync.pull], and :ui[sync.push] become quick versions, such as :ui[sync.quickPush]. A quick version works with the tracking branch right away, without opening a dialog.

:ui[toolbar.clone] appears while you have recent clones. See [The Repositories Window](/guide/repositories/manager/). Choose :ui[menu.view > menu.customizeToolbar] to add or remove buttons. Besides the buttons above, you can add :ui[toolbar.quickActions], :ui[toolbar.synchronize], :ui[sync.merge] and :ui[sync.rebaseHead], and :ui[toolbar.pushTo].

### The three columns {#columns}

The left column is the sidebar. The middle column shows the list for the view you chose. In :ui[workspace.title], that’s the commit area and the changed files. In :ui[history.title], it’s the commits.

The right column shows the details of what you select in the middle. In :ui[workspace.title], that’s the changes in the selected file. When a file has both staged and unstaged changes, use :ui[working.staged] and :ui[working.unstaged] at the top to switch between them. With nothing selected, the column shows :ui[detail.empty.title].

### Quick Actions {#quick-actions}

Choose :ui[menu.file > quickActions.menu] or press <kbd>⇧⌘A</kbd> to open a panel. Type to find a view, a branch, a file, or a commit, then run an action on it without leaving the keyboard. [Windows and Navigation](/guide/repositories/navigation/) explains what it finds and which keys it uses.

## See also

- [Your First Repository](/guide/start/first-repository/)
- [The Repositories Window](/guide/repositories/manager/)
- [Windows and Navigation](/guide/repositories/navigation/)
