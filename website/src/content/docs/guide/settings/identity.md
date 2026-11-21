---
title: "User Profiles and Git Config"
description: "Manage user profiles and Git config, and adjust the settings of a single repository."
---

Git records a name and email with every commit, and can sign it with a key. Spooky gives you three places to set these up:

- :ui[settings.profiles] in :ui[app.name > settings.title] keeps identities you switch between.
- :ui[settings.gitConfig] in :ui[app.name > settings.title] sets the Git program and your global identity and signing.
- The settings of a single repository override the global ones for that repository.

## User profiles {#profiles}

A user profile is a name, an email, and an optional signing key, saved under a title such as “Work”. Spooky keeps profiles on this Mac. You can use them in both local and server repositories.

To add a profile:

1. Choose :ui[app.name > settings.title] › :ui[settings.profiles].
2. Click the add button below the list.
3. Fill in the :ui[profiles.title], :ui[profiles.userName], and :ui[profiles.email] fields. Optionally choose a :ui[profiles.signingKey] from the keys found on this Mac.
4. Click :ui[profiles.create.submit].

Title, user name, and email are required. Two profiles can’t share a title, or share both a user name and an email.

To change a profile, select it and click :ui[profiles.edit]. To delete one, select it and click the remove button. Deleting a profile doesn’t change any Git settings.

If the identity you use now isn’t a profile yet, choose :ui[profiles.addCurrent]{1="alex@example.com"} from its menu. Enter a title, and click :ui[profiles.add.submit].

### Use a profile {#use-profile}

Click the picture next to an identity to see your profiles, with a checkmark next to the one in use. What choosing a profile changes depends on where you choose it:

| Where | What it changes | Asks first |
|---|---|---|
| The commit area, or :ui[bookmarks.detail.identity] in [repository settings](#repository) | This repository’s own Git settings. See [Choose who commits](/guide/work/commit/#identity). | Yes |
| :ui[settings.gitConfig] in Settings | Your global Git settings on this Mac | No |

The profile’s name and email are written to `user.name` and `user.email`. A profile with a signing key also sets `user.signingkey` and `gpg.format`.

[Quick Actions](/guide/repositories/navigation/#quick-actions) list your profiles too. :ui[quickActions.setCommitter] works like the commit area. :ui[quickActions.setGlobalUser] sets the name and email in your global Git settings on the machine where the repository is, after asking.

:::note[Server repositories]
Choosing a profile for a server repository changes the repository’s settings on the server. Other tools that commit there use the same identity. :ui[quickActions.setGlobalUser] in a server repository writes to your global settings on the server.
:::

## Git Config {#git-config}

The :ui[settings.gitConfig] page has four parts: the Git program, your identity, signing, and external tools. The tools are described in [Integration](/guide/settings/integration/#diff-merge-tools).

::screenshot[The Git Config page of the Settings window, with the Git binary, the global name and email, the signing settings, and the diff and merge tools.]{name="settings-git-config" frame="window" markers="20,16.7 20,29.4 20,46 20,83.4"}

1. The Git program
2. Your identity
3. Signing
4. External tools

### Git program {#git-program}

:ui[settings.gitProgram] lists the Git programs on this Mac that are new enough, with their versions. Spooky looks in the usual places: `/usr/bin/git` (marked as the system one, and used at first), Command Line Tools, Xcode, Homebrew, and MacPorts.

To use a Git that isn’t listed, choose :ui[settings.gitProgram.choose] and select the program. If the file isn’t Git, or its version is too old, Spooky tells you why and keeps the one you had. The line below the menu shows the lowest version Spooky accepts.

:::note[Server repositories]
This setting applies only to local repositories. Server repositories use the Git on the server. See [System Requirements](/reference/requirements/#servers).
:::

### Global identity {#global-identity}

:ui[gitConfig.userName] and :ui[gitConfig.email] are Git’s global `user.name` and `user.email`. Every repository on this Mac uses them, unless it has its own.

Changes are saved when you press <kbd>Return</kbd> or leave the field. Clearing a field removes the setting. The line below shows which file they’re saved in, usually `~/.gitconfig`.

Click the picture to the right to choose a [profile](#use-profile) or manage them.

### Signing {#signing}

These settings decide how Git signs commits in every repository on this Mac that doesn’t set its own.

| Setting | What it does |
|---|---|
| :ui[gitConfig.sshProgram] | The program that signs with SSH keys. :ui[gitConfig.sshProgram.system] is used at first. If 1Password is installed, its signing program is listed too. |
| :ui[gitConfig.gpgProgram] | The GnuPG program for OpenPGP keys. Lists the versions on this Mac that are new enough. Choose :ui[gitConfig.gpgProgram.select] to pick another one. |
| :ui[gitConfig.signingKey] | The key to sign with: a secret key in your GnuPG keyring, or a key loaded in the SSH agent. Choosing a key also tells Git whether to sign with OpenPGP or SSH. |
| :ui[gitConfig.allowedSigners] | The file of SSH keys whose signatures you trust, used when Git checks signatures. Choose `~/.ssh/allowed_signers`, pick another file, or choose :ui[gitConfig.allowedSigners.none]. |
| :ui[gitConfig.signCommits] | Signs every commit |
| :ui[gitConfig.ensureEmailMatch] | Warns when the email of the OpenPGP key isn’t your global email. On at first. |

When something needs your attention, such as a signing program that can’t run, a yellow warning button shows up next to the setting. Click it to see what’s wrong.

Signed commits and the passphrase prompt are described in [Sign commits](/guide/work/commit/#signing).

## Repository settings {#repository}

Each repository has its own settings. To see them, click :ui[repositorySettings.title] under :ui[workspace.group] in the sidebar. The buttons at the top switch between four sections.

Changes are written to the repository’s own Git settings, and wait in line with the repository’s other operations. Anything a repository doesn’t set comes from your global settings.

::screenshot[Repository settings in the main window, on the General tab, with the repository’s name, path, description, identity, and signing settings.]{name="settings-repository" frame="window" markers="73,9.8 60,38.8"}

1. The buttons that switch sections
2. :ui[bookmarks.detail.identity]

### General {#repository-general}

| Item | What it shows |
|---|---|
| :ui[repositorySettings.name] and :ui[repositorySettings.path] | Where the repository is |
| :ui[repositorySettings.localLocation] | For server repositories, where the repository’s folder is on this Mac. See [Set the location](/guide/server/local-location/#set). |
| :ui[bookmarks.detail.description] | A description of the repository, also shown in [the Repositories window](/guide/repositories/manager/). Click :ui[bookmarks.detail.edit] to change it. |
| :ui[bookmarks.detail.identity] | The name and email this repository commits with. Click the picture to use a [profile](#use-profile), or :ui[bookmarks.detail.edit] to type a name and email for this repository only. |

Under :ui[repositorySettings.signing], :ui[repositorySettings.signCommits], :ui[repositorySettings.signingKey], and :ui[repositorySettings.allowedSigners] work like the [global ones](#signing), for this repository only.

### Git LFS, Ignores, and Excludes {#repository-files}

- :ui[repositorySettings.lfs] shows the Git LFS version and the :ui[repositorySettings.lfs.patterns]. See [Git LFS](/guide/advanced/lfs/).
- :ui[repositorySettings.ignores] lists the rules in the `.gitignore` at the top of the repository. Commit this file to share the rules with others.
- :ui[repositorySettings.excludes] lists the rules in Git’s `info/exclude`. They apply only to this copy of the repository.

Click :ui[repositorySettings.openInEditor] to change the rules. The file opens in the app your Mac uses for it. If the file doesn’t exist yet, Spooky creates it first.

:::note[Server repositories]
The settings are read and written on the server. You can change them only while the repository is connected. :ui[repositorySettings.openInEditor] opens the file the same way the Working Copy opens files on the server. See [Terminal and other apps](/guide/server/local-location/#terminal).
:::

## See also

- [Commit Changes](/guide/work/commit/)
- [General, Updates, and Environment](/guide/settings/general/)
- [Integration](/guide/settings/integration/)
- [System Requirements](/reference/requirements/)
