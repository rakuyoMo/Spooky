---
title: "Add Server Repository"
description: "Fill in the Add Server Repository dialog, read the results of the connection check, and clone or scan for repositories on the server."
---

Adding a server repository puts it in your Repositories list and opens it. Spooky checks the connection first. If something is missing, the dialog tells you what to fix.

Before you start, make sure Terminal can connect to the server without asking anything. See [Prepare SSH](/guide/server/prepare-ssh/).

To open the dialog, choose :ui[action.addRemote] from the :ui[menu.file] menu, or from the add button’s menu in the Repositories window.

## Fill in the dialog {#dialog}

::screenshot[The Add Server Repository dialog. Host alias is spooky-test. Repository path is /srv/git/driftwood, with a Browse button next to it. Mount on This Mac is set to Don’t Mount. The buttons are Cancel and Open.]{name="add-server" frame="dialog"}

| Field | What to enter |
|---|---|
| :ui[remote.host] | The `Host` name from `~/.ssh/config`, such as `driftwood-server`. Enter only the alias, without a username or port. To add one, see [Add a host alias](/guide/server/prepare-ssh/#alias). |
| :ui[remote.path] | The full path of the repository on the server, starting with `/`, such as `/srv/git/driftwood` |
| :ui[remote.mount] | Optional. Makes the repository’s folder available on this Mac, so Finder can show it. See [Mount while adding](/guide/server/local-location/#when-adding). |

If you don’t know the path, click :ui[clone.browse] once the host alias is filled in. Spooky lists the folders on the server, starting at the path you entered, or at your home folder there. Git repositories are marked :ui[browse.repository]. Folders you can’t read are dimmed. Double-click a folder to go into it, then click :ui[bookmarks.create.choosePrompt].

You can also pick a folder inside a repository. Spooky opens the repository it belongs to.

:ui[action.open] is available once the host alias is filled in and the path starts with `/`.

## The connection check {#check}

When you click :ui[action.open], Spooky shows :ui[remote.checking] at the bottom of the dialog and checks these, in order:

1. SSH logs in with the host alias.
2. Git is on the server, version 2.41.0 or later.
3. The folder exists, and you can open and read it.
4. The folder is in a Git repository, and Git can read its status.

The fields are locked during the check. Click :ui[action.cancel] to stop it and close the dialog.

When everything passes, Spooky sets up its helper on the server, adds the repository to the Repositories list, and opens it.

## When the check fails {#results}

The dialog stays open and keeps what you typed. At the bottom, it shows what to fix, followed by the original output from SSH or Git. Fix the problem and click :ui[action.open] again.

| What went wrong | What to do |
|---|---|
| The host alias isn’t valid | Enter just the alias from the `Host` line, without spaces, `@`, `:`, or `/`. |
| The server’s fingerprint is unknown | Connect once in Terminal and check the fingerprint. See [Connect once](/guide/server/prepare-ssh/#fingerprint). Spooky never accepts a fingerprint for you. |
| The server’s fingerprint changed | Don’t connect yet. Confirm the change with the server’s owner first. |
| SSH can’t log in | The server doesn’t accept your key, or your Mac can’t unlock it. See [Test the way Spooky connects](/guide/server/prepare-ssh/#test). |
| The server can’t be reached | Check the host alias and your network, then try again. |
| Git isn’t found | Install Git 2.41.0 or later on the server. If it’s installed, SSH logins can’t find it. The output lists the `PATH` the server uses. Add Git’s folder to it in the shell startup file on the server. |
| Git is too old | Update Git on the server to 2.41.0 or later. |
| The folder doesn’t exist | Check the path. To start a new repository there, click :ui[bookmarks.noRepository.create]. |
| No permission for the folder | Your user on the server needs permission to open and read the folder. |
| macOS on the server blocks the folder | The server is a Mac, and the repository is in a protected folder such as Documents. Turn on full disk access for remote users, as in [Use a Mac as the server](/guide/server/prepare-ssh/#mac-server), or move the repository. |
| The folder isn’t a Git repository | Choose the repository’s folder, or click :ui[bookmarks.noRepository.create] to make this folder one. If Git’s output mentions ownership, the folder belongs to another user on the server. |
| Git can’t read the status | Git’s output below explains why. |
| The server session can’t be set up | The server’s SSH has to allow Unix socket forwarding. The server also needs `/usr/bin/perl`, and you need write access to `~/.spooky/bin` and `/tmp` there. See [System Requirements](/reference/requirements/#servers). |

::screenshot[The Add Server Repository dialog with the host alias spooky-test and the path /srv/git/driftwood. Below the fields, a warning asks to check that the absolute path exists on the selected server, followed by the original output, “Directory does not exist”. The buttons are Cancel, Create Repository, and Open.]{name="server-add-error" frame="dialog"}

:ui[bookmarks.noRepository.create] runs `git init` in that folder, and creates the folder first if it’s missing. Spooky then checks the connection again and opens the new repository.

To see the `PATH` and the Git that a server uses without adding a repository, open :ui[app.name > settings.title] › :ui[settings.environment]. Enter the host alias at the bottom, then click :ui[settings.environment.server.check]. See [Check a server](/guide/settings/general/#server-check).

## Git environment variables on the server {#environment}

After the check, Spooky may show :ui[remote.environment.title]. The server’s non-interactive shell sets variables whose names start with `GIT_`. They change how Git finds repositories and reads its settings, for every command Spooky runs there.

Click :ui[action.close], and the repository opens. If Git behaves unexpectedly in it, remove those variables from the shell startup files on the server.

## Clone and search on a server {#clone-scan}

There are two more ways to get a server repository into the list:

- **Clone:** In the clone dialog, choose a server in :ui[clone.to]. Git clones the repository on the server, and Spooky adds it as a server repository. See [Clone a repository](/guide/repositories/manager/#clone).
- **Search:** Choose :ui[scan.menu] from the add button’s menu, then choose a server in :ui[scan.in]. Spooky searches the folder on the server and lists the repositories it finds. See [Search for repositories](/guide/repositories/manager/#scan).

## See also

- [Prepare SSH](/guide/server/prepare-ssh/)
- [Connection Status and Reconnecting](/guide/server/connection/)
- [Location on This Mac](/guide/server/local-location/)
