---
title: "How Server Repositories Work"
description: "Learn what happens on the server and what happens on your Mac, what Spooky keeps on the server, and how server repositories differ from local ones."
---

A server repository is a Git repository on another machine that Spooky opens over SSH. Its files stay on the server, and Git runs there. You don’t clone it to your Mac first. This page explains what each side does, what Spooky leaves on the server, and what works differently from a repository on your Mac.

To set one up, start with [Prepare SSH](/guide/server/prepare-ssh/), then [Add Server Repository](/guide/server/add/).

## What happens where {#where}

Spooky connects with the SSH that comes with macOS. It uses a host alias from your `~/.ssh/config` file, so it logs in to the server the same way the `ssh` command in Terminal does.

On the server:

- Git runs every command, using the server’s own Git and environment.
- Spooky reads and writes files over SFTP, the file transfer part of SSH.
- Files you delete, and new files you discard, go to the server’s Trash if it has one.
- Fetch, pull, and push reach remotes such as GitHub from the server. They use the server’s network and the server’s SSH keys.

On your Mac:

- The windows, lists, and diffs you work with.
- The SSH connection to the server. Spooky keeps one connection for each open repository and sends every command through it.
- Questions from Git on the server, such as a password or a key passphrase. See [Password and passphrase prompts](/guide/server/connection/#prompts).
- Requests to GitHub and GitLab, such as signing in to your account or loading pull requests.
- Copies of files that you open in Quick Look or in another app.

:::note
For a remote reached over SSH, the server has to know the remote’s host key already. If it doesn’t, log in to the server and connect to the remote once from there.
:::

## What Spooky keeps on the server {#on-server}

Spooky doesn’t need administrator access, and it doesn’t install a service. It leaves two things on the server:

- **A helper script in `~/.spooky/bin/`** in your home folder on the server. It passes Git’s questions back to your Mac. Spooky puts it there when it connects and keeps it for later connections. The other names in that folder, ending in `-askpass`, `-gpg`, and so on, are links to the same file.
- **Temporary files in `/tmp/spooky-*`** while a repository is open. Spooky removes them when you close the repository.

The helper runs with `/usr/bin/perl`, which most macOS and Linux servers already have. For the full list, see [System Requirements](/reference/requirements/#servers).

You can delete `~/.spooky` at any time. Spooky installs the helper again the next time it connects.

## How server repositories differ {#differences}

A server repository opens in the same kind of window as a repository on your Mac. Most views and commands work the same way. These are the visible signs that a repository is on a server:

::screenshot[A server repository window. The title reads spooky-test:driftwood, with the current view and branch below it. The toolbar shows the host alias spooky-test. A strip at the top of the middle column reads spooky-test: Connected. Below it are the commit area and the list of changed files. The right column shows the changes in the selected file.]{name="hero" frame="window" markers="45.8,3.3 64.4,7.2 40,8.9"}

1. The window title starts with the host alias, as in `driftwood-server:driftwood`. The Repositories window shows names the same way.
2. The :ui[toolbar.host] item in the toolbar shows the host alias.
3. The connection status shows at the top of the Working Copy, History, and other lists. See [Connection Status and Reconnecting](/guide/server/connection/).

Some things work differently:

| What | In a server repository |
|---|---|
| Changes made on the server | Spooky checks the server for changes every 2 seconds while the repository’s window is in front, and every 10 seconds otherwise. When the server is slow to answer, it checks less often. |
| Losing the connection | You can still look at what Spooky last read, but you can’t change anything until it reconnects. |
| :ui[action.revealFinder] | Finder needs a folder on your Mac that shows the server’s files. See [Location on This Mac](/guide/server/local-location/). |
| :ui[action.openTerminal] | Terminal logs in to the server with `ssh` and goes to the repository folder. |
| :ui[action.copyPath] | The copied path starts with the host alias, as in `driftwood-server:/srv/git/driftwood`. |
| Opening a file in another app | Most apps get a copy of the file. Spooky writes your changes back to the server when you save. See [Terminal and other apps](/guide/server/local-location/#terminal). |
| Discarding or deleting files | Spooky asks before it discards changes, because that overwrites files on the server. Deleted files and discarded new files go to the server’s Trash. If the server has no Trash, Spooky asks first, then deletes them for good. |
| :ui[settings.environment] settings | They apply only to Git on your Mac. Git on a server uses the server’s own environment. See [Environment](/guide/settings/general/#environment). |

You can turn off the confirmations for discarding changes, deleting files for good, and restoring files in :ui[app.name > settings.title] › :ui[settings.general]. See [Confirmations](/guide/settings/general/#confirmations).

## See also

- [Prepare SSH](/guide/server/prepare-ssh/)
- [Add Server Repository](/guide/server/add/)
- [System Requirements](/reference/requirements/)
