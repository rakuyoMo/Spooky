---
title: "Stashes"
description: "Save, apply, and inspect stashes, and use automatic stashing."
---

A stash puts your local changes aside without committing them. Use it when you need a clean Working Copy for a moment, for example to switch branches or pull, and want your changes back afterwards.

Stashes belong to the repository. They aren’t pushed to the remote.

## Save a stash {#save}

1. Choose :ui[workspace.title > stash.saveMenu] (<kbd>⇧⌘S</kbd>), or click :ui[toolbar.saveStash] in the toolbar.
2. Optionally, describe the changes in :ui[stash.message] so you can find the stash later.
3. To put new files aside too, select :ui[stash.includeUntracked]. Spooky remembers this choice.
4. Click :ui[stash.save].

All your changes go on the stash, and the Working Copy is clean again. If there’s nothing to save, Spooky says :ui[stash.error.noChanges]. New files count only when :ui[stash.includeUntracked] is selected.

To save a copy of your changes but keep working on them, choose :ui[workspace.title > stash.snapshotMenu] (<kbd>⌃⇧⌘S</kbd>) instead. The dialog is the same, and the Working Copy stays as it is.

## Stash some files {#partial}

To put only some files aside, select them in the Working Copy, right-click, and choose :ui[stash.stashFile]{1="README.md"} or :ui[stash.stashItems]{1="3"} from the menu. The snapshot items below them keep the files as they are.

You can also drag the files onto :ui[stash.title] in the sidebar.

New files you selected always go on the stash, whether or not :ui[stash.includeUntracked] is selected.

:::tip
Hold <kbd>⌥</kbd> while the menu is open, and the items turn into quick versions such as :ui[stash.quickStashFile]{1="README.md"}. They save right away, without the dialog, with a message that Git writes.
:::

## View stashes {#view}

Click :ui[stash.title] in the sidebar, or choose :ui[menu.view > stash.show] (<kbd>⌘3</kbd>).

The list on the left shows the newest stash first. Each row shows :ui[stash.basedOn] with the branch the stash was saved from, the date, and the message. To filter the list, type in the search field in the toolbar.

::screenshot[The stashes view. The list on the left shows three stashes, and Halfway through the units toggle is selected. Its details are on the right, with the Apply, Delete, and Difftool buttons showing below the commit info.]{name="work-stashes" frame="window" markers="33,36 84,35.5"}

1. The list of stashes
2. :ui[stash.applyButton], :ui[stash.deleteButton], and :ui[history.diffTool]

Select a stash to see its changes on the right, laid out like the details of a commit. Hold the pointer over the details to show the :ui[stash.applyButton], :ui[stash.deleteButton], and :ui[history.diffTool] buttons. :ui[history.diffTool] opens the stash in a diff app.

## Apply a stash {#apply}

Applying brings the changes of a stash back into the Working Copy.

1. Choose :ui[workspace.title > stash.applyMenu] (<kbd>⌥⇧⌘S</kbd>), or click :ui[toolbar.applyStash] in the toolbar. You can also drag a stash onto :ui[workspace.title] or the current branch in the sidebar.
2. Choose the stash in :ui[stash.picker]. In the stashes view, the selected stash is already chosen.
3. Set the options:
   - :ui[stash.deleteAfterApply] removes the stash once its changes are back.
   - :ui[stash.restoreIndex] stages again what was staged when you saved the stash.
4. Click :ui[stash.apply].

Spooky remembers both options for next time.

If the changes collide with what’s in the Working Copy now, Spooky reports :ui[stash.error.conflicts]. The stash is kept, even with :ui[stash.deleteAfterApply] selected. Resolve the conflicts as described in [Resolve Conflicts](/guide/work/conflicts/).

To bring back a single file, open the stash and drag the file from its details onto :ui[workspace.title] in the sidebar.

## Delete stashes {#delete}

In the stashes view, right-click a stash and choose :ui[stash.deleteNamed]{1="Halfway through the units toggle"} from the menu. If several stashes are selected, the item is :ui[stash.deleteMultiple]{1="2"} instead. You can also press <kbd>⌘⌫</kbd>.

Spooky always asks first. To get a stash back after deleting it, choose :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

## Auto stash {#auto-stash}

Some operations can’t run while you have local changes, such as switching branches, pulling, or merging. When one of them is blocked, Spooky asks whether to stash your changes first.

::screenshot[A dialog asking whether to stash the local changes that block the operation. It has a field for an optional message, a Re-Apply Changes After Operation is Finished checkbox, and the Abort, Do Not Stash, and Stash Changes buttons.]{name="work-auto-stash" frame="dialog"}

- :ui[stash.autoStash.confirm] stashes the changes and runs the operation.
- :ui[stash.autoStash.skip] runs the operation without stashing. If your changes still block it, it fails as it would have.
- :ui[stash.autoStash.abort] cancels the operation.

Select :ui[stash.autoStash.reapply] to get the changes back as soon as the operation is done. Otherwise the stash stays in the list, and you can apply it yourself later. Spooky remembers this choice.

When you switch branches with changes to tracked files, Spooky asks before it starts, even if the changes wouldn’t get in the way.

If anything goes wrong along the way, your changes stay on the stash, and Spooky tells you what happened.

To stop being asked, turn off :ui[stash.offerAutoStash] in :ui[app.name > settings.title] › :ui[settings.general].

## See also

- [Working Copy](/guide/work/working-copy/)
- [Resolve Conflicts](/guide/work/conflicts/)
- [Branches](/guide/branches/branches/)
