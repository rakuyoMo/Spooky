---
title: "Location on This Mac"
description: "Give a server repository a location on this Mac through automatic lookup, an SMB or sshfs mount, or a folder you choose, so that Show in Finder, Terminal, and external editors can open it."
---

Finder can only show folders on your Mac. A server repository’s files are on the server. To show them in Finder, Spooky needs a folder on this Mac where the server’s files appear, usually a mounted network volume. That folder is the repository’s location on this Mac.

This page covers how Spooky finds or mounts that folder, and how Terminal and other apps open a server repository.

## Show in Finder {#show-in-finder}

:ui[action.revealFinder] is always available in a server repository. You’ll find it in these places:

- The :ui[menu.file] menu
- :ui[toolbar.finder] in the toolbar. To add it, choose :ui[menu.view > menu.customizeToolbar] and drag it into the toolbar.
- The :ui[workspace.title] row in the sidebar, when you Control-click it
- [Quick Actions](/guide/repositories/navigation/#quick-actions)
- The Repositories window, when you Control-click a server repository
- Files in the Working Copy, when you Control-click them. Finder selects those files.

If the location is known and the folder is there, Finder opens right away. Otherwise, Spooky shows a sheet and works through these steps:

1. If the repository isn’t connected, Spooky connects first.
2. It looks for the folder, and mounts it if the method is SMB or sshfs.
3. If it still can’t find the folder, the sheet turns into the form for setting the location, with the reason at the top. See [Set the location](#set).

Click :ui[action.cancel] to close the sheet. Your settings stay the same.

## Set the location {#set}

1. In the sidebar, under :ui[workspace.group], click :ui[repositorySettings.title].
2. On the :ui[repositorySettings.general] page, find :ui[repositorySettings.localLocation]. It shows the method and the folder, or why there’s no folder, such as :ui[localLocation.notMounted].
3. Move the pointer over the row, then click :ui[localLocation.change] when it appears. The repository has to be connected.
4. In :ui[localLocation.title], choose a method next to :ui[localLocation.method].
5. Click :ui[localLocation.mount] for a mount, or :ui[localLocation.save] for the other methods.

While Spooky mounts or checks the folder, the form is locked. Click :ui[action.cancel] to stop. Your earlier setting stays.

The location is saved on this Mac for each server repository. Spooky doesn’t write it to the repository or the server.

If an SMB or sshfs mount has been ejected, the row shows :ui[localLocation.mountAgain]. Click it to mount the folder again.

## Methods {#methods}

The :ui[localLocation.method] menu lists only the methods that work right now. The current method is always listed.

### Automatic {#automatic}

:ui[localLocation.method.automatic] is the default. Spooky looks through the network volumes already mounted on this Mac, such as SMB, NFS, AFP, WebDAV, and sshfs volumes. It doesn’t matter which app mounted them. A volume counts if its server has the same address as your host alias.

Spooky then looks for the repository folder inside the volume. To make sure it’s the same repository, Spooky briefly puts an empty file in the repository’s Git folder on the server, checks that it shows up on the volume, and deletes it.

### SMB Mount {#smb}

:ui[localLocation.method.smbMount] mounts a shared folder from the server with SMB, the file sharing protocol that macOS uses. It’s listed when the server answers on the SMB port within 2 seconds.

1. Choose :ui[localLocation.method.smbMount], then click :ui[localLocation.mount].
2. macOS shows the server’s shared folders, or asks you to log in first. Choose the share that contains the repository.

Spooky remembers the share and mounts it again next time without asking. If the repository isn’t in the share you chose, the form shows :ui[localLocation.notInShare] Choose another share and try again.

If the server is a Mac, turn on **File Sharing** in **Apple menu › System Settings › General › Sharing** on that Mac.

### sshfs Mount {#sshfs}

:ui[localLocation.method.sshfsMount] mounts the repository folder over SSH, with the same host alias Spooky uses. It needs sshfs and macFUSE or FUSE-T on this Mac. Spooky looks for `sshfs` in `/opt/homebrew/bin`, `/usr/local/bin`, and your `PATH`. If it isn’t installed, this method isn’t listed.

1. Choose :ui[localLocation.method.sshfsMount].
2. Next to :ui[localLocation.mountAt], click :ui[localLocation.choose] and pick an empty folder on this Mac. The server’s files appear there.
3. Click :ui[localLocation.mount].

### Chosen Folder {#chosen-folder}

:ui[localLocation.method.chosenFolder] lets you pick the folder yourself, for example one you’ve mounted in another way.

1. Choose :ui[localLocation.method.chosenFolder].
2. Next to :ui[localLocation.folder], click :ui[localLocation.choose] and pick the repository folder.
3. Click :ui[localLocation.save]. Spooky checks the folder before it saves.

Spooky never ejects a volume it mounted. When you open the repository again later, Spooky mounts it again in the background, without asking anything.

## Mount while adding {#when-adding}

When you [add a server repository](/guide/server/add/), :ui[remote.mount] sets up the location in the same step. It starts at :ui[remote.mount.none]. Once you fill in the host alias, the menu lists :ui[remote.mount.smb] and :ui[remote.mount.sshfs] if they’re available. If neither is, it shows :ui[remote.mount.unavailable].

- **SMB:** After the repository opens, macOS shows the server’s shared folders or a login window. If you cancel, the repository still opens, and :ui[repositorySettings.localLocation] in its settings shows why it isn’t mounted.
- **sshfs:** An extra :ui[localLocation.mountAt] row appears. Pick an empty folder. Spooky mounts the repository there after it opens.

If you change the host alias, the menu goes back to :ui[remote.mount.none].

## Terminal and other apps {#terminal}

These commands work in a server repository without a location on this Mac:

- **:ui[action.openTerminal]** opens the terminal app chosen in :ui[app.name > settings.title] › :ui[settings.general], logs in with `ssh -t` and the host alias, and goes to the repository folder. If the server doesn’t allow a terminal, Spooky connects again without one. Commands still work, but line editing and full-screen programs don’t. You’ll find it in the :ui[menu.file] menu, as :ui[toolbar.terminal] in the toolbar, and when you Control-click the Working Copy or a repository in the Repositories window.
- **:ui[action.copyPath]** copies the path with the host alias in front, such as `driftwood-server:/srv/git/driftwood`.
- **:ui[files.open] and :ui[files.openWith]** in the Working Copy open a file in another app. Visual Studio Code, Visual Studio Code Insiders, and Cursor open the file on the server directly, if a Remote SSH extension is installed. Other apps get a copy on this Mac. When you save, Spooky writes the copy back to the server.

If the file on the server changed in the meantime, Spooky asks before writing: :ui[externalTool.fileChanged]. Click :ui[externalTool.overwrite] to replace it with your copy. Spooky deletes the copies when you close the repository.

Quick Look and external diff and merge tools also work on copies. After a merge tool finishes, Spooky writes the result back to the server and stages it.

## See also

- [How Server Repositories Work](/guide/server/overview/)
- [Add Server Repository](/guide/server/add/)
- [Integration](/guide/settings/integration/)
