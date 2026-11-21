---
title: "Resolve Conflicts"
description: "Resolve conflicts from a merge, rebase, or other operation in progress with the conflict wizard or an external merge tool, then continue or abort."
---

A conflict happens when both sides changed the same part of a file, and Git can’t tell which change to keep. A merge, rebase, cherry-pick, or revert stops at that point, and so does applying a stash. You decide what goes into each file, then finish the operation.

::screenshot[The Working Copy during a merge of “feature/units-toggle” into “main”. A yellow banner at the top of the middle column says 1 unresolved conflict, 0 resolved, and has an Abort button. In the file list, src/units.ts is marked as conflicted. On the right, two cards show the version of units.ts from each branch, with arrows pointing down to an empty result box and a Choose Merge Tool button.]{name="conflict" frame="window" markers="24,18 47,55 76,37 76,73 84,86"}

1. The banner shows what’s in progress and how many conflicts are left.
2. A conflicted file. Select it to open the conflict wizard.
3. The two versions of the file, one from each side.
4. The result: what the file will look like.
5. The button that resolves the file, or opens a merge tool.

## Operations in progress {#banner}

While a merge, rebase, cherry-pick, or revert is in progress, a banner sits at the top of the Working Copy:

- The title says what’s going on, for example :ui[conflict.title.merge]{1="feature/units-toggle" 2="main"}.
- Below it is the number of unresolved conflicts. Once the operation has stopped on a conflict, the number of resolved files follows in parentheses.
- A short hint says what to do next. During a rebase or a series of commits, a progress bar shows which step you’re on.
- :ui[working.onlyConflicts] narrows the file list to the files of this conflict. Files you’ve resolved stay in the list. Spooky remembers the choice for all repositories.
- :ui[working.abort] cancels the operation. See [Continue or abort](#continue).

The commit area stays hidden until every conflict is resolved.

## Use the conflict wizard {#wizard}

Select a conflicted file in the Working Copy. The conflict wizard opens on the right, with a card for each side, such as :ui[conflict.version]{1="main"}. Each card shows the file, what that side did to it (for example :ui[conflict.change.modified]), and the commit it came from.

To keep one side:

1. Click its card. The result box shows that version.
2. Click :ui[conflict.resolveUsing]{1="main"}.

Spooky writes that version into the file and stages it. The file counts as resolved. If that side deleted the file, the file is deleted.

To combine both sides, click both cards, then click the button below the result box. It opens a merge tool, as described in [Merge in another app](#merge-tool).

If you’ve already edited the file yourself, for example in a text editor, the result box shows :ui[conflict.result]. Click :ui[conflict.resolveCurrent] to stage the file as it is. The wizard reads the file again when you come back to Spooky.

The “…” button on a card opens a menu for that version:

- :ui[conflict.open]{1="main"} or open it with another app
- :ui[conflict.export]{1="main"}
- :ui[conflict.compareOther]{1="feature/units-toggle"}
- :ui[conflict.compareBase]

## Merge in another app {#merge-tool}

A merge tool shows both versions side by side and lets you pick changes line by line. It works on one file at a time, when both sides have the file.

1. In the conflict wizard, click :ui[externalTool.chooseMergeTool] and pick an app. After the first time, the button reads :ui[externalTool.mergeIn]{1="FileMerge"}.
2. Merge the file in that app, save the result, and quit it.

Spooky writes the result into the file and marks it as resolved. If the app didn’t save a result, Spooky says :ui[externalTool.noResult], and the conflict stays.

FileMerge works a bit differently. Spooky shows :ui[externalTool.finishMerge]{1="FileMerge"} while it’s open. Save the result in FileMerge, then click :ui[externalTool.done].

Spooky supports Araxis Merge, Beyond Compare, DeltaWalker, FileMerge, Kaleidoscope, P4Merge, and Visual Studio Code. To switch apps, change :ui[externalTool.mergeTool] in :ui[app.name > settings.title] › :ui[settings.gitConfig]. Turn on :ui[externalTool.keepBackups] there to keep the file as it was before the merge, for example as `src/units.ts.orig`. See [Diff and merge tools](/guide/settings/integration/#diff-merge-tools).

If the file was changed somewhere else while you merged, Spooky asks before it overwrites it.

:::note[Server repositories]
The merge tool gets copies of the versions in a temporary folder on this Mac. Spooky writes the result back to the server, then marks the file as resolved. The folder is deleted when you close the repository.
:::

## Other ways to resolve {#other-ways}

Right-click one or more conflicted files:

- :ui[conflict.menu.resolve]
  - :ui[conflict.markResolved.one]{1="src/units.ts"} stages the file as it is now. Selecting its checkbox does the same.
  - :ui[conflict.resolveUsingVersion]{1="main"} keeps one side, like the wizard.
- :ui[conflict.menu.restore]
  - :ui[conflict.restoreUnmerged.one]{1="src/units.ts"} brings the conflict back, even for a file you already resolved.
  - :ui[conflict.restoreVersion]{1="main"} and :ui[conflict.restoreAncestor] put one version into the file. The file stays unresolved.

:::caution
Restoring overwrites the file in the Working Copy without asking. Any edits you made to it are lost.
:::

When applying a stash or patch stops on conflicts, there’s no operation to continue or abort, and no banner. The wizard calls the incoming side :ui[conflict.version.applied]. Once the files are resolved, the changes are in the Working Copy like any others.

## Continue or abort {#continue}

When every conflict is resolved, the commit area comes back, with the message Git prepared for the operation.

- **Merge, or cherry-picking or reverting one commit**: check the message, then click :ui[working.commit].
- **Rebase, or cherry-picking or reverting several commits**: check the message, then click :ui[working.continue]. Spooky commits this step and moves on to the next one, which may stop on a conflict again.
- **A rebase step that stops to edit a commit**: make your commits, then click :ui[working.endEditing] in the banner.

Sometimes nothing is left to commit, for example when you kept the version that was already there. When you click :ui[working.commit] or :ui[working.continue] in that case, Spooky asks :ui[commit.empty.title] Click :ui[commit.empty.use] to make an empty commit. The other button aborts the merge, or skips the step in a rebase or series. In a rebase or series, you can also click :ui[working.skip] in the banner.

To give up, click :ui[working.abort] in the banner. The repository goes back to how it was before the operation started.

:::caution
Abort runs right away, without asking, and can’t be undone. The conflicts you resolved are lost.
:::

## See also

- [Review and Stage Changes](/guide/work/diff/)
- [Stashes](/guide/work/stash/)
- [Undo and Recovery](/guide/work/undo/)
