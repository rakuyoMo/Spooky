---
title: "Prepare SSH"
description: "Set up an SSH key and a host alias in ~/.ssh/config, and make sure you can connect from Terminal before adding a server repository."
---

Spooky logs in to a server with SSH, the same way Terminal does. It can’t type a password for you, so it needs an SSH key. This page sets up a key and a short name for the server, then checks that Terminal connects without asking anything. Once that works, Spooky can connect too.

If `ssh` already logs you in to the server without a password, skip to [Test the way Spooky connects](#test).

## What you need {#before}

- An account on the server that you can log in to with SSH. Ask the server’s owner if you’re not sure.
- Git 2.41.0 or later on the server.
- The **Terminal** app on your Mac.

The commands on this page go into Terminal. Type or paste each one, then press Return.

## Check for a key {#key-check}

An SSH key is a pair of files. The private key stays on your Mac. The public key ends in `.pub` and goes on the server.

```sh
ls ~/.ssh
```

If the list has `id_ed25519` and `id_ed25519.pub`, you already have a key. Skip to [Add a host alias](#alias). Another pair, such as `id_rsa` and `id_rsa.pub`, works too. Use its name instead of `id_ed25519` in the steps below.

If you see “No such file or directory”, or there’s no key pair in the list, create one.

## Create a key {#create-key}

```sh
ssh-keygen -t ed25519 -C "alex@example.com"
```

Put your own email address in the quotes. It’s only a label that helps you recognize the key.

1. When asked where to save the key, press Return to keep the suggested place.
2. Enter a passphrase, then enter it again. Nothing shows while you type. The passphrase protects the key if someone copies the file.

When it’s done, `~/.ssh` has `id_ed25519` and `id_ed25519.pub`.

## Add a host alias {#alias}

A host alias is a short name for a server. You type it in Terminal and in Spooky, in place of the server’s address and your username. Aliases are saved in the file `~/.ssh/config`. You add them in Spooky’s settings.

1. Choose :ui[app.name > settings.title] › :ui[settings.sshHosts].
2. Click the add button below the list.
3. Fill in the fields with your own details.
4. Click :ui[sshHosts.create.submit].

::screenshot[The Add Host Alias dialog. Alias is driftwood-server, Server address is 203.0.113.10, User name is alex, Port is empty, and Private key is ~/.ssh/id_ed25519. The buttons are Cancel and Add.]{name="settings-ssh-hosts-add" frame="dialog"}

| Field | What to put there |
|---|---|
| :ui[sshHosts.alias] | The alias. Use one word without spaces, `@`, `:`, `/`, `*`, or `?`, and don’t start it with `-` or `!`. |
| :ui[sshHosts.hostName] | The server’s address or name, such as `203.0.113.10` or `server.example.com` |
| :ui[sshHosts.user] | Your username on the server |
| :ui[sshHosts.port] | The port, if SSH on the server uses one other than 22 |
| :ui[sshHosts.identityFile] | The private key you created or found above, such as `~/.ssh/id_ed25519` |

Only :ui[sshHosts.alias] is required. Spooky writes the alias and the fields you filled in to `~/.ssh/config`:

```
Host driftwood-server
    HostName 203.0.113.10
    User alex
    IdentityFile ~/.ssh/id_ed25519
```

If the file has an entry with a pattern, such as `Host *`, or a `Match` entry, the new lines go above the first of them, so it can’t override them. Otherwise, they go at the end of the file.

### Change or delete an alias {#manage-aliases}

The :ui[settings.sshHosts] page lists the aliases in `~/.ssh/config`, including ones you added in a text editor.

::screenshot[The SSH Hosts page of the Settings window. The list has the columns Alias, Server Address, User Name, Port, and Private Key. It shows three aliases: staging, backup-nas, and driftwood-server, which is selected. Below the list are the add and remove buttons, and an Edit button on the right.]{name="settings-ssh-hosts" frame="window"}

- To change an alias, double-click it, or select it and click :ui[sshHosts.edit] or press <kbd>Return</kbd>. Spooky changes only the lines of the fields you edit. The server’s other SSH options, other servers, and comments stay as they are.
- To delete an alias, select it, click the remove button below the list, and confirm. Spooky deletes its `Host` line and the options under it.

An entry with several names or with a pattern, such as `Host *`, isn’t in the list, and Spooky doesn’t change it. Edit those in a text editor.

Spooky reads the file again each time you come back to the app. If another app changes the file while a dialog is open, Spooky doesn’t save your change. The list shows the file’s current content, and you make the change again.

## Let your Mac unlock the key {#keychain}

Spooky never asks for the passphrase of your key when it logs in, so your Mac has to unlock the key for it. Two lines in `~/.ssh/config` set that up for every server. Skip this step if your key has no passphrase.

1. Open the file in TextEdit:

   ```sh
   open -e ~/.ssh/config
   ```

2. Add these lines at the end:

   ```
   Host *
       AddKeysToAgent yes
       UseKeychain yes
   ```

3. Save the file and close TextEdit.

The first time you type the passphrase, your Mac saves it in Keychain. After that, SSH unlocks the key without asking.

## Connect once {#fingerprint}

The first time you connect to a server, SSH asks you to confirm the server’s fingerprint. Spooky never accepts a fingerprint for you, so do this in Terminal first.

```sh
ssh driftwood-server
```

1. SSH shows the server’s fingerprint, a line that starts with `SHA256:`, and asks whether to continue.
2. Compare it with the fingerprint the server’s owner gives you. On the server, this command prints it:

   ```sh
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```

3. If they match, type `yes` and press Return. Your Mac remembers the server and won’t ask again.

What happens next depends on the server:

- If SSH asks for the passphrase of your key, enter it. Your Mac saves it in Keychain.
- If you’re logged in, your key is already on the server. Type `exit`, then skip to [Test the way Spooky connects](#test).
- If SSH asks for your password on the server, press <kbd>⌃C</kbd> for now. The next step puts your key on the server.

:::caution
If SSH warns that the remote host identification has changed, don’t continue. Ask the server’s owner whether the server was reinstalled or replaced.
:::

## Put the public key on the server {#copy-key}

If you can log in to the server with a password, this command copies your public key there. Enter your password on the server when asked.

```sh
ssh-copy-id -i ~/.ssh/id_ed25519.pub driftwood-server
```

If the server doesn’t take passwords, send your public key to the server’s owner instead. This command copies it to the clipboard:

```sh
pbcopy < ~/.ssh/id_ed25519.pub
```

Ask them to add it to `~/.ssh/authorized_keys` in your home folder on the server. The public key is safe to share. Never send the file without `.pub`.

## Test the way Spooky connects {#test}

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

This logs in the same way Spooky does, without asking for anything. It works if it prints a version of 2.41.0 or later right away, such as `git version 2.47.1`. You’re ready to [add the server repository](/guide/server/add/).

If it prints something else:

| What you see | What to do |
|---|---|
| `Permission denied` | The server doesn’t accept your key yet, or your Mac can’t unlock it. Check [Let your Mac unlock the key](#keychain), [Put the public key on the server](#copy-key), and [After restarting your Mac](#after-restart). |
| `Host key verification failed` | Your Mac doesn’t know the server yet. See [Connect once](#fingerprint). |
| `Could not resolve hostname`, `Connection refused`, or `Operation timed out` | Check the alias’s :ui[sshHosts.hostName] and :ui[sshHosts.port] in :ui[app.name > settings.title] › :ui[settings.sshHosts], and make sure the server is on and reachable. |
| A message with `command not found` | Git isn’t installed on the server, or SSH logins can’t find it. Ask the server’s owner. |
| A version older than 2.41.0 | Ask the server’s owner to update Git. |

## After restarting your Mac {#after-restart}

If the test worked before but fails with `Permission denied` after a restart, load your key again. Keys whose passphrase is saved in Keychain load with:

```sh
ssh-add --apple-load-keychain
```

## Use another SSH agent {#agent}

An SSH agent keeps unlocked keys ready for SSH. Spooky uses the system agent, the one macOS starts for you. If your keys are in another agent, for example one that comes with a password manager, set `SSH_AUTH_SOCK` to that agent’s socket. Add it as a custom variable in :ui[app.name > settings.title] › :ui[settings.environment], or set it in your login shell. Spooky then uses that agent to log in to servers. See [SSH agent](/guide/settings/integration/#ssh-agent).

## Use a Mac as the server {#mac-server}

Another Mac can be the server. On that Mac:

1. Choose **Apple menu › System Settings**, click **General**, then click **Sharing**.
2. Turn on **Remote Login**.
3. If the repository is in a protected folder, such as Documents or Desktop, click the info button next to **Remote Login** and turn on **Allow full disk access for remote users**.

Then go through this page from your own Mac, with that Mac’s address in :ui[sshHosts.hostName].

## See also

- [How Server Repositories Work](/guide/server/overview/)
- [Add Server Repository](/guide/server/add/)
- [System Requirements](/reference/requirements/#servers)
