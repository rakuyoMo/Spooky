---
title: "Fetch, Pull, and Push"
description: "Fetch, pull, and push, publish a branch for the first time, sync, force push, and fetch automatically."
---

These operations exchange commits with [remotes](/guide/branches/tags-remotes/#remotes):

- Fetch downloads new commits from a remote. Your branches and the Working Copy stay as they are.
- Pull fetches a remote branch and brings its commits into the branch you’re on.
- Push sends your commits to a remote branch.

The toolbar has :ui[sync.fetch], :ui[sync.pull], and :ui[sync.push] side by side, and :ui[toolbar.forcePush] next to them. These operations and :ui[sync.sync] are in the :ui[menu.repository] menu.

Fetch, pull, push, and sync aren’t recorded in the undo history, so they can’t be undone. Publishing a branch can be undone.

:::note[Server repositories]
Remotes are reached from the server, with the server’s network and SSH keys. When a remote asks for a password, Spooky asks you. See [Password and passphrase prompts](/guide/server/connection/#prompts).
:::

## Fetch {#fetch}

1. Click :ui[sync.fetch] in the toolbar, or choose :ui[menu.repository > sync.fetchMenu] (<kbd>⇧⌘F</kbd>). To fetch one remote, right-click it in the sidebar and choose :ui[remote.fetchMenu]{1="origin"} from the menu.
2. Pick the remote in :ui[sync.remote], or select :ui[sync.allRemotes].
3. Set the options:
   - :ui[sync.prune] removes remote branches that were deleted on the remote. It’s on at first.
   - :ui[sync.fetchSubmodules] also fetches new commits in checked-out submodules.
   - :ui[sync.allTags] also fetches every tag on the remote.
4. Click :ui[sync.fetch].

Spooky remembers all the options except :ui[sync.allTags].

After a fetch, the remote branches in the sidebar are up to date, and ↓ on a local branch counts the commits you can pull.

:ui[menu.repository > sync.fetchAll] fetches every remote right away, without the dialog. It skips remotes set to :ui[remote.skipFetchAll] in their [settings](/guide/branches/tags-remotes/#remote-settings).

## Pull {#pull}

1. Click :ui[sync.pull] in the toolbar, or choose :ui[menu.repository > sync.pullMenu] (<kbd>⇧⌘P</kbd>). To pull a particular remote branch, right-click it and choose :ui[branch.pullMenu]{1="origin/main"} from the menu.
2. Pick the branch in :ui[sync.remoteBranch]. At first it’s the [upstream](/guide/branches/branches/#track) of the branch you’re on.
3. Select :ui[sync.rebase] to put your commits on top of the pulled ones, instead of joining the two with a merge commit. Spooky remembers this choice.
4. Below the options, a preview says whether the pull will run into conflicts. See [Preview conflicts](/guide/branches/merge-rebase/#preview).
5. Set the options:
   - :ui[merge.verify] stops the pull unless the pulled commit has a trusted signature. Spooky remembers it.
   - :ui[sync.skipHooks] skips the repository’s Git hooks this time.
6. Click :ui[sync.pull].

Your tracked files need to be unchanged for a pull. If they aren’t, Spooky offers to stash the changes first. See [Auto stash](/guide/work/stash/#auto-stash). New files only get in the way when the pull would overwrite them.

If the pull runs into conflicts, Spooky switches to the Working Copy and shows a banner. See [Resolve Conflicts](/guide/work/conflicts/#banner).

## Push {#push}

1. Click :ui[sync.push] in the toolbar, or choose :ui[menu.repository > sync.pushMenu] (<kbd>⇧⌘U</kbd>).
2. Pick the remote branch in :ui[sync.destination]. At first it’s the upstream of the branch you’re on.
3. Set the options:
   - :ui[sync.pushAllTags] pushes every local tag too.
   - :ui[sync.forcePush] overwrites the remote branch when a normal push can’t. See [Force push](#force-push).
   - :ui[sync.pushSubmodules] handles submodule commits this push refers to. Choose between :ui[sync.pushSubmodules.onDemand] and :ui[sync.pushSubmodules.check].
   - :ui[sync.skipHooks] skips the repository’s Git hooks this time.
4. Click :ui[sync.pushHead].

Spooky remembers the tag and submodule options.

If the branch you’re on doesn’t track a remote branch yet, :ui[sync.push] opens the publish dialog instead. See [Publish a branch](#publish). If the repository has no remote at all, it opens the dialog for publishing the repository. See [Publish a repository](/guide/hosting/accounts/#publish).

If someone else pushed to the remote branch first, the remote refuses your push. Pull their commits, then push again.

To push a branch you’re not on, drag it onto a remote branch in the sidebar. The :ui[sync.pushBranch] dialog pushes it there. It’s a plain push, without options, and it doesn’t change what the branch tracks.

## Publish a branch {#publish}

A new branch exists only in your repository until you publish it, which creates it on a remote.

1. Choose :ui[menu.repository > sync.publishMenu], or right-click the branch and choose :ui[branch.publishMenu]{1="feature/station-map"} from the menu. You can also drag the branch onto a remote in the sidebar.
2. Check :ui[branch.local] and :ui[sync.remote]. :ui[branch.name] is the name on the remote, the same as the local name at first.
3. :ui[sync.setUpstream] makes your branch track the new remote branch, so later pulls and pushes go there. It’s on at first.
4. Select :ui[sync.skipHooks] to skip the repository’s Git hooks.
5. Click :ui[sync.publish].

To take it back, choose :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

## Sync {#sync}

Sync fetches, pulls, and pushes the branch you’re on, one after another.

1. Choose :ui[menu.repository > sync.syncMenu] (<kbd>⇧⌘Y</kbd>).
2. Pick the branch in :ui[sync.remoteBranch]. At first it’s the upstream of the branch you’re on.
3. Select :ui[sync.rebase] if you like. The preview below says whether the pull will run into conflicts.
4. Set the options: :ui[merge.verify], :ui[sync.pushAllTags], :ui[sync.pushSubmodules], and :ui[sync.skipHooks] work as they do for pull and push.
5. Click :ui[sync.syncHead].

As with pull, Spooky offers to stash changes to tracked files first.

If a step fails, Spooky stops there and tells you which step it stopped at, and which steps were done. In :ui[activity.title], the pull and the push each get a record.

## Push to another place {#push-to}

To push a branch, tag, or commit to any branch or reference on a remote:

1. Choose :ui[menu.repository > sync.pushToMenu], or right-click a branch and choose :ui[branch.pushToMenu]{1="main"} from the menu. Tags have :ui[tag.pushToMenu]{1="v0.4.0"} in their menu too.
2. Pick what to push in :ui[sync.revision], and the remote in :ui[sync.remote].
3. In :ui[sync.refSpec], type where it goes: a new or existing branch name, or a full reference such as `refs/tags/v0.4.0`.
4. Click :ui[sync.pushRevision].

For a branch, the dialog starts with the remote branch it tracks. For a tag, it starts with `refs/tags/` and the tag’s name.

## Force push {#force-push}

After you rewrite commits you already pushed, for example by amending or rebasing, a normal push is refused: the remote branch has commits that your branch no longer has. A force push replaces the remote branch with yours.

Spooky only force pushes with a lease. The push goes through only if the remote branch is still where it was when you last fetched. If someone pushed in the meantime, Git refuses, and nothing is overwritten. Spooky never falls back to an unprotected force push.

1. Click :ui[toolbar.forcePush] in the toolbar, or choose :ui[menu.repository > sync.forcePushMenu] (<kbd>⌃⌘U</kbd>). You can also right-click a local branch and choose it from the menu.
2. Pick the local branch in :ui[branch.target], and the remote branch in :ui[sync.destination].
3. Read the comparison below them. It says how many commits the push adds to the remote branch and how many it overwrites. Then:
   - A green line means the remote branch is at the version your branch had before you rewrote it. This is the usual case.
   - A yellow line means the remote branch is somewhere else, or has commits your branch never had. Check that you really want to overwrite them.
   - If both branches are at the same commit, there’s nothing to push.
4. Click :ui[sync.forcePush].

::screenshot[The Force Push with Lease dialog. The local branch is feature/units-toggle and the remote branch is origin/feature/units-toggle. Below them, a line with a green check mark says the remote branch is at the version this branch had before it was rewritten.]{name="branches-force-push" frame="dialog" markers="16.4,65.9"}

1. The comparison

The :ui[sync.forcePush] option in the push dialog uses the same protection.

:::tip
Choose :ui[menu.view > menu.customizeToolbar] to add :ui[toolbar.synchronize] and :ui[toolbar.pushTo] to the toolbar.
:::

## Quick versions {#quick}

Hold <kbd>⌥</kbd>, and :ui[sync.fetch], :ui[sync.pull], and :ui[sync.push] in the toolbar turn into :ui[sync.quickFetch], :ui[sync.quickPull], and :ui[sync.quickPush]. :ui[sync.sync] turns into :ui[sync.quickSync] once you’ve added it to the toolbar. The menu items change the same way, for example :ui[sync.quickPushMenu].

A quick version runs right away, without the dialog:

- It works with the upstream of the branch you’re on.
- It uses the options you last chose in the dialog. :ui[sync.skipHooks] is never carried over.
- :ui[sync.quickFetch] fetches the remote that the current branch tracks. It fetches every remote when you last chose :ui[sync.allRemotes], or when the branch doesn’t track anything.
- If the branch you’re on doesn’t track a remote branch, :ui[sync.quickPush] and :ui[sync.quickSync] tell you so.

Right-click menus have quick versions too, such as :ui[sync.quickFetchNamed]{1="origin"} for a remote and :ui[sync.quickPullNamed]{1="origin/main"} for a remote branch.

## Fetch automatically {#auto-fetch}

Spooky can fetch in the background, so the remote branches and ↓ counts stay current. Choose how often in :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.autoFetch]: :ui[settings.autoFetch.never], every 5, 10, or 30 minutes, or :ui[settings.autoFetch.hour]. It’s every 30 minutes at first. See [Operations](/guide/settings/general/#operations).

- Spooky looks for remotes that are due about 10 seconds after a repository opens, and every few minutes after that. A remote is due when it was never fetched, or when the interval has passed since its last fetch.
- It fetches only while the window shows the repository and no dialog is open. It keeps going while Spooky is in the background.
- It starts only when nothing else is running in the repository. If you start something while it’s fetching, it stops and lets yours go first. :ui[activity.title] notes which operation it stopped for.
- It never asks for passwords. If it fails, the error only shows up in :ui[activity.title].
- It uses the prune and submodule options you last chose in the fetch dialog, and skips remotes set to :ui[remote.skipFetchAll].
- In a local repository, it skips remotes that are paths on your Mac, and doesn’t fetch while the Mac is offline.

## See also

- [Merge and Rebase](/guide/branches/merge-rebase/)
- [Branches](/guide/branches/branches/)
- [Operation Queue and Activity](/guide/advanced/queue-activity/)
- [Stashes](/guide/work/stash/)
