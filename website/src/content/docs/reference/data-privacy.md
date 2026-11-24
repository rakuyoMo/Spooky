---
title: "Data and Privacy"
description: "Learn what Spooky stores and where, which network addresses it connects to, and what crash and diagnostic reports contain."
---

There’s no Spooky account, and Spooky doesn’t collect usage data. This page lists what it stores, where it stores it, and which addresses it connects to.

## On your Mac {#mac}

| What | Where |
|---|---|
| Settings, the repository list, user profiles, the list of hosting accounts, and the locations of server repositories on this Mac | Spooky’s preferences, `com.rakuyo.spooky` |
| Themes, one `.spookytheme` file each | `~/Library/Application Support/Spooky/Themes/` |
| Small `.spookyrepo` folders that let server repositories show up among recent documents | `~/Library/Application Support/Spooky/Locations/` |
| Records of remote operations in :ui[activity.title], such as fetch, pull, and push, kept for 7 days | `~/Library/Application Support/Spooky/Activity/` |
| What :ui[activity.title] compares against to count changes, one file per repository | `~/Library/Application Support/Spooky/Baselines/` |
| Usernames and passwords you saved for Git on a server | Keychain, items named `com.rakuyo.spooky.remote.<host alias>` |
| Hosting account tokens | Keychain, items named `com.rakuyo.spooky.hosting.<address>` |
| Caches and cookies that macOS keeps for Spooky’s network requests | `~/Library/Caches/com.rakuyo.spooky/`, and the items in `~/Library/HTTPStorages/` whose names begin with `com.rakuyo.spooky` |
| Connection files for server repositories | `/tmp/spooky-*` folders, removed when the connection closes |
| Copies of files you open in Quick Look or other apps | Temporary `spooky-files-*` folders, removed when the repository closes |

If you sign in to a self-managed GitLab with a username and password, Spooky keeps the tokens it gets in return. It doesn’t keep the password.

To remove all of this, see [Uninstall](/guide/start/install/#uninstall).

Host aliases you add in :ui[app.name > settings.title] › :ui[settings.sshHosts] go to `~/.ssh/config`, the file SSH itself reads. That file isn’t Spooky’s, and uninstalling Spooky leaves it as it is. See [Add a host alias](/guide/server/prepare-ssh/#alias).

## On servers {#servers}

Besides the repository itself, Spooky writes to two places on a server:

- `~/.spooky/bin/` in your home folder: a small script that Spooky runs over SSH, plus links to it for prompts and signing. It stays there for the next connection. Each time Spooky installs the script, it deletes older versions that haven’t been used for 30 days. Delete the folder to remove it.
- `/tmp/spooky-*`: files for the current connection. They’re removed when the connection closes.

When Spooky looks for a repository’s [location on this Mac](/guide/server/local-location/#automatic), it briefly puts an empty file in the repository’s Git folder. It deletes the file right after the check.

When Git on a server asks for a password, Spooky sends the answer from your Mac over the SSH connection, only to the Git command that asked. Git on the server doesn’t save it, because Spooky turns off Git’s credential helpers for its commands.

## In repositories {#repositories}

Spooky saves a few things in the repository’s own Git configuration, as `branch.<name>.spooky-*` entries:

- Which branches are pinned or archived
- The parent branch of each branch
- Marks used for automatic archiving

These entries move with a branch when you rename it, and go away when you delete it. Git settings you change in the repository’s :ui[repositorySettings.title], such as signing, go to the same configuration. See [Repository settings](/guide/settings/identity/#repository).

Git configuration isn’t pushed, so none of this reaches your remotes. For a server repository, it’s stored on the server.

## Network connections {#network}

| Spooky connects to | When |
|---|---|
| Your servers, over SSH | While a server repository is open. Spooky uses the host alias in `~/.ssh/config`. An SMB mount also connects to the server’s file sharing. |
| Your Git remotes | When you fetch, pull, push, or clone, and during automatic fetch. For a server repository, Git connects from the server, not from your Mac. |
| `github.com` and `api.github.com`, or the address of your GitLab | When you add or re-authenticate a hosting account, and when you use a feature that needs one: pull requests and merge requests, issue number completion, the status in Branches Review, and publishing a repository. These requests come from your Mac. See [Where requests go](/guide/hosting/accounts/#network). |
| `gravatar.com` | To show pictures of commit authors |
| `github.com`, for Spooky’s releases | To check for updates |

Automatic fetch runs every 30 minutes by default. To change it, open :ui[app.name > settings.title], click :ui[settings.general], and pick an option next to :ui[settings.autoFetch]. Choose :ui[settings.autoFetch.never] to fetch only when you ask. See [Operations](/guide/settings/general/#operations).

For a commit author’s picture, Gravatar gets a hash of the author’s email address, not the address itself. Downloaded pictures stay in memory only, and are gone when you quit Spooky. Pictures of GitHub and GitLab users come from those services. There’s no setting to turn pictures off.

Spooky checks for updates once a day by default. To stop it, turn off :ui[updates.automaticChecks] in :ui[app.name > settings.title] › :ui[settings.updates]. See [Keep Spooky up to date](/guide/start/install/#updates).

Items in the :ui[menu.help] menu, such as :ui[help.help] and :ui[help.support], open web pages in your browser.

## Crash reports {#crash-reports}

If Spooky quit unexpectedly last time, it reads the crash report that macOS saved on your Mac. At the next launch, it asks: :ui[crash.title].

- Click :ui[crash.report] to open a new issue page on GitHub in your browser, filled in with a summary of the crash.
- Click :ui[crash.dontReport] to skip it. Spooky doesn’t ask about that crash again.

The summary has the Spooky version and build, the macOS version, the type of crash, and up to 30 lines of the call stack of the thread that crashed. Before it leaves your Mac, Spooky replaces your home folder, username, email addresses, IP addresses, tokens, and passwords in web addresses with placeholders.

The summary is part of the page’s web address. GitHub receives it as soon as the page opens. The issue is created only when you submit it in the browser. You can edit the text first, or close the page.

To skip the question next time, select :ui[settings.crashReports.always] in the dialog. Spooky then opens the issue page right away. The same option is in :ui[app.name > settings.title] › :ui[settings.integration].

## Diagnostic reports {#diagnostic-reports}

When you report a problem, a diagnostic report helps show what happened. Choose :ui[menu.help > help.diagnosticReport] and pick where to save it. Spooky saves a text file and shows it in Finder. It doesn’t send the report anywhere.

The report contains:

- The Spooky version and build, the macOS version, and your first three preferred languages
- The Git program on this Mac and its version
- Settings that affect how Spooky runs, such as appearance, update channel, terminal app, diff and merge tools, SSH agent, Git program, and whether to read environment variables from the login shell
- How many local and server repositories you have
- The names, times, and results of the last 20 operations
- Spooky’s log from the last hour of the current run, up to 500 lines

It doesn’t contain repository paths, host aliases, passwords, or values of environment variables. Spooky replaces your home folder, username, email addresses, IP addresses, and tokens with placeholders, the same way as in crash reports. Open the file and read it before you share it.

Spooky’s log notes connection changes, and when operations start, finish, or fail. It doesn’t record command arguments or output, commit messages, passwords, or tokens.

## See also

- [Install Spooky](/guide/start/install/)
- [How Server Repositories Work](/guide/server/overview/)
- [Hosting Accounts](/guide/hosting/accounts/)
- [System Requirements](/reference/requirements/)
