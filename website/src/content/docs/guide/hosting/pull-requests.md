---
title: "Pull Requests and Merge Requests"
description: "List, create, discuss, check out, merge, and close pull requests on GitHub and merge requests on GitLab."
---

Spooky shows the pull requests on GitHub and merge requests on GitLab for a repository’s remote. You can read and discuss them, see their CI/CD status, check them out, merge them, and create new ones, without leaving the repository window.

This needs a [hosting account](/guide/hosting/accounts/) for the remote. When the remote is on GitLab, the sidebar, menus, and dialogs say merge request instead of pull request.

## Open the list {#list}

Click :ui[pr.title] in the sidebar, or choose :ui[menu.view > pr.show.menu] (<kbd>⌘4</kbd>).

Choose a remote from the menu at the top of the list. Each row shows:

- An icon for its state, then the title. The icon is green for an open request, gray for a draft, red for a closed one, and purple for a merged one. Hold the pointer over it to see the state by name.
- The number, the author, and when it was opened
- The source branch and the branch it goes into. For a request from a fork, the source branch comes with its project.
- Its labels, each in its own color. Hold the pointer over a label to see its description. Labels that don’t fit on one line are left out.
- On the right, an icon for its [CI/CD status](#checks), when it has one

Scroll to the bottom to load more.

The list starts with open requests only. To see closed and merged ones too, click the filter button at the top of the list and choose :ui[pullRequests.filter.all]. Closed and merged requests can’t be merged or closed. The next time you open the window, the list is back to :ui[pullRequests.filter.open].

If the list can’t load, it says why. The requests it already loaded stay below. When the account’s token is rejected or lacks a scope, you can click :ui[accounts.reauthenticate] right there.

When the list can’t tell which account to use, see [Which account a remote uses](/guide/hosting/accounts/#remotes).

## Read a request {#details}

Select a request to see it on the right. Switch between four views at the top:

- :ui[pullRequests.conversation]: the title and state, the labels, the description, the comments, and the commits grouped by day, oldest first.
- :ui[pullRequests.commits]: the request’s commits. The bar above lists the contributors and how many commits there are.
- :ui[pullRequests.changeset]: what the request changes, compared with where its source branch split off.
- :ui[pullRequests.checks]: the request’s checks or pipeline jobs. See [CI/CD status](#checks).

In the conversation, double-click a commit or press <kbd>Return</kbd> to open it. Right-click a commit to copy its hash. Click a link in the text to open it.

:ui[pullRequests.commits] and :ui[pullRequests.changeset] need the request’s commits in your repository. If they aren’t there yet, click :ui[pullRequests.fetch]. Spooky gets them from the remote without changing your branches.

GitLab stops keeping a merge request’s commits 14 days after it’s closed or merged. From then on, :ui[pullRequests.fetch] can’t get them, and Spooky says the commits are no longer available. This only matters when your repository doesn’t have the commits yet.

## CI/CD status {#checks}

:ui[pullRequests.checks] shows how the request’s latest commit is doing:

- **GitHub**: the checks and commit statuses on that commit
- **GitLab**: the jobs of the request’s latest pipeline

The overall status is at the top, and each check or job is listed below with its own. While anything is pending or running, Spooky keeps the view up to date by itself.

In the list, the icon on a request’s row is its overall status. Hold the pointer over it to see the status by name. A request without checks or a pipeline has no icon.

A check or job that has a log has a disclosure triangle on the left of its row. Click it to show the log below the row. Click it again to hide the log.

- **GitHub**: GitHub Actions jobs have a log once they finish. Skipped jobs, commit statuses, and checks from other apps don’t.
- **GitLab**: every job of the pipeline can be expanded. While a job is running, its log updates along with the status.

The log leaves out the timestamps and color codes. You can select and copy its text.

## Create a request {#create}

The source branch has to be on a remote already. Push it first, then do one of these:

- Click the add button at the top of the list.
- Choose :ui[menu.repository > pr.create.menu] (<kbd>⌃⌘P</kbd>).
- Right-click a branch in the sidebar and choose :ui[pr.forBranch.create]{1="feature/units-toggle"} from the menu. If the branch already has an open request, the item is :ui[pr.forBranch.show]{1="feature/units-toggle"} instead.

In the dialog:

1. Next to :ui[pullRequests.source] and :ui[pullRequests.target], choose a remote and a branch on it. The source starts as the branch you right-clicked or the current branch, and the target as the remote’s default branch. Only remotes on the same instance as the account are listed. A source in a different project makes a request from a fork.
2. The title starts as the source branch name. The description is optional.
3. Click :ui[pr.create.submit].

The source and target can’t be the same branch.

## Discuss {#discuss}

To add a comment, click :ui[pullRequests.addComment] at the end of the conversation, or press <kbd>⌘S</kbd>.

For your own comments, use :ui[pullRequests.comment.edit] and :ui[pullRequests.comment.delete] on the comment, or right-click it. Double-clicking your comment also opens it for editing. Deleting a comment can’t be undone.

On GitLab, you can also reply to any comment with :ui[pullRequests.comment.reply]. The reply goes into the same discussion on GitLab.

For your own request, you can also:

- Change the description: click :ui[pullRequests.edit] next to it, or right-click it and choose :ui[pullRequests.editDescription.menu] from the menu.
- Change the title, description, and target branch: double-click the request in the list, or right-click it and choose :ui[pr.edit.menu]{1="#12"} from the menu. The source and the target project stay as they are.

## Edit labels {#labels}

A request’s labels are in :ui[pullRequests.conversation], below the title.

- To remove a label, click the × after its name.
- To add a label, click :ui[pullRequests.labels.add] and choose one of the project’s labels. Type in the field at the top to filter them.
- To create a label, click :ui[pullRequests.labels.add], then :ui[pullRequests.labels.new]. Enter a name, choose a color, and click :ui[pullRequests.createLabel.title]. Spooky creates the label in the project and adds it to the request.

The list shows the change right after. If your account isn’t allowed to change labels, Spooky shows the service’s answer and the labels stay as they are.

## Check out a request {#checkout}

To work on a request’s code, click :ui[pullRequests.checkout] at the bottom of the details, or right-click the request and choose :ui[pr.checkout.menu]{1="#12"} from the menu.

Enter a name for the local branch and click :ui[pullRequests.checkout]. The name starts as the source branch name. For a request from a fork, it’s `pullrequests/<author>/<branch>`.

Spooky first gets the request’s commits, then checks out the branch:

- If a local branch with that name already points to them, Spooky checks it out.
- If it points somewhere else, the dialog says so. Choose another name.
- Otherwise Spooky creates the branch. For a request from the same project, it tracks the source branch on the remote, as long as that’s at the same commit.

When you have changes to tracked files, Spooky asks whether to stash them first. See [Auto stash](/guide/work/stash/#auto-stash).

Checking out isn’t available when the local branch that tracks the source branch has commits you haven’t pushed. It isn’t available either when that branch is the current branch and already at the request’s commit.

A merge request whose commits GitLab no longer keeps can only be checked out when your repository already has them.

## Merge a request {#merge}

Click :ui[pullRequests.merge] at the bottom of the details. The merge happens on the hosting service. It can’t be undone.

- **GitHub**: choose a :ui[pullRequests.mergeType] from the ones the repository allows: :ui[pullRequests.method.merge], :ui[pullRequests.method.rebase], or :ui[pullRequests.method.squash]. Spooky picks the one you used last time.
- **GitLab**: the dialog shows the project’s :ui[pullRequests.mergeStrategy]. Select :ui[pullRequests.squash] to squash. The option is missing when the project doesn’t allow squashing. It stays on when the project requires it.

:ui[pullRequests.deleteBranch] removes the source branch on the service. It starts as the project’s setting.

If the request can’t be merged, the dialog says why. For example, it’s a draft, it has conflicts, your account isn’t allowed to merge, or the service is still checking.

After the merge, Spooky fetches from the remote to bring its branches up to date.

## Close a request {#close}

Click :ui[pullRequests.close] at the bottom of the details, and confirm. To reopen it, go to the hosting service.

:::note[Server repositories]
The list, the CI/CD status, and everything you do on the service go from your Mac. Fetching a request’s commits, checking it out, and the fetch after a merge run on the server. So do the comparisons in :ui[pullRequests.commits] and :ui[pullRequests.changeset].
:::

Each request to the service shows up on the :ui[activity.service] page of the :ui[activity.title] window. The automatic CI/CD updates don’t.

## See also

- [Hosting Accounts](/guide/hosting/accounts/)
- [Branches](/guide/branches/branches/)
- [Branches Review](/guide/branches/review/)
