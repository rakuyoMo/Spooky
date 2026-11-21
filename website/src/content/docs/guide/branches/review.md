---
title: "Branches Review"
description: "Compare your local branches with a base branch, find the ones you can clean up, follow archive suggestions, and archive branches automatically."
---

Branches Review lists your local branches and compares each one with a base branch. It shows which branches can be merged, which would conflict, which are stale, and which no longer have their remote branch. That helps you decide what to merge, archive, or delete.

To open it, click :ui[review.title] at the top of the sidebar, or choose :ui[menu.view > review.show] (<kbd>⌘5</kbd>).

::screenshot[The Branches Review window. The base branch is main. The list shows six branches, from feature/csv-export to spike/radar-overlay, each with its merge status, commits ahead and behind, and tracked branch. feature/units-toggle is selected, and the details on the right show its commits and a conflicts button.]{name="branches-review" frame="window" markers="41.8,9 47.3,9 22,52 76,9"}

1. The base branch
2. The filter button
3. Whether the branch can be merged cleanly
4. The conflicts button

## The list {#list}

Pick the base branch in :ui[review.compareTo] at the top of the list. At first it’s the first of `next`, `develop`, `dev`, `main`, and `master` that the repository has, otherwise the branch you’re on.

Each branch gets a row:

- An icon on the left says whether the branch can be merged into the base cleanly or would lead to conflicts. Hold the pointer over it for details.
- On the right, how many commits the branch is ahead of and behind the base. It says :ui[review.comparing] while Spooky compares.
- The second line shows the remote branch it tracks, or :ui[review.noTracking]. When the remote branch is gone, the name turns red.
- When the branch was last updated, and the latest pull request or merge request for the branch, with its number and a color for its state.

## Filter and sort {#filter}

The filter button at the top right shows only some of the branches:

- :ui[review.filter.stale] and :ui[review.filter.active] split the branches by whether they’re stale. Stale means no new commits for as long as set in the sidebar’s [view settings](/guide/branches/branches/#filter), 6 months at first.
- :ui[review.filter.trackingError] shows branches whose remote branch is gone.
- :ui[review.filter.mergeable] and :ui[review.filter.conflicts] go by what merging into the base would do.
- :ui[pr.filter.with] and :ui[pr.filter.without] go by open pull requests or merge requests. They need a [hosting account](/guide/hosting/accounts/) for the remote. Without one, the list says so.
- :ui[review.filter.none] shows every branch again.

The view settings button next to it sorts the list by :ui[review.sort.name] or :ui[review.sort.date], in :ui[review.sort.ascending] or :ui[review.sort.descending] order. Spooky remembers both the filter and the order.

To find a branch by name, type in the search field in the toolbar.

## Details {#details}

Select a branch to see how it compares with the base on the right. The top shows the branch and the base. When merging would conflict, a button there lists the files.

:ui[compare.commits] lists the commits the branch has made since it split off from the base. :ui[history.changeset] shows what those commits changed. Above both, a summary shows :ui[review.summary.contributors], :ui[review.summary.updated], :ui[review.summary.tracking], and :ui[review.summary.mergeStatus].

You can select several branches at once, for example to archive or delete them together.

## Work with branches {#actions}

Right-click a branch for the same menu as in the sidebar. With several branches selected, the menu applies to all of them.

When a branch would conflict with the base, its menu also has :ui[review.resolveConflicts]. Spooky checks out the branch and merges the base into it. Then you resolve the conflicts on the branch. See [Resolve Conflicts](/guide/work/conflicts/).

To delete branches, select them and press <kbd>⌘⌫</kbd>, or swipe left on a row and click :ui[review.delete]. Spooky asks first, as it does in the sidebar.

## Archive suggestions {#archive-suggestions}

Spooky suggests [archiving](/guide/branches/branches/#archive) a local branch when:

- it’s stale, or
- its pull request or merge request was merged, and the branch has no new commits since.

Pinned and archived branches are never suggested. Neither are `main`, `master`, `trunk`, `dev`, `develop`, `next`, and branches that are another branch’s parent.

When there are suggestions and automatic archiving is off, a button with the number of branches shows up at the bottom of the sidebar. Click it to open :ui[review.archive.title]:

1. Select the branches to archive, or select :ui[menu.selectAll]. Nothing is selected at first. Each branch shows why it’s suggested: :ui[pr.archive.merged] or :ui[review.filter.stale].
2. Click :ui[review.archive.submit].

::screenshot[The Archive Branches dialog lists three branches, each marked Stale, and one is selected. At the bottom is the switch to archive branches automatically.]{name="branches-archive" frame="dialog"}

Afterwards, a note at the bottom of the sidebar says how many branches were archived, with an :ui[review.archived.undo] button. <kbd>⌘Z</kbd> works too. :ui[activity.title] records why each branch was archived.

## Archive automatically {#auto-archive}

Spooky can check for branches to archive once a day. Any of these turns it on. They’re all the same setting:

- :ui[review.archive.auto] in the :ui[review.archive.title] dialog
- :ui[sidebar.autoArchive] in the sidebar’s view settings
- :ui[settings.autoArchive] in :ui[app.name > settings.title] › :ui[settings.general] (see [Operations](/guide/settings/general/#operations))

It’s off at first.

Once a day for each repository, while you work in its window, Spooky looks for suggestions. If there are any, it opens the same dialog. There you pick the branches to archive. Whether you archive any or not, it checks again a day later.

To keep a branch out of it, right-click the branch and select :ui[review.skipAutoArchive] below the archive item in the menu.

When branches are archived this way:

- A notification says :ui[review.archived.notification]. The record in :ui[activity.title] is called :ui[review.autoArchive].
- A dot next to :ui[sidebar.archived] in the sidebar marks branches you haven’t looked at yet. Click one of them and its mark goes away after a moment. To clear them all, right-click :ui[sidebar.archived] and choose :ui[sidebar.markAllReviewed].

## See also

- [Branches](/guide/branches/branches/)
- [Merge and Rebase](/guide/branches/merge-rebase/)
- [Pull Requests and Merge Requests](/guide/hosting/pull-requests/)
- [Hosting Accounts](/guide/hosting/accounts/)
