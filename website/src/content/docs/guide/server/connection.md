---
title: "Connection Status and Reconnecting"
description: "Understand the connection status, password and passphrase prompts, disconnects and reconnecting, and what you can still see while disconnected."
---

A server repository depends on its SSH connection. This page explains how to tell whether it’s connected, what the questions from the server mean, and what happens when the connection drops.

## Connection status {#status}

In a server repository, a strip at the top of each list shows the host alias and the connection status. You’ll find it in the Working Copy, History, Stashes, Reflog, file history, and the file list of a commit.

| Status | What it means |
|---|---|
| :ui[connection.connecting] | Spooky is opening the connection. |
| :ui[connection.connected] | The connection works. |
| :ui[connection.reconnecting] | The connection dropped, and Spooky is trying again. |
| :ui[connection.unavailable] | The last attempt failed. Spooky tries again 5 seconds later. |

While the repository isn’t connected, the strip turns yellow and shows more:

- A note that Spooky is showing the last successful snapshot, and that writes are disabled until the connection recovers.
- The reason, such as :ui[remoteError.unavailable]. Click it to see the original output from SSH.
- A :ui[action.reconnect] button, while the status is :ui[connection.unavailable].

::screenshot[The top of the Working Copy for a server repository that lost its connection. A strip reads spooky-test: Unavailable, with a Reconnect button. Below it, a note says Spooky is showing the last successful snapshot and writes are disabled until the connection recovers. A collapsed line reads Server Connection Unavailable.]{name="server-unavailable" frame="closeup"}

## Password and passphrase prompts {#prompts}

Spooky logs in to the server without asking anything. Git on the server sometimes needs an answer, though, for example a password when you push to a remote over HTTPS. Spooky passes the question to your Mac and shows it in a dialog:

| Dialog | When it appears |
|---|---|
| :ui[callback.username.title], :ui[callback.password.title] | A remote asks who you are. This usually happens with remotes reached over HTTPS. |
| :ui[callback.privateKey.title] | The SSH key that the server uses for a remote is protected with a passphrase. |
| :ui[signing.unlock] | Git needs the passphrase of the signing key on the server to sign a commit or tag. |
| :ui[callback.editor] | Git wants you to edit some text, such as a message. |

The first line of the dialog names the server. A private key dialog also shows the key’s path on the server.

For a user name or password, select :ui[callback.saveKeychain] to keep the answer. The next time Git on that server asks, Spooky answers from Keychain. If you’ve added a GitHub or GitLab account, Spooky answers with that account first. See [Hosting Accounts](/guide/hosting/accounts/).

A few things to know:

- Each dialog waits 2 minutes. If you don’t answer in time, Git gets no answer, and the command fails.
- Automatic fetch never asks. It only uses accounts and answers saved in Keychain. If those aren’t enough, it’s cancelled.
- Passphrase dialogs for Git on the server need OpenSSH 8.4 or later on the server.

## Disconnects and reconnecting {#reconnect}

When the connection drops, Spooky reconnects on its own. After each failed attempt, the status shows :ui[connection.unavailable], and Spooky tries again 5 seconds later. Once it’s back, Spooky reloads the repository.

Changes you made don’t get repeated after a disconnect:

- Operations waiting in the repository’s queue are cancelled. They don’t run after reconnecting. Start them again if you still need them.
- An operation that was running when the connection dropped isn’t retried. After reconnecting, Spooky checks the branch, the number of changes, the index lock, and whether a merge or rebase is in progress.

That check shows up in the :ui[recovery.title] dialog. It tells you whether the operation started at all and whether the current commit moved. Look at the result before you try the operation again.

## While disconnected {#offline}

You can keep looking at what Spooky read last: the lists, the selected file, and its changes. Anything that changes the repository is unavailable until the connection is back.

If the server can’t be reached when you open a repository, the window shows :ui[missing.unreachable.title]{1="driftwood-server"} with the output from SSH. Click :ui[action.refresh] to try again, or :ui[action.close] to go back to the Repositories window.

:::tip
Run `ssh -o BatchMode=yes driftwood-server git --version` in Terminal, with your own host alias. If it fails, the problem is between your Mac and the server, not in Spooky. See [Test the way Spooky connects](/guide/server/prepare-ssh/#test).
:::

## See also

- [Prepare SSH](/guide/server/prepare-ssh/)
- [Add Server Repository](/guide/server/add/)
- [How Server Repositories Work](/guide/server/overview/)
