---
title: "Commit Changes"
description: "Write a commit subject and description, use autocompletion, amend the last commit, and choose the identity and signing for a commit."
---

A commit saves the staged changes in the repository’s history, together with a message. Stage the changes first, as described in [Review and Stage Changes](/guide/work/diff/). Then write the message in the commit area at the top of the Working Copy.

## Write the message {#write}

The message has two parts:

- :ui[working.subject] is one short line that sums up the change. Press <kbd>Return</kbd> or <kbd>Tab</kbd> to move on to the description.
- :ui[working.body] is optional. Use it to explain what changed and why.

::screenshot[The commit area, expanded. The subject reads Add a units toggle, with a two-line description below. At the bottom of the description are the pin and wrapping buttons. Below are the Amend and Sign Off checkboxes, with the author’s name, email, and picture on the right. The Stage All and Commit buttons are at the bottom.]{name="work-commit-area" frame="closeup" markers="62,12 24,56 94.6,69.1"}

1. :ui[working.subject]
2. The pin button and the wrapping button
3. The author’s picture

The commit area expands while you type in either field, and stays open while the description has text. To keep it open all the time, click the pin button at the bottom of the description. Drag the bottom edge of the description to make it taller or shorter.

Once you start typing, the number at the end of the subject counts the characters you have left. Characters past the limit are highlighted.

The other button at the bottom of the description switches between two ways of wrapping:

- :ui[editor.softWrap] wraps lines at the edge of the field.
- :ui[editor.hardWrap] uses a fixed-width font and doesn’t wrap. A guide marks the character limit, and longer lines are highlighted. To break the current paragraph at the limit, choose :ui[menu.edit > commit.reformatParagraph] (<kbd>⇧⌘W</kbd>).

These options are in :ui[app.name > settings.title] › :ui[settings.editor]:

| Setting | Default |
|---|---|
| :ui[editor.showsCounter] | On |
| :ui[editor.subjectLimit] | 50 |
| :ui[editor.wrapping] | :ui[editor.softWrap] |
| :ui[editor.bodyLimit] | 72. You can change it when :ui[editor.hardWrap] is chosen. |
| :ui[editor.showsGuide] | On. Used with :ui[editor.hardWrap]. |
| :ui[editor.warnsComments] | On. See [Comments in the message](#comments). |
| :ui[editor.stripsComments] | Off. Available when the warning is off. |
| :ui[editor.completesIssues] | On. See [Autocomplete](#autocomplete). |

See [Editor](/guide/settings/appearance/#editor).

## Commit {#commit}

When the message is ready, click :ui[working.commit], or press <kbd>⌘↩</kbd> while you’re typing in the message. The button stays dimmed until the subject has some text and some changes are staged.

To jump to the subject from anywhere in the window, choose :ui[workspace.title > working.commitMenu] (<kbd>⇧⌘C</kbd>).

Two checkboxes below the description change the commit:

- :ui[commit.signOff] adds a `Signed-off-by` line with your name and email to the end of the message. The checkbox stays as you left it, in all repositories.
- :ui[commit.skipHooks] commits without running the repository’s `pre-commit` and `commit-msg` hooks. It shows up only when the repository has such hooks, and it turns off again after each commit.

If the commit fails, your message stays in the commit area. To take back a commit you just made, choose :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>). See [Undo and Recovery](/guide/work/undo/).

### Comments in the message {#comments}

Lines that start with `#` count as comments in Git, unless you set a different comment character. Spooky commits the message as you wrote it, so it asks first when the message has such lines: :ui[commit.comments]

- :ui[commit.removeComments] commits without those lines.
- :ui[commit.keepComments] commits them as they are.

Select :ui[commit.doNotAskAgain] to keep your choice for next time. To get the question back, turn on :ui[editor.warnsComments] in :ui[app.name > settings.title] › :ui[settings.editor]. See [Editor](/guide/settings/appearance/#editor).

If the message has nothing but comments, Spooky asks :ui[commit.commentsOnly] Click :ui[commit.keepCommentsAndCommit] to commit them anyway.

## Autocomplete {#autocomplete}

Type one of these in the subject or the description, and Spooky lists matches as you go on typing:

| Type | To insert |
|---|---|
| `c:` | The short hash of one of the last 100 commits. Type part of the hash, the subject, or the author. |
| `\` | The path of a staged file |
| `#` | The number of an open issue on GitHub or GitLab |
| `fixup!` or `squash!` at the start of the subject | The subject of an earlier commit, to mark this commit as a fix for it |

::screenshot[The commit subject after typing c:. A list below it shows recent commits, each with the author, date, short hash, and subject. The first one is selected.]{name="work-commit-completion" frame="closeup"}

Press <kbd>↑</kbd> or <kbd>↓</kbd> to choose a match, <kbd>Return</kbd> to insert it, and <kbd>Esc</kbd> to close the list.

Issue numbers need a [hosting account](/guide/hosting/accounts/) for the repository’s remote, and :ui[editor.completesIssues] turned on in :ui[app.name > settings.title] › :ui[settings.editor]. See [Editor](/guide/settings/appearance/#editor). A commit marked with `fixup!` or `squash!` can later be folded into its target, as described in [Rewrite History](/guide/history/rewrite/).

## Amend the last commit {#amend}

Amending replaces the last commit with a new one. Use it to fix the message, or to add changes you forgot.

1. Select :ui[working.amend] below the description. Spooky fills in the last commit’s message, and the checkbox shows that commit’s short hash.
2. Edit the message, and stage any changes that should go in.
3. Click :ui[working.amend].

Clear the checkbox to go back to the message you were writing before.

For a quick amend, hold <kbd>⌥</kbd> while neither message field is being edited. The commit area switches to amending the last commit until you let go. Click :ui[working.amend] while you hold the key, or press <kbd>⌥⌘↩</kbd>. The commit keeps its message and takes in the staged changes.

:::caution
If you already pushed the last commit, amending makes it different from the one on the remote. Pushing it then needs a force push. See [Force push](/guide/branches/sync/#force-push).
:::

To change an older commit, see [Rewrite History](/guide/history/rewrite/).

## Choose who commits {#identity}

The name and email to the right of the checkboxes are recorded in the commit as its author. They come from Git’s `user.name` and `user.email` settings. The picture next to them is looked up by the email address. See [Data and Privacy](/reference/data-privacy/).

To commit as someone else, for example with your work email, use a user profile:

1. Click the picture. A menu lists your profiles, with a checkmark next to the one in use.
2. Choose a profile.
3. Check which settings Spooky is about to write, and click :ui[profiles.apply.submit].

The profile’s name, email, and signing key go into this repository’s own Git settings, so other repositories aren’t affected.

If the current identity isn’t a profile yet, the menu offers :ui[profiles.addCurrent]{1="alex@example.com"} to save it as one. To set up profiles, choose :ui[profiles.manage] from the same menu. See [User profiles](/guide/settings/identity/#profiles).

:::note[Server repositories]
The profile goes into the repository’s settings on the server. Other tools that commit in the same repository on the server use it too.
:::

## Sign commits {#signing}

A signed commit carries proof that it came from the owner of a key. Spooky works with SSH and OpenPGP keys.

Hold the pointer over the picture in the commit area to see whether the next commit will be signed, and with which key.

- **For all repositories**: turn on :ui[gitConfig.signCommits] and choose :ui[gitConfig.signingKey] in :ui[app.name > settings.title] › :ui[settings.gitConfig]. See [Signing](/guide/settings/identity/#signing).
- **For one repository**: click :ui[repositorySettings.title] in the sidebar. Under :ui[repositorySettings.signing], set :ui[repositorySettings.signCommits] and :ui[repositorySettings.signingKey]. See [Repository settings](/guide/settings/identity/#repository).

If the key needs a passphrase, Spooky asks for it in a :ui[signing.unlock] dialog.

## See also

- [Review and Stage Changes](/guide/work/diff/)
- [Undo and Recovery](/guide/work/undo/)
- [User Profiles and Git Config](/guide/settings/identity/)
