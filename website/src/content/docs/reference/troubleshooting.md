---
title: "Troubleshooting"
description: "Fix common problems such as failed connections, an outdated Git, permissions, and PATH on the server, and learn how to report a problem."
---

Each problem below starts with what you see, then explains why it happens and what to do. Many errors in Spooky also show the original output from Git or SSH, which often names the exact cause.

## Can’t connect to a server {#connect}

A connection problem shows up in one of these places:

- The :ui[remote.form.title] dialog stays open and says what to fix. See [When the check fails](/guide/server/add/#results) for each case.
- Opening a server repository shows :ui[missing.unreachable.title]{1="driftwood-server"}. See [While disconnected](/guide/server/connection/#offline).
- In an open server repository, the strip at the top of the list turns yellow and names the reason. See [Connection status](/guide/server/connection/#status).

First, try the same login outside Spooky. Run this in Terminal, with your own host alias:

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

If it fails, the problem is between your Mac and the server. See [Test the way Spooky connects](/guide/server/prepare-ssh/#test) for what each kind of output means. If it works in Terminal but Spooky still can’t log in, Spooky may be using a different SSH agent. See [SSH agent](/guide/settings/integration/#ssh-agent).

The reason Spooky shows tells you where to look:

| Reason | What to do |
|---|---|
| :ui[remoteError.authentication] | The server doesn’t accept your key, or your Mac can’t unlock it. After a restart, load the key again, as in [After restarting your Mac](/guide/server/prepare-ssh/#after-restart). An account that can only log in with a password won’t work. |
| :ui[remoteError.unknownHostKey] | Your Mac doesn’t know the server yet. Connect once in Terminal and check the fingerprint, as in [Connect once](/guide/server/prepare-ssh/#fingerprint). Spooky never accepts a fingerprint for you. |
| :ui[remoteError.changedHostKey] | Don’t connect yet. Confirm the change with the server’s owner first. |
| :ui[remoteError.unavailable] | Check the host alias and your network. Spooky tries again 5 seconds after each failed attempt. To try right away, click :ui[action.reconnect] in the strip. See [Disconnects and reconnecting](/guide/server/connection/#reconnect). |
| :ui[remoteError.deployment] | The server is missing something Spooky needs: Unix socket forwarding, `/usr/bin/perl`, or write access to `~/.spooky/bin` and `/tmp`. See [Servers](/reference/requirements/#servers). |

If Git on the server is missing or too old, read on.

## Git is too old {#git-version}

Spooky needs Git 2.41.0 or later, both on your Mac and on servers.

### On your Mac {#mac-git}

When you open a local repository, Spooky may show one of these:

- :ui[error.version], with Git’s output below it. The Git program Spooky uses is older than 2.41.0. Choose a newer one next to :ui[settings.gitProgram] in :ui[app.name > settings.title] › :ui[settings.gitConfig], or update Xcode or the Command Line Tools.
- :ui[error.gitProgram], with the path below it. The Git program you chose isn’t there anymore, for example because you uninstalled it. Choose another one in the same place.

The menu lists only Git programs that are new enough. See [Git program](/guide/settings/identity/#git-program).

### On a server {#server-git}

The connection fails with :ui[remoteError.gitVersion]. Update Git on the server to 2.41.0 or later.

If a newer Git is already installed there, SSH logins find an older one first. Put the newer Git’s folder ahead of the others in `PATH`, as in [Git isn’t found on the server](#server-path).

## Git isn’t found on the server {#server-path}

The connection fails with :ui[remoteError.gitUnavailable]. Or, when you check the server in :ui[app.name > settings.title] › :ui[settings.environment], it shows :ui[settings.environment.server.noGit].

If Git isn’t installed on the server, install Git 2.41.0 or later. If it is, the cause is usually the `PATH`. Spooky runs commands on the server through SSH, without an interactive shell. That shell reads fewer startup files. A `PATH` that you set in `~/.zshrc` or `~/.bash_profile` may not apply.

To fix it:

1. Log in to the server in Terminal and run `command -v git`. It prints where Git is, such as `/opt/homebrew/bin/git`.
2. Compare it with the `PATH` that Spooky gets. The error’s output lists it, and so does the check in [Check a server](/guide/settings/general/#server-check).
3. Add Git’s folder to `PATH` in a startup file that non-interactive shells read. Run `echo $SHELL` on the server to see which shell you use.
   - zsh: `~/.zshenv`
   - bash: `~/.bashrc`, above any line that stops early when the shell isn’t interactive

   For example:

   ```sh
   export PATH="/opt/homebrew/bin:$PATH"
   ```

4. Click :ui[settings.environment.server.check] again, or run the test from [Can’t connect to a server](#connect). Then reconnect.

Git LFS and the programs your hooks run are found through the same `PATH`. If they work in Terminal but not from Spooky, for example when a command fails with :ui[hostError.lfsUnavailable], add their folders the same way.

## Permission problems {#permissions}

| What you see | Why, and what to do |
|---|---|
| :ui[remoteError.pathPermission] | Your user on the server can’t open or read the repository folder. Ask the server’s owner for access, or choose a folder you own. |
| :ui[remoteError.diskAccess] | The server is a Mac, and the repository is in a folder that macOS protects, such as Documents. Turn on full disk access for remote users, as in [Use a Mac as the server](/guide/server/prepare-ssh/#mac-server), or move the repository. |
| :ui[error.ownership] | The repository folder on this Mac belongs to another user. Git refuses to work in it. Change the folder’s owner to yourself. If you trust its owner, you can instead run the `git config --global --add safe.directory` command that Git’s output suggests. |
| :ui[error.terminal] | The details below the title say what went wrong. Often the terminal app chosen next to :ui[settings.terminal] isn’t installed anymore, or you didn’t allow Spooky to control Terminal or iTerm. See [Terminal](/guide/settings/integration/#terminal). |
| :ui[appIcon.writeFailed] | Spooky saves the icon into `Spooky.app`. Your user needs to be able to write to it. In Finder, select Spooky, choose **File › Get Info**, and check that you have **Read & Write** under **Sharing & Permissions**. |

:::note[Server repositories]
On a server, a folder that belongs to another user fails with :ui[remoteError.notWorkingTree], and Git’s output mentions ownership. Ask the server’s owner, or run the `safe.directory` command on the server.
:::

## Report a problem {#report}

Choose :ui[menu.help > help.support] to open Spooky’s issues on GitHub. Look for your problem there, or open a new issue. Say what you did, what you expected, and what happened. If Spooky showed an error, include its title and the original output.

A diagnostic report helps show what happened. Choose :ui[menu.help > help.diagnosticReport] and pick where to save it. Spooky saves a text file and shows it in Finder. It doesn’t send the report anywhere. Open the file and read it before you share it. See [Diagnostic reports](/reference/data-privacy/#diagnostic-reports) for what it contains.

If Spooky quit unexpectedly last time, it asks at the next launch: :ui[crash.title]. When you click :ui[crash.report], a new issue page on GitHub opens in your browser, with a summary of the crash filled in. The issue is created only when you submit it in the browser. See [Crash reports](/reference/data-privacy/#crash-reports).

## See also

- [Prepare SSH](/guide/server/prepare-ssh/)
- [Connection Status and Reconnecting](/guide/server/connection/)
- [System Requirements](/reference/requirements/)
- [Data and Privacy](/reference/data-privacy/)
