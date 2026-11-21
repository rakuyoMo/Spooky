---
title: "Submodules"
description: "Open, update, fetch, initialize, synchronize, move, rename, and delete submodules."
---

A submodule is another Git repository inside a folder of your repository. Your repository records which commit of it to use. Spooky calls that record the submodule pointer.

## In the sidebar {#sidebar}

Submodules are listed under :ui[submodule.group] in the sidebar, by path. Hold the pointer over one to see its name and URL.

- A dimmed row is a submodule that isn’t checked out yet.
- A warning icon means its configuration is incomplete, or its URL needs synchronizing.
- A number is how many files have changed inside it.
- ↑ and ↓ show how far the checked-out commit is ahead of or behind the pointer.

Click a submodule to see its details. Double-click a checked-out submodule to open it as a repository in the same window. While it’s open, :ui[toolbar.parentRepository] in the toolbar takes you back.

Double-clicking a checked-out submodule in the Working Copy file list opens it the same way. To have that double-click open it like other files instead, turn off :ui[files.openSubmodules] in :ui[app.name > settings.title] › :ui[settings.general].

## Details {#details}

The details have three pages, chosen at the top:

- :ui[submodule.page.general]: the name, path, status, local changes, the checked-out commit, the pointer, and the settings in effect. If the submodule isn’t initialized, or its URL in `.gitmodules` has changed, a note at the top has a button to fix it.
- :ui[submodule.page.shared]: the settings in `.gitmodules`, which everyone who clones the repository gets. Changes here show up in the Working Copy, and you commit them like other changes.
- :ui[submodule.page.local]: the settings in this repository’s own configuration. They apply only here, and take precedence over `.gitmodules`.

On the two configuration pages, you can rename and move the submodule, change its URL, and set three options. :ui[submodule.useDefault] removes an option, so Git’s default applies.

- :ui[submodule.field.fetchMode]: whether fetching the parent repository also fetches this submodule. Choose :ui[submodule.fetchMode.always], :ui[submodule.fetchMode.onDemand] (only when fetched commits change its pointer, the default), or :ui[submodule.fetchMode.never].
- :ui[submodule.field.ignoreMode]: which changes in the submodule the parent’s Working Copy ignores. Choose :ui[submodule.ignoreMode.none] (the default), :ui[submodule.ignoreMode.untracked], :ui[submodule.ignoreMode.dirty] (only another checked-out commit counts), or :ui[submodule.ignoreMode.all].
- :ui[submodule.field.updateStrategy]: how updating brings the submodule to its pointer. Choose :ui[submodule.updateStrategy.checkout] (the default), :ui[submodule.updateStrategy.rebase] or :ui[submodule.updateStrategy.merge] onto its current branch, or :ui[submodule.updateStrategy.none].

## Add a submodule {#add}

1. Choose :ui[menu.repository > menu.addSubmodule] in the menu bar. You can also find it in the :ui[reference.addMenu] button at the bottom of the sidebar, or right-click :ui[submodule.group].
2. Enter the URL of the submodule’s repository.
3. For :ui[submodule.path], choose :ui[submodule.path.select] and pick an empty folder inside your repository.
4. Click :ui[submodule.add.submit].

If your repository already has a Git directory for a submodule by that name, for example from one you deleted, Spooky asks what to do. :ui[submodule.forceAdd.reuse] uses it again. :ui[submodule.forceAdd.overwrite] deletes it and clones again.

## Fetch and update {#update}

- **Fetch** downloads new commits from the submodule’s remote. It doesn’t change what’s checked out.
- **Update** checks out the commit the pointer records. A submodule that isn’t initialized gets initialized first.

Right-click a submodule and choose :ui[submodule.fetch.menu]{1="vendor/charts"} or :ui[submodule.update.menu]{1="vendor/charts"} from the menu. The :ui[menu.repository] menu has the same, plus items for all submodules at once.

The dialogs have these options:

- :ui[sync.prune] when fetching
- :ui[submodule.update.recursive] when updating. It updates submodules inside the submodule too. Their remotes must work with credentials that are already set up, because Spooky can’t ask you along the way.

Hold <kbd>⌥</kbd> in the right-click menu to get :ui[submodule.quickFetch]{1="vendor/charts"} and :ui[submodule.quickUpdate]{1="vendor/charts"}. They skip the dialog and use the options from last time. So do :ui[menu.fetchAllSubmodules] and :ui[menu.updateAllSubmodules] in the menu bar.

Update is available only when there’s something to do: the submodule isn’t checked out, or a different commit is checked out.

### Update after other operations {#auto-update}

Checking out, pulling, merging, and other operations can change the pointer of a checked-out submodule. Afterwards, Spooky asks whether to update those submodules. Select :ui[submodule.autoUpdate.always] to update them right away from then on. You can turn that back off with :ui[settings.autoUpdateSubmodules] in :ui[app.name > settings.title] › :ui[settings.general].

### Initialize and synchronize {#initialize}

- **Initialize** copies the submodule’s settings from `.gitmodules` into your repository’s configuration. Update it afterwards to check it out.
- **Synchronize** is for when the URL in `.gitmodules` has changed. It makes the URL in your repository’s configuration, and in the submodule’s own repository, match the new one.

Both are in the right-click menu, and in a note on the :ui[submodule.page.general] page when they’re needed.

## Check out another revision {#checkout}

Right-click a checked-out submodule and choose a branch or tag of the submodule from :ui[submodule.checkoutRevision]. The current one has a checkmark.

If changes inside the submodule are in the way, the checkout fails. Spooky doesn’t offer to stash them, because stashes in your repository don’t cover the submodule.

The pointer in your repository doesn’t move until you commit the submodule’s new commit.

## Move, rename, and delete {#manage}

All three are in the right-click menu:

- **Move** changes the submodule’s path. Select :ui[submodule.move.rename] to rename it to the new path as well.
- **Rename** changes its name, which is how `.gitmodules` and your configuration refer to it. The folder stays where it is.
- **Delete** removes the submodule from your repository. Select :ui[submodule.delete.keepWorkingTree] to remove only its configuration and keep its files. If it has changes inside, Spooky asks before deleting it anyway with :ui[submodule.forceDelete.submit].

These change `.gitmodules` and your repository’s index. Commit them so others get them too.

After a deletion, the submodule’s Git directory stays inside your repository’s `.git` folder, so adding it again can reuse it.

### Repair a submodule {#repair}

When a submodule’s configuration is incomplete, its details say :ui[submodule.invalid], with two buttons. :ui[submodule.repair.submit] restores what’s missing: the entry in `.gitmodules`, the pointer, or the checked-out repository. If Spooky can’t find the submodule’s URL anywhere, delete it and add it again.

## Undo {#undo}

You can undo adding, moving, renaming, and deleting a submodule, checking out another revision in it, and changing its URL or options. See [Undo and Recovery](/guide/work/undo/).

Initializing, synchronizing, and repairing can’t be undone. After one of them, operations before it can’t be undone anymore either.

Fetching and updating aren’t recorded, just like fetching and pulling in the repository. Operations before them can still be undone.

:::note[Server repositories]
All of this runs on the server. When you add a submodule, you pick its folder on the server.
:::

## See also

- [Fetch, Pull, and Push](/guide/branches/sync/)
- [Worktrees](/guide/advanced/worktrees/)
- [Undo and Recovery](/guide/work/undo/)
