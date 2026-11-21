---
title: "Integration"
description: "Choose external diff and merge tools, editors, and terminals, and set up Finder integration."
---

Spooky works with other apps on your Mac: your browser, diff and merge apps, editors, a terminal, and Finder. This page shows where each one is set up.

## The Integration page {#integration-page}

:ui[app.name > settings.title] › :ui[settings.integration] has three settings.

### Links from github.com {#github-links}

On github.com, the button that opens a repository in a desktop app sends a link to your Mac. :ui[settings.github] decides which app gets it. The menu lists the apps on your Mac that can open these links.

Choose Spooky, and these links open the clone dialog. See [Clone a repository](/guide/repositories/navigation/#link-clone).

### SSH agent {#ssh-agent}

An SSH agent keeps unlocked keys ready. Spooky uses it to log in to servers and remotes over SSH, and to sign commits with SSH keys.

:ui[settings.sshAgent] has one choice, :ui[settings.sshAgent.system]. Spooky finds it in this order:

1. `SSH_AUTH_SOCK` among your own variables on the :ui[settings.environment] page (see [Variables on this Mac](/guide/settings/general/#local-variables))
2. `SSH_AUTH_SOCK` from your login shell, if reading it is turned on there
3. The agent macOS starts for you

To use another agent, such as one that comes with a password manager, set `SSH_AUTH_SOCK` on the :ui[settings.environment] page or in your login shell.

If the agent isn’t running, a yellow warning button shows up next to the menu. Click it to see what to do.

:::note[Server repositories]
Spooky never forwards your agent to a server. Git on the server uses that machine’s own agent and keys.
:::

### Crash reports {#crash-reports}

If Spooky quit unexpectedly last time, it asks at the next launch whether to report the crash. Select :ui[settings.crashReports.always] to skip the question and open the issue page right away. It’s off at first.

See [Crash reports](/reference/data-privacy/#crash-reports) for what the report contains.

## Diff and merge tools {#diff-merge-tools}

The tools are set on the :ui[settings.gitConfig] page.

| Setting | What it does |
|---|---|
| :ui[externalTool.diffTool] | The app that compares files. :ui[externalTool.noneSelected] at first. |
| :ui[externalTool.directoryDiff] | When you compare several files, opens them as two folders in one window. Only Kaleidoscope supports this. Other apps open one file at a time. On at first. |
| :ui[externalTool.mergeTool] | The app that resolves conflicts. :ui[externalTool.noneSelected] at first. |
| :ui[externalTool.keepBackups] | Keeps the file as it was before the merge, next to it with `.orig` at the end. Off at first. |

Spooky works with these apps:

| App | Compare | Merge |
|---|---|---|
| Araxis Merge | Yes | Yes |
| BBEdit | Yes | No |
| Beyond Compare | Yes | Yes |
| DeltaWalker | Yes | Yes |
| FileMerge | Yes | Yes |
| Kaleidoscope | Yes | Yes |
| P4Merge | Yes | Yes |
| TextMate | Yes | No |
| Visual Studio Code | Yes | Yes |

The menus list apps that aren’t installed too, but you can’t choose them. If you use a tool before choosing one, Spooky asks which app to use.

To use them, see [Compare in another app](/guide/work/diff/#external) and [Merge in another app](/guide/work/conflicts/#merge-tool).

## Editors {#editors}

Spooky doesn’t have its own editor setting. To open a file in another app, right-click it in the Working Copy and choose :ui[files.open] or :ui[files.openWith]. The :ui[files.openWith] submenu lists the apps that can open the file, with the default one first. The same submenu is in the file tree of a commit and in the conflict wizard.

In a server repository, Visual Studio Code, Visual Studio Code Insiders, and Cursor open the file on the server directly, if their Remote SSH extension is installed. Other apps get a copy. When you save, Spooky writes your changes back to the server. See [Terminal and other apps](/guide/server/local-location/#terminal).

## Terminal {#terminal}

:ui[settings.terminal] on the :ui[settings.general] page chooses the app for :ui[action.openTerminal]. Spooky works with Terminal, iTerm, Warp, Ghostty, WezTerm, and Otty. The menu lists the ones that are installed. Terminal is used at first.

You’ll find :ui[action.openTerminal] in these places:

- The :ui[menu.file] menu
- :ui[toolbar.terminal] in the toolbar
- The menu of the Working Copy in the sidebar
- The menu of a file or folder in the Working Copy’s file list. The terminal opens in that folder, or in the folder the file is in.
- The menus of repositories in the Repositories window and of recent clones
- The menu of a worktree in the sidebar
- [Quick Actions](/guide/repositories/navigation/#quick-actions)

For a local repository, the terminal opens in the folder on this Mac. For a server repository, it logs in with SSH and goes to the folder on the server. See [Terminal and other apps](/guide/server/local-location/#terminal).

The first time Spooky opens Terminal or iTerm, macOS asks whether Spooky may control it. If you don’t allow it, Spooky shows :ui[error.terminal]. To allow it later, go to **Apple menu › System Settings › Privacy & Security › Automation**, and turn on the app under Spooky.

## Finder {#finder}

- **Show a folder**: :ui[action.revealFinder] shows the repository folder or a file in Finder. For a server repository, it needs a location on this Mac. See [Show in Finder](/guide/server/local-location/#show-in-finder).
- **Add repositories**: drag repository folders from Finder into the Repositories window. See [Add repositories](/guide/repositories/manager/#add).
- **The Dock**: drop a folder on Spooky’s icon to open the repository it’s in. Right-click the icon to choose a recent repository, server repositories included. See [Recent repositories and the Dock](/guide/repositories/navigation/#recent).
- **Themes**: open a `.spookytheme` file in Finder to add the theme. See [Share themes](/guide/settings/appearance/#share-themes).

## See also

- [General, Updates, and Environment](/guide/settings/general/)
- [User Profiles and Git Config](/guide/settings/identity/)
- [Location on This Mac](/guide/server/local-location/)
- [Prepare SSH](/guide/server/prepare-ssh/)
