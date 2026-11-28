---
title: "General, Updates, and Environment"
description: "Find your way around the Settings window, and set the options on the General, Updates, and Environment pages."
---

Settings apply to Spooky as a whole. Most of them take effect as soon as you change them. There’s no Save button.

## The Settings window {#window}

Choose :ui[app.name > settings.title] (<kbd>⌘,</kbd>). The pages are along the top of the window, and the title shows the page you’re on.

| Page | What it sets | Described in |
|---|---|---|
| :ui[settings.general] | Cloning, background operations, confirmations, history, the file list, and windows | [General](#general) |
| :ui[settings.appearance] | Light or dark, and the app icon | [Appearance and Themes](/guide/settings/appearance/#appearance) |
| :ui[settings.gitConfig] | The Git program, your global Git identity, signing, and external diff and merge tools | [User Profiles and Git Config](/guide/settings/identity/#git-config) |
| :ui[settings.text] | Syntax coloring, invisible characters, and tab width in diffs and files | [Appearance and Themes](/guide/settings/appearance/#text) |
| :ui[settings.editor] | How the commit message is checked and wrapped | [Appearance and Themes](/guide/settings/appearance/#editor) |
| :ui[settings.themes] | Colors and font for diffs and files | [Appearance and Themes](/guide/settings/appearance/#themes) |
| :ui[settings.profiles] | Identities you can switch between when you commit | [User Profiles and Git Config](/guide/settings/identity/#profiles) |
| :ui[settings.accounts] | GitHub and GitLab accounts | [Hosting Accounts](/guide/hosting/accounts/) |
| :ui[settings.sshHosts] | Host aliases for your servers, saved in `~/.ssh/config` | [Prepare SSH](/guide/server/prepare-ssh/#alias) |
| :ui[settings.integration] | Links from github.com, the SSH agent, and crash reports | [Integration](/guide/settings/integration/#integration-page) |
| :ui[settings.environment] | Environment variables for Git on this Mac, and a check of a server’s environment | [Environment](#environment) |
| :ui[settings.updates] | How Spooky updates itself | [Updates](#updates) |

Settings for a single repository, such as its identity and signing, are in the repository window instead. See [Repository settings](/guide/settings/identity/#repository).

## General {#general}

The :ui[settings.general] page is a long list. The sections below follow it from top to bottom.

::screenshot[The General page of the Settings window, with the clone location, terminal app, operation and confirmation options, history and diff options, and file list options.]{name="settings-general" frame="window"}

### Cloning and Terminal {#cloning}

| Setting | What it does |
|---|---|
| :ui[settings.cloneDirectory] | Where the clone dialog suggests putting new repositories. It’s your home folder at first. The menu also lists `~/Development` if you have one. Choose :ui[settings.cloneDirectory.select] to pick another folder. |
| :ui[settings.terminal] | The app that :ui[action.openTerminal] uses. See [Terminal](/guide/settings/integration/#terminal). |

### Operations {#operations}

| Setting | Default | What it does |
|---|---|---|
| :ui[settings.autoFetch] | Every 30 minutes | How often Spooky fetches in the background. See [Fetch automatically](/guide/branches/sync/#auto-fetch). |
| :ui[stash.offerAutoStash] | On | When local changes block an operation, asks whether to stash them first. See [Auto stash](/guide/work/stash/#auto-stash). |
| :ui[settings.autoUpdateSubmodules] | Off | Updates checked-out submodules after operations that move their pointers, without asking. See [Update after other operations](/guide/advanced/submodules/#auto-update). |
| :ui[branch.cleanNames] | On | Fixes the names of branches, tags, and remotes for Git while you type. See [Create a branch](/guide/branches/branches/#create). |
| :ui[settings.autoArchive] | Off | Archives branches that look finished. See [Archive automatically](/guide/branches/review/#auto-archive). |

### Confirmations {#confirmations}

These questions each have :ui[dialog.doNotAskAgain]. Selecting it there turns off the matching setting here. Turn the setting back on to get the question again. All four are on at first.

| Setting | Asks before |
|---|---|
| :ui[settings.warnDiscardingChunks] | Discarding chunks or lines, in any repository. See [Discard changes](/guide/work/diff/#discard). |
| :ui[settings.warnDiscardingOnServer] | Discarding whole files in a server repository |
| :ui[settings.warnDeletingOnServer] | Deleting files for good on a server that has no Trash |
| :ui[settings.warnRestoringOnServer] | Restoring files from a revision in a server repository. See [Restore a file from a revision](/guide/history/file-views/#restore). |

In a local repository, discarding whole files always asks.

### History and diffs {#history}

| Setting | Default | What it does |
|---|---|---|
| :ui[history.pageSize] | 100 | How many commits the history loads at a time: 100, 200, 500, or 1,000 |
| :ui[settings.dateFormat] | Absolute | Absolute dates are short, like 10/26/26. Relative dates say “Today” or “Yesterday” for those two days and write out other dates in full. The menu shows a sample of each. |
| :ui[history.mergeDiff] | :ui[history.mergeDiff.firstParent] | What the changeset of a merge commit shows. See [The changeset](/guide/history/commit-details/#changeset). |
| :ui[working.diffThreshold] | 20,000 | Diffs larger than this many kilobytes ask before they’re shown. Choose a value or type one. See [Read a diff](/guide/work/diff/#read). |

The date format applies to the history, stashes, file history, and the Reflog.

### File list {#file-list}

| Setting | Default | What it does |
|---|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] | Or open the file in your diff tool |
| :ui[files.openSubmodules] | On | Double-clicking a submodule opens it in Spooky instead of another app |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] | Or show the file in Quick Look |
| :ui[files.fontSize] | :ui[files.fontSize.medium] | Or :ui[files.fontSize.regular] |
| :ui[files.truncation] | :ui[files.truncation.beginning] | Or shorten the middle of long names |

See [Settings for the file list](/guide/work/working-copy/#settings) for how these work in the Working Copy.

### Windows and the Repositories list {#windows}

| Setting | Default | What it does |
|---|---|---|
| :ui[settings.windowRestoration] | :ui[settings.windowRestoration.system] | What Spooky reopens when it starts. See [Pick up where you left off](/guide/repositories/navigation/#restore). |
| :ui[settings.showLaunchWindow] | Off | Shows a window with your recent repositories when Spooky starts |
| :ui[settings.showWorktreesInRepositoryList] | Off | Lists the worktrees of each repository in the Repositories list |
| :ui[settings.showHostAliasesInRepositoryList] | On | Shows the host alias of each server repository in the Repositories list |
| :ui[settings.showDeveloperMenu] | Off | Adds the :ui[menu.developer] menu, with tools for testing Spooky itself |

## Updates {#updates}

The :ui[settings.updates] page sets the release channel, whether Spooky checks for updates and downloads them on its own, and how often it checks. [Keep Spooky up to date](/guide/start/install/#updates) explains each option.

## Environment {#environment}

Apps opened from Finder or the Dock don’t get the environment you have in Terminal. For example, `PATH` may be missing folders like `/opt/homebrew/bin`. Git hooks, credential helpers, and Git LFS may then not be found. The :ui[settings.environment] page fixes that for Git on this Mac.

### Variables on this Mac {#local-variables}

| Setting | What it does |
|---|---|
| :ui[settings.environment.loginShell] | Starts your login shell once, reads the variables its startup files set, and passes them to Git and to toolbar button scripts. The table below it lists what was read. On at first. |
| :ui[settings.environment.custom] | Variables you add yourself. Click the add button to add one, and the remove button to remove the selected one. These override the login shell’s. |

A few things to know:

- Changes apply to the next Git command. You don’t need to restart Spooky.
- The login shell is read again each time Spooky starts. If reading fails, the page tells you so.
- If two custom variables have the same name, the lower one wins. A variable with a name that isn’t valid stays in the table but isn’t passed to Git.
- To use an SSH agent other than the system one, set `SSH_AUTH_SOCK` here or in your login shell. See [SSH agent](/guide/settings/integration/#ssh-agent).

:::note[Server repositories]
These variables apply only to Git and toolbar button scripts on this Mac. Git on a server uses the server’s own environment.
:::

### Check a server {#server-check}

At the bottom of the page, you can see the environment Git gets on a server, without adding a repository:

1. Type a host alias in the :ui[remote.host] field. You can also pick one from the :ui[settings.environment.server.hosts] menu. It lists the servers of your server repositories.
2. Click :ui[settings.environment.server.check].

::screenshot[The server check at the bottom of the Environment page in Settings. A host alias has been checked, and the result shows the Git found on the server with its version.]{name="settings-environment" frame="closeup"}

The result shows the Git that SSH logins find and its version, or :ui[settings.environment.server.noGit]. Below that, it lists each folder in `PATH` and the names of any variables that start with `GIT_`. If Git isn’t found, see [Git isn’t found on the server](/reference/troubleshooting/#server-path).

## See also

- [Appearance and Themes](/guide/settings/appearance/)
- [User Profiles and Git Config](/guide/settings/identity/)
- [Integration](/guide/settings/integration/)
- [Install Spooky](/guide/start/install/)
