---
title: "User Guide"
description: "Learn how this guide is organized and where to start reading."
---

This guide shows how to do everyday Git work in Spooky. It covers repositories on your Mac and repositories that stay on another machine you reach over SSH. Each page covers one task area and starts with what it helps you do.

If you’re new to Spooky, read the Getting Started pages in order. If your repositories live on a server, read Server Repositories next.

In Spooky, :ui[menu.help > help.help] (<kbd>⌘?</kbd>) opens this website. Many dialogs also have a help button. It opens the part of this guide about that dialog.

## How the guide is organized {#organization}

| Group | What it covers |
|---|---|
| [Getting Started](/guide/start/install/) | Installing and updating Spooky, the parts of its windows, and a first commit and push |
| [Repositories](/guide/repositories/manager/) | Keeping track of your repositories, windows and tabs, moving back and forward, and Quick Actions |
| [Server Repositories](/guide/server/overview/) | How Spooky works with repositories on a server, preparing SSH, adding a server repository, the connection, and the location on this Mac |
| [Everyday Work](/guide/work/working-copy/) | The Working Copy, reviewing and staging changes, committing, stashes, conflicts, and undo |
| [History](/guide/history/browse/) | Browsing history, commit details, file history and blame, and rewriting history |
| [Branches and Sync](/guide/branches/branches/) | Branches, tags and remotes, fetching, pulling and pushing, merging and rebasing, and cleaning up branches |
| [Collaboration](/guide/hosting/accounts/) | Hosting accounts, pull requests, and merge requests |
| [More Git Features](/guide/advanced/submodules/) | Submodules, worktrees, Git LFS, and how operations queue up |
| [Settings and Integration](/guide/settings/general/) | Settings, appearance and themes, user profiles and Git config, and working with other apps |
| [Reference](/reference/shortcuts/) | Keyboard shortcuts, system requirements, data and privacy, and troubleshooting |

## Conventions {#conventions}

### Names on screen {#names}

Names of buttons, menus, options, and windows are in bold, such as :ui[working.commit]. They come straight from Spooky. When Spooky runs in the language of this page, you see the same names on screen.

A menu path such as :ui[menu.file > action.openLocal] means: click the first name in the menu bar, then choose the next one from that menu.

Some pages also name parts of macOS, such as **System Settings**. They’re written the way macOS shows them.

### Keyboard shortcuts {#shortcuts}

Shortcuts look like keycaps, such as <kbd>⇧⌘A</kbd>. Hold the modifier keys, then press the last key. The symbols are the same ones macOS shows in its menus.

| Symbol | Key |
|---|---|
| <kbd>⌘</kbd> | Command |
| <kbd>⇧</kbd> | Shift |
| <kbd>⌥</kbd> | Option |
| <kbd>⌃</kbd> | Control |
| <kbd>↩</kbd> | Return |
| <kbd>⌫</kbd> | Delete |

All shortcuts are listed in [Keyboard Shortcuts](/reference/shortcuts/).

### Notes about server repositories {#server-notes}

A server repository stays on another machine, and Spooky opens it over SSH. Most tasks work the same way there. When something is different, the page says so in a note like this one:

:::note[Server repositories]
A note with this title tells you what’s different in a server repository. If you only use repositories on your Mac, you can skip these notes.
:::

## See also

- [Install Spooky](/guide/start/install/)
- [A Tour of Spooky](/guide/start/tour/)
- [How Server Repositories Work](/guide/server/overview/)
