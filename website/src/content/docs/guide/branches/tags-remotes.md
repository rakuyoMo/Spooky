---
title: "Tags and Remotes"
description: "Create, publish, and delete tags, and add, edit, rename, and remove remotes."
---

Tags are listed in the sidebar under :ui[sidebar.tags], and remotes under :ui[remote.group]. Both have their own menus: right-click one to see what you can do with it.

## Tags {#tags}

A tag gives a commit a name that stays put, usually for a release such as `v0.4.0`. Unlike a branch, it doesn’t move when you commit.

Hold the pointer over a tag to see the commit it points at, and its message if it has one. Double-click a tag to check out its commit; see [Check out a tag or a commit](/guide/branches/branches/#checkout-revision).

Like branches, tags whose names contain a `/` go into folders. To show only the newest few, or sort them the other way round, see [Filter and group](/guide/branches/branches/#filter).

### Create a tag {#create-tag}

1. Choose :ui[menu.repository > tag.createMenu] (<kbd>⇧⌘T</kbd>), or choose it from the :ui[reference.addMenu] button at the bottom of the sidebar. To tag a particular branch or commit, right-click it and choose :ui[tag.createFrom]{1="main"} from the menu instead.
2. Type the name in :ui[reference.name].
3. :ui[tag.revision] is the commit to tag. At first it’s the branch you’re on, or what you right-clicked.
4. Write a :ui[tag.messageField] if you like. Without one, the tag is just a name for the commit. With one, Git also saves who made the tag and when.
5. To sign the tag, select :ui[tag.sign], and pick a key in :ui[tag.signingKey]. :ui[tag.signingKey.configured] uses the key set up in Git. A signed tag needs a message. Spooky remembers whether you sign.
6. Click :ui[tag.create.submit].

You can also drag a commit or a local branch onto :ui[sidebar.tags] or a tag folder.

A new tag exists only in this repository until you publish it. To remove it again, choose :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

### Publish a tag {#publish-tag}

1. Right-click the tag and choose :ui[tag.publishMenu]{1="v0.4.0"} from the menu, or choose :ui[menu.repository > tag.publishMainMenu] in the menu bar. You can also drag the tag onto a remote.
2. Check :ui[tag.local] and :ui[sync.remote]. The remote is the one your current branch tracks, unless you dragged the tag onto another.
3. Select :ui[sync.skipHooks] to push without running the repository’s Git hooks.
4. Click :ui[tag.publish].

Publishing a tag can be undone. Undo deletes it on the remote again.

To push every tag to a remote at once, right-click the remote and choose :ui[tag.pushAll]{1="origin"} from the menu. The push dialog can also send all tags along; see [Push](/guide/branches/sync/#push).

### Delete a tag {#delete-tag}

Right-click the tag and choose :ui[reference.deleteMenu]{1="v0.1.0"} from the menu. You can also select one or more tags and press <kbd>⌘⌫</kbd> while the sidebar is focused.

Spooky always asks first. To delete the tag on a remote too, select :ui[tag.deleteRemote] and pick the remote in :ui[sync.remote].

Deleting a tag only in this repository can be undone. Deleting it on a remote can’t.

## Remotes {#remotes}

A remote is another copy of the repository that you fetch from and push to, often on a hosting service. The one you cloned from is usually called `origin`.

Under :ui[remote.group], each remote lists its branches. Hold the pointer over a remote to see its fetch and push URLs.

Right-click a remote for its menu:

- :ui[remote.fetchMenu]{1="origin"} and :ui[sync.prune] open the fetch dialog for this remote; see [Fetch](/guide/branches/sync/#fetch).
- :ui[remote.viewInBrowser]{1="origin"} opens the remote’s web page. It works for HTTP(S), SSH, and `git://` URLs, but not for local paths.
- The other items add, edit, rename, and delete remotes, as described below.

:::note[Server repositories]
Remotes are reached from the server, with the server’s network and SSH keys. A URL that works on your Mac might not work from the server.
:::

### Add a remote {#add-remote}

1. Choose :ui[menu.repository > remote.addMainMenu], or choose :ui[remote.addMenu] from the :ui[reference.addMenu] button at the bottom of the sidebar. You can also right-click :ui[remote.group].
2. Type a short name in :ui[reference.name], such as `upstream`.
3. Paste the address in :ui[remote.url].
4. Click :ui[remote.add.submit].

Spooky checks the connection before it adds the remote. The dialog stays open until that works, so you can fix a typo and try again. Once the remote is added, Spooky fetches it right away.

### Remote settings {#remote-settings}

Click a remote in the sidebar to open its settings. The switch at the top has two pages:

- :ui[remote.page.general] shows how Git talks to the remote.
- :ui[remote.page.branches] lists the remote’s branches with the commit each one points at.

Hold the pointer over a row in :ui[remote.page.general] to show its buttons.

| Setting | What it does |
|---|---|
| :ui[remote.field.fetchURL] | Where Spooky fetches from. Right-clicking the remote and choosing :ui[remote.editConnection] edits it too. |
| :ui[remote.skipFetchAll] | Leaves this remote out of automatic fetching and :ui[sync.fetchAll]. |
| :ui[remote.field.fetchRefspecs] | Which branches to fetch, and where to keep them. |
| :ui[remote.field.pushURL] | Where Spooky pushes to. Until you set one, pushing uses the fetch URL, shown in gray. :ui[remote.action.unset] goes back to it. |
| :ui[remote.field.pushRefspecs] | Which branches to push, and where. |

A refspec is a rule that maps branch names on one side to names on the other. Most remotes only need the one Git sets up. To add one, click :ui[remote.action.addRefspec] next to :ui[remote.group.fetch] or :ui[remote.group.push].

Spooky checks a new URL before saving it. Changes to remote settings can be undone.

### Rename or remove a remote {#rename-remote}

Right-click the remote and choose :ui[reference.renameMenu]{1="origin"} or :ui[reference.deleteMenu]{1="origin"} from the menu.

Removing a remote removes it and its remote branches from this repository. The repository it points to doesn’t change. Both renaming and removing can be undone.

## See also

- [Branches](/guide/branches/branches/)
- [Fetch, Pull, and Push](/guide/branches/sync/)
- [Undo and Recovery](/guide/work/undo/)
