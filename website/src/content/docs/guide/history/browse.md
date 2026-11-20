---
title: "Browse History"
description: "Browse the commit list and graph, read reference badges, search and filter commits, and change the view options."
---

The :ui[history.title] view lists the commits of a repository, newest first, next to a graph of how they connect. Select a commit to see its details on the right.

::screenshot[The History view of a repository. The header above the list reads All Branches, Remotes, Tags, with the view options button at its right end. Commits are grouped under November 2026. Colored lines on the left connect the commits, and badges such as HEAD, main, and v0.4.0 sit next to the author names. On the right are the details of the selected commit, with the Changeset and Tree buttons at the top.]{name="history" frame="window" markers="50,13.75 42,23 22.5,62 81,9"}

1. The header: what the list shows, and the view options
2. Badges for the branches and tags that point at a commit
3. The commit graph
4. Details of the selected commit. See [Commit Details](/guide/history/commit-details/).

## Open the history {#open}

- :ui[menu.view > menu.showHistory] (<kbd>⌘2</kbd>), or :ui[history.title] in the sidebar, shows every branch, remote branch, and tag together. The header reads :ui[history.all].
- Click a branch, tag, or remote branch in the sidebar to see only its history. <kbd>⌘</kbd>-click more of them to see them together.
- :ui[menu.view > history.showHead] (<kbd>⌘0</kbd>) shows the history of the branch you’re on.

When you look at a local branch with an upstream, the header shows both, as in `main › origin/main`. The list then includes commits on the upstream that you haven’t pulled yet.

## The commit list {#list}

Each row shows the author’s avatar and name, the date, the short hash, and the first line of the message. Commits are grouped by month.

When the list shows a local branch with an upstream:

- ↑ marks a commit you haven’t pushed.
- ↓ marks a commit you haven’t pulled. These rows are dimmed.

Spooky loads the first 100 commits, and loads the next 100 when you scroll to the end. To load more at a time, change :ui[history.pageSize] in :ui[app.name > settings.title] › :ui[settings.general]. The same page sets :ui[settings.dateFormat].

Click a commit to select it. <kbd>⇧</kbd>-click or <kbd>⌘</kbd>-click selects several. <kbd>⌘C</kbd> copies the full hashes of the selected commits. Double-click a commit to open its details as a full page.

Right-click a commit for everything you can do with it. If the commit isn’t selected, the menu acts on that one commit only, and your selection stays as it is.

## The commit graph {#graph}

The graph on the left draws each commit as a dot, with lines down to its parents. A merge commit has more than one line going down.

To hide it, turn off :ui[history.showGraph] in the [view options](#view-options) (<kbd>⌃⌘G</kbd>). :ui[history.firstParentOnly] follows only the first parent of each merge, so commits that came in through a merge are left out.

## Reference badges {#badges}

Badges next to the author name show what points at a commit:

| Badge | Points at the commit |
|---|---|
| Blue HEAD | The commit you have checked out |
| Blue | A local branch |
| Gray | A remote branch |
| Yellow | A tag |
| Red | A stash |

The branch you’re on comes first. Badges that don’t fit collapse into “…”.

Click a tag badge to see the tag’s signature: the key and whether it’s valid, or :ui[signature.unsigned].

## Search and filter {#search}

1. Press <kbd>⌘F</kbd>, or click the search field in the toolbar.
2. Click the magnifying glass in the field to choose what to search: :ui[history.search.message], :ui[history.search.author], :ui[history.search.committer], :ui[history.search.file], :ui[history.search.hash], :ui[history.search.sinceDate], or :ui[history.search.untilDate].
3. Type. The list shows only the matching commits.

While you type, Spooky suggests authors, committers, and file paths. When searching messages, the suggestions also let you switch to another kind of search. If you type a date, the first suggestion searches for commits since that date.

How each kind matches:

- Messages, authors, and committers match as regular expressions, ignoring case.
- A file matches the commits that changed it. A folder matches the commits that changed anything inside it.
- A commit hash needs at least the first 4 characters.

The search shows up as a line below the header. Click :ui[history.search.add] (+) to add another condition, and choose its kind from the menu at the start of the row. Conditions of the same kind match any of them; conditions of different kinds must all match. For a date, choose :ui[history.search.after], :ui[history.search.before], or :ui[history.search.range]. Click − to remove a condition.

The search ends when you switch to another view.

## View options {#view-options}

Click :ui[history.viewOptions] at the right end of the header, or choose :ui[menu.view > history.title]:

| Option | What it does |
|---|---|
| :ui[history.showGraph] | Shows the commit graph. On by default. |
| :ui[history.firstParentOnly] | Follows only the first parent of each merge |
| :ui[history.sortBy] | :ui[history.sort.topo] keeps the commits of each line of work together, and :ui[history.sort.date] orders them by date. While the graph is shown, :ui[history.sort.topo] stays on. When both are on, the date order is used. |
| :ui[history.groupBy] | Groups commits by day, week, or month under headings, or not at all. Only applies while sorting by date. |
| :ui[history.medium] / :ui[history.small] | Two lines per commit, or one. Small rows only apply while the graph is shown. |
| :ui[signature.verify] | Marks signed commits. See [Signatures](/guide/history/commit-details/#signatures). |
| :ui[history.compareBranches] | See [Compare with another branch](#compare-branches) |

These options apply to every window and every repository, and Spooky remembers them.

## Compare with another branch {#compare-branches}

To see how a local branch relates to another one:

1. Click the branch in the sidebar.
2. Click :ui[history.compareBranches] in the header, or turn it on in the view options (<kbd>⌃⌥⌘C</kbd>).
3. Choose the other branch in the :ui[history.compareTo] menu. Spooky starts with the branch’s parent branch if it has one.

A row in the list marks where the two branches split. The commits below it also belong to the other branch, and are dimmed. If the branch has no commits of its own yet, the list says :ui[history.noNewCommits].

The header can also show two badges. One counts the commits on the other branch that this branch doesn’t have yet. The other appears when merging the other branch would cause conflicts. Click it to list the files.

## Find a commit in the history {#reveal}

When the list shows only some branches, right-click a commit and choose :ui[quickActions.revealInHistory]. The list switches to all branches and selects the commit.

If the commit is far back, beyond the first 10,000 commits, Spooky asks before it loads the history that far. If the commit isn’t in the history, a line above the list says so.

## See also

- [Commit Details](/guide/history/commit-details/)
- [Rewrite History](/guide/history/rewrite/)
- [Branches](/guide/branches/branches/)
