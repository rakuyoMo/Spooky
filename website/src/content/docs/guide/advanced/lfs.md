---
title: "Git LFS"
description: "Enable Git LFS, track files and patterns, and fetch, pull, and push LFS content."
---

Git LFS keeps large files out of the repository’s history. The repository stores a small pointer file for each one, and the content goes to an LFS store on the remote.

Spooky runs Git LFS on the machine where the repository is.

## What you need {#requirements}

Git LFS 2.9.0 or later, in the `PATH` that Git uses on the machine where the repository is.

To check, click :ui[repositorySettings.title] under :ui[workspace.group] in the sidebar. The :ui[repositorySettings.lfs] section shows the :ui[lfs.version] of Git LFS. If Git LFS isn’t found or is too old, a note there says how to fix it:

- **On your Mac**: install or update Git LFS. If it’s installed but not found, open :ui[app.name > settings.title] › :ui[settings.environment]. Select :ui[settings.environment.loginShell], or add `PATH` as a custom variable.
- **On a server**: install or update Git LFS there, and add its folder to the `PATH` of non-interactive SSH sessions, for example in `~/.zshenv`.

While Git LFS is missing, the buttons in that section that need it aren’t available.

## Turn on Git LFS {#enable}

In the :ui[repositorySettings.lfs] section of the repository’s settings, click :ui[lfs.enable]. This sets up Git LFS for this repository only, and doesn’t change your global Git configuration.

Spooky treats a repository as using Git LFS when Git has the Git LFS filters set up and the repository has the Git LFS hooks. Until then, the section offers only :ui[lfs.enable], and the LFS menu items aren’t available.

When you clone a repository that uses Git LFS, select :ui[clone.lfs]. See [Clone a repository](/guide/repositories/manager/#clone).

After you update Git LFS, choose :ui[menu.repository > lfs.menu > lfs.menu.update] in the menu bar to update the repository’s Git LFS hooks.

## Track files {#track}

Files that match a tracking pattern are stored with Git LFS. Patterns go into `.gitattributes` at the repository root, so everyone who uses the repository gets them. The change to `.gitattributes` shows up in the Working Copy. Commit it like other changes.

To add a pattern, click :ui[lfs.createPattern] in the repository’s settings, or choose :ui[menu.repository > lfs.menu > lfs.menu.track] in the menu bar. Enter a pattern such as `*.psd`, then click :ui[files.pattern.save].

You can also right-click files in the Working Copy and choose from :ui[lfs.menu]:

- :ui[lfs.trackFile]: track just the selected files, with their exact paths. With several files, it says how many.
- :ui[lfs.trackType.single]{1="psd"}: track all files with the same extension. With several files, it’s :ui[lfs.trackType], and covers each of their extensions.
- :ui[lfs.createPattern.menu]: enter a pattern yourself, starting from the path of the first selected file.

For a folder, only :ui[lfs.createPattern.menu] is available.

### Stop tracking a pattern {#untrack}

In the repository’s settings, click :ui[lfs.remove] next to a pattern, and confirm. The pattern comes out of `.gitattributes`. Files already stored with Git LFS stay as they are.

If Git LFS can’t remove a pattern, Spooky says which ones are left. Remove them by hand with :ui[repositorySettings.openInEditor] next to :ui[repositorySettings.lfs.patterns].

## Fetch, pull, and push LFS content {#transfer}

With Git LFS set up, Git normally downloads LFS content as it checks out files, and uploads it as you push. To do it yourself, choose from :ui[menu.repository > lfs.menu] in the menu bar:

| Item | What it does |
|---|---|
| :ui[lfs.menu.fetch] | Downloads the LFS content the current checkout needs. The Working Copy doesn’t change. |
| :ui[lfs.menu.pull] | Downloads it, and replaces the pointer files in the Working Copy with the content. |
| :ui[lfs.menu.push] | Uploads the LFS content used by all local branches and tags that the remote doesn’t have yet. |

Choose a remote in the dialog. It starts as the remote of the current branch’s upstream, or the first remote if there’s no upstream. Progress shows up in the [activity area](/guide/advanced/queue-activity/#activity-area) at the bottom of the sidebar.

## Undo {#undo}

You can undo turning on Git LFS, adding a tracking pattern, and removing one. See [Undo and Recovery](/guide/work/undo/).

Updating the hooks can’t be undone, and operations before it can’t be undone anymore either.

Fetching, pulling, and pushing LFS content aren’t recorded, just like fetching, pulling, and pushing in the repository. Operations before them can still be undone.

:::note[Server repositories]
Git LFS runs on the server, and LFS content goes between the server and the remote. Your Mac doesn’t need Git LFS for a server repository.
:::

## See also

- [System Requirements](/reference/requirements/#optional)
- [Submodules](/guide/advanced/submodules/)
- [The Repositories Window](/guide/repositories/manager/)
