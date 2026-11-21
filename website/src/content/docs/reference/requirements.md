---
title: "System Requirements"
description: "Check what Spooky requires of macOS, Git, and your servers."
---

This page lists what Spooky needs on your Mac and on the servers you connect to.

## Mac {#mac}

| What | Requirement |
|---|---|
| macOS | macOS 26 or later |
| Git | Git 2.41.0 or later. Spooky uses `/usr/bin/git` unless you choose another one next to :ui[settings.gitProgram] in :ui[app.name > settings.title] › :ui[settings.gitConfig]. See [Git program](/guide/settings/identity/#git-program). |
| SSH | The SSH that comes with macOS. Server repositories use it to connect. |

Spooky relies on Git features added in version 2.41.0, so older versions don’t work.

## Servers {#servers}

A server can be a Linux machine or a Mac. Spooky doesn’t need administrator access there, and it doesn’t install a service.

| What | Requirement |
|---|---|
| Login | SSH login with a key, through a host alias in `~/.ssh/config` on your Mac. An account that can only log in with a password won’t work. See [Prepare SSH](/guide/server/prepare-ssh/). |
| Git | Git 2.41.0 or later, in the `PATH` that non-interactive SSH logins use |
| SSH server | OpenSSH with SFTP turned on and Unix socket forwarding allowed. Both are on by default. `MaxSessions` has to be 10 or more, which is also the default. |
| Passphrase prompts | OpenSSH 8.4 or later, if Git on the server needs a passphrase for an SSH key |
| Perl | `/usr/bin/perl` with its standard modules `IO::Socket::UNIX`, `JSON::PP`, `POSIX`, and `Fcntl` |
| Files | Write access to `~/.spooky/bin` in your home folder on the server, and to `/tmp` |
| Trash | Optional. On a Mac, Spooky uses `/usr/bin/trash`, which comes with macOS 15 and later. On Linux, it uses `gio` or `trash-put`. Without one, Spooky asks first, then deletes files for good. |

To see what a server provides before you add a repository, run the test in [Prepare SSH](/guide/server/prepare-ssh/#test). You can also check a server in :ui[app.name > settings.title] › :ui[settings.environment]. See [Check a server](/guide/settings/general/#server-check).

## Optional {#optional}

| To use | You need |
|---|---|
| Git LFS | Git LFS 2.9.0 or later, on the machine where the repository is, in the `PATH` that Git uses there |
| sshfs mounts | sshfs and macFUSE or FUSE-T on your Mac |
| SMB mounts | SMB file sharing on the server |
| Pull requests and merge requests | An account on github.com or GitLab.com, or on a self-managed GitLab 9.0 or later |

## See also

- [Install Spooky](/guide/start/install/)
- [How Server Repositories Work](/guide/server/overview/)
- [Data and Privacy](/reference/data-privacy/)
