---
title: "Your First Repository"
description: "Open a repository on your Mac, then change, stage, commit, and push your work from start to finish."
---

This page walks you through one full round of work. You open a repository on your Mac, change a file, stage the change, commit it, and push the commit to a remote.

You need a Git repository on your Mac with a remote you can push to. If you don’t have one yet, [The Repositories Window](/guide/repositories/manager/) shows how to clone or create one.

## Open the repository {#open}

1. Choose :ui[menu.file > action.openLocal] (<kbd>⌘O</kbd>).
2. Select the repository’s folder, then click :ui[repositories.panel.prompt].

Spooky opens the repository and shows its :ui[workspace.title]. It also adds the repository to the Repositories list. Next time, you can open it from there.

You can choose any folder inside the repository. Spooky opens the whole repository. If the folder isn’t in a Git repository, Spooky says :ui[bookmarks.noRepository.title]. Click :ui[bookmarks.noRepository.create] to make the folder a new repository, or :ui[action.cancel] to choose another one.

:::note[Server repositories]
To work in a repository on a server, add it with :ui[action.addRemote] instead. [Add Server Repository](/guide/server/add/) shows how. Once it’s open, the rest of this page works the same way.
:::

## Make a change {#change}

Edit a file in the repository with any editor and save it. Spooky notices the change and lists the file in :ui[workspace.title]. If a change doesn’t show up, click :ui[action.refresh] or press <kbd>⌘R</kbd>.

Select the file to see what changed in the right column. Added lines are green, and removed lines are red.

## Stage the change {#stage}

Git doesn’t commit everything you changed. It commits only what you stage. Staging lets you pick which changes go into the next commit. Everything else stays in the Working Copy for later.

To stage a file, do one of the following:

- Select the checkbox in front of the file.
- Select one or more files and press <kbd>Space</kbd>.
- Click :ui[working.stageAll] to stage every changed file.

Staged files keep their checkbox selected. To stage only some of the lines in a file, see [Review and Stage Changes](/guide/work/diff/).

## Commit {#commit}

A commit saves the staged changes in the repository’s history. It comes with a message that says what you changed and why.

1. Click :ui[working.subject] and type a short summary of the change. The commit area expands while you type.
2. If you want to explain more, write it in :ui[working.body].
3. Click :ui[working.commit], or press <kbd>⌘↩</kbd>.

::screenshot[The commit area with the subject “Add gust alerts and a humidity chart” typed in. Below it are an empty detailed description, the Amend and Sign Off checkboxes, the author’s name and email, and the Stage All and Commit buttons. The file list below shows three files with their checkboxes selected.]{name="start-commit" frame="closeup"}

A few things in the expanded commit area:

- The number at the end of the subject field counts the characters you have left. Past that, the subject is longer than recommended.
- :ui[working.commit] stays dimmed until the subject has some text.
- The name and email on the right are recorded in the commit as its author. To change them, see [User Profiles and Git Config](/guide/settings/identity/).
- :ui[working.amend] and :ui[commit.signOff] are explained in [Commit Changes](/guide/work/commit/).

After the commit, the committed files leave the list. In the sidebar, the current branch now shows ↑1. That’s one commit on your Mac that isn’t on the remote yet.

## Push {#push}

Pushing sends your commits to the remote. Others can get them from there, and the remote keeps a copy as a backup.

1. Click :ui[sync.push] in the toolbar, or choose :ui[menu.repository > sync.pushMenu] (<kbd>⇧⌘U</kbd>).
2. Check that :ui[sync.destination] is the remote branch you want to push to. If the branch already tracks a remote branch, that one is selected.
3. Click :ui[sync.pushHead].

::screenshot[The Push HEAD dialog. It pushes the new commits on the local branch “main” to the destination origin/main. Below are a collapsed Options section and the Cancel and Push HEAD buttons.]{name="sync" frame="dialog"}

When the push is done, the ↑1 next to the branch disappears. [Push](/guide/branches/sync/#push) covers :ui[dialog.options]. To push a branch for the first time, see [Publish a branch](/guide/branches/sync/#publish).

:::tip
Hold <kbd>⌥</kbd> and click the :ui[sync.push] button. It turns into :ui[sync.quickPush] and pushes the current branch to its tracking branch right away, without the dialog.
:::

## See also

- [Working Copy](/guide/work/working-copy/)
- [Commit Changes](/guide/work/commit/)
- [Fetch, Pull, and Push](/guide/branches/sync/)
