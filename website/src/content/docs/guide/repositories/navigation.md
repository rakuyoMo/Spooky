---
title: "Windows and Navigation"
description: "Work with windows and tabs, go back and forward, use Quick Actions, restore windows, use the Dock menu, and open spooky:// links."
---

This page is about getting around. You’ll see how to keep several repositories open, move between views, jump anywhere with Quick Actions, and come back to where you left off.

## Windows and tabs {#windows}

Each window or tab shows either the Repositories view or one repository.

- :ui[menu.file > menu.newTab] (<kbd>⌘T</kbd>) opens a new tab with the Repositories view. The add button at the end of the tab bar does the same.
- :ui[menu.file > menu.newWindow] (<kbd>⌘N</kbd>) opens a new window with the Repositories view.
- :ui[menu.view > menu.showRepositories] (<kbd>⌃⌘R</kbd>) shows the Repositories view in the current window.

If a repository is already open, opening it again switches to the window that shows it. To open it in a second window anyway, right-click it in the Repositories list and choose :ui[bookmarks.openNewWindow]{1="driftwood"}.

### Switch views {#views}

The :ui[menu.view] menu switches between the views of the repository:

| Shortcut | Menu item |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[stash.show] |
| <kbd>⌘4</kbd> | :ui[pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[review.show] |
| <kbd>⌘6</kbd> | :ui[reflog.show] |
| <kbd>⌘0</kbd> | :ui[history.showHead] |

:ui[menu.window > activity.title] (<kbd>⌃⌘0</kbd>) opens the Activity window. It lists what Spooky has run and is running. See [Operation Queue and Activity](/guide/advanced/queue-activity/).

## Go back and forward {#back-forward}

Each window remembers the views and repositories you visited, including the Repositories view. To retrace your steps:

- :ui[menu.view > navigation.back] (<kbd>⌘[</kbd>) or :ui[toolbar.previous] in the toolbar
- :ui[menu.view > navigation.forward] (<kbd>⌘]</kbd>) or :ui[toolbar.next] in the toolbar

If you go back and then open something new, the places you could go forward to are dropped.

## Quick Actions {#quick-actions}

Quick Actions let you find something by typing and act on it without leaving the keyboard. They’re available while a repository is shown. Choose :ui[menu.file > quickActions.menu] (<kbd>⇧⌘A</kbd>).

::screenshot[Quick Actions open over a repository window with “dark” typed in. The first result, the branch feature/dark-mode, is selected and shows its default action and the hint for more actions. Below it are the remote branch origin/feature/dark-mode, the Dark appearance, the Default (Dark) theme, and two commits whose messages mention dark.]{name="quick-actions" frame="window"}

With nothing typed, the panel lists the views of the repository, then branches (the current branch first), worktrees, remotes, submodules, remote branches, tags, stashes, user profiles, and appearances and themes. As you type, the list narrows down. Spooky also looks for:

- files in the current branch whose names match
- a commit, when you type 5 to 64 hexadecimal characters of its hash
- commits on the current branch whose messages contain the text, up to 100

Files and commits show up at the end of the list a moment after you stop typing.

Use these keys in the panel:

| Key | What it does |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Move the selection |
| <kbd>↩</kbd> | Run the default action of the selected item |
| <kbd>Tab</kbd>, or <kbd>→</kbd> at the end of the text | List all actions for the selected item |
| <kbd>←</kbd> with no text, or <kbd>⇧Tab</kbd> | Go back from the list of actions |
| <kbd>Esc</kbd> | Clear the text; with no text, go back from the list of actions or close the panel |

Only actions you can run right now are listed.

## Pick up where you left off {#restore}

:ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.windowRestoration] decides what Spooky shows when it starts:

| Choice | When Spooky starts |
|---|---|
| :ui[settings.windowRestoration.always] | Reopens your windows and tabs, each with the repository and view it showed when you quit |
| :ui[settings.windowRestoration.never] | Shows only the Repositories window |
| :ui[settings.windowRestoration.system] | Follows the macOS setting for keeping windows when you quit an app. This is the default. |

If a restored repository can’t be found anymore, its window shows that it’s missing. See [Missing repositories](/guide/repositories/manager/#missing).

Turn on :ui[settings.showLaunchWindow] to get a window at startup that lists your recent repositories. Double-click one, or select it and press <kbd>↩</kbd>, to open it. The window closes by itself once a repository window comes to the front. See [Windows and the Repositories list](/guide/settings/general/#windows) for both settings.

:::note[Server repositories]
Restored server repositories connect to their servers again when Spooky starts.
:::

## Recent repositories and the Dock {#recent}

:ui[menu.file > menu.openRecent] lists the repositories you opened recently, on your Mac and on servers. :ui[menu.clearRecent] at the bottom empties the list. Your bookmarks in the Repositories window stay.

Right-click Spooky’s icon in the **Dock** to get a menu with :ui[menu.newWindow] and your recent repositories. Choose a repository to open it. This works even when Spooky isn’t running yet.

You can also drop a folder on Spooky’s icon in the Dock to open the repository it’s in. If the folder isn’t in a Git repository, Spooky offers to create one.

## Open Spooky from a link {#links}

A link that starts with `spooky://` opens a repository or a clone. You can put these links in other apps, scripts, or notes.

### Open a repository {#link-open}

```
spooky://open?repository=<repository>&view=<view>
```

- `repository` is required. It’s the repository’s absolute path on your Mac, or `alias:path` for a server repository, URL-encoded.
- `view` is optional. Without it, the repository opens in the view it showed last.
- Two shorthands replace `view`: `branch=<name>` opens the history of that branch, and `commit=<hash>` opens that commit.

| `view` | Opens | Extra parameters |
|---|---|---|
| `workingCopy` | The Working Copy | |
| `history` | History | `ref=<reference>`, a full reference name such as `refs/heads/main`; can be repeated |
| `commit` | A commit | `commit=<hash>` |
| `stashes` | Stashes | |
| `reflog` | The reflog | |
| `pullRequests` | Pull requests or merge requests | |
| `branchesReview` | Branches review | |
| `settings` | Repository settings | |
| `remote` | A remote | `remote=<name>` |
| `submodule` | A submodule | `path=<path>` |
| `worktree` | A worktree | `path=<path>` |
| `fileHistory` | A file’s history | `path=<path>` |
| `file` | A file | `path=<path>`, and optionally `revision=<revision>` and `mode=blame` or `mode=raw` |

For example, this link opens the history of the branch `main` in the repository at `/Volumes/Projects/driftwood`:

```
spooky://open?repository=%2FVolumes%2FProjects%2Fdriftwood&branch=main
```

### Clone a repository {#link-clone}

```
spooky://clone?url=<address>
```

This opens the clone dialog with the address filled in. Nothing is cloned until you choose where to put it and click :ui[clone.submit]. See [Clone a repository](/guide/repositories/manager/#clone).

Set :ui[app.name > settings.title] › :ui[settings.integration] › :ui[settings.github] to Spooky, and the links on github.com that open a repository in a desktop app open this clone dialog too. See [Links from github.com](/guide/settings/integration/#github-links).

Some links can’t be used, for example one that names an unknown view or gives a relative path. For those, Spooky shows :ui[link.invalid.title] and does nothing else.

## See also

- [A Tour of Spooky](/guide/start/tour/)
- [The Repositories Window](/guide/repositories/manager/)
- [Keyboard Shortcuts](/reference/shortcuts/)
