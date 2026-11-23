---
title: "Operation Queue and Activity"
description: "See how Spooky queues write operations, follow and cancel them in the sidebar’s activity area and the Activity window, and get system notifications."
---

Spooky changes a repository one operation at a time. If you start something while another operation is running, yours waits its turn instead of being turned away. Loading the status, history, and diffs doesn’t wait.

## How operations queue {#queue}

When nothing is running in the repository, an operation starts right away. Otherwise it joins the repository’s queue, and operations run in the order you started them. All windows showing the repository share the same queue.

This covers everything that changes the repository, wherever you start it: menus, the toolbar, right-click menus, Quick Actions, drag and drop, double-clicks, dialogs, the file list, and the commit area.

- Menu items and buttons stay available while the repository is busy. A dialog closes when you click its button, as usual.
- If an operation asks you to confirm, such as deleting a branch or force pushing, it asks when you click. It doesn’t ask again when its turn comes.
- Questions that depend on the repository at that moment, such as whether to stash changes that are in the way, come up when its turn comes.

While an operation that changes the Working Copy or the index runs, the file list is dimmed, even if you started the operation in another window. Other operations, such as fetching and pushing, leave the file list as it is, and what you do there joins the queue.

A commit that’s waiting keeps its message and options locked until it runs.

## When its turn comes {#turn}

After the operation before it finishes and the window has refreshed, Spooky checks the next one against the repository as it is now. It uses the same rules that decide whether the menu item is available. If the operation no longer makes sense, for example because the branch it works on is gone, it doesn’t run. Its record says :ui[activity.skipped], with the reason.

If an operation fails, everything queued after it is cancelled, so nothing runs on top of the failure. Their records say which operation failed. If you stop a running operation yourself, only that one stops, and the rest go on.

Queued operations are also cancelled when:

- The connection to a server repository is lost. They don’t run after you reconnect.
- You close the window, or open another repository in it. Only operations started from that window are cancelled.
- You quit Spooky.

## Undo and redo {#undo}

Undo and redo don’t queue. While an operation you started is running or waiting, they aren’t available, and the menu says :ui[undo.reason.busy]. See [When undo is blocked](/guide/work/undo/#blocked).

## Automatic fetch {#auto-fetch}

[Automatic fetch](/guide/branches/sync/#auto-fetch) starts only when nothing is running or waiting in the repository. If you start anything while it’s fetching, including undo and redo, it stops right away and your operation runs. Its record says :ui[activity.cancelled], and which operation it made way for.

## The activity area {#activity-area}

The bottom of the sidebar lists, for the repository in the window:

- Fetches, pulls, pushes, and other operations that connect to a remote, while they run and for a few seconds after they finish. The newest is on top.
- Below them, operations waiting in the queue, the next one on top. In place of Git’s output, they show :ui[activity.waitingDetail] until their turn comes.

Each row has a progress bar, a stop button, and the last line of Git’s output. Up to three rows show at once. Scroll for more.

- Click the stop button on a waiting row to take it out of the queue. Nothing runs, and the row says the operation was cancelled.
- Click the stop button on a running row to stop the operation.
- Click anywhere else in a row to open the :ui[activity.title] window.

Operations that don’t connect to a remote leave the area when they start. Their progress shows in the window itself, for example in the Working Copy or the commit area.

## The Activity window {#activity-window}

Choose :ui[menu.window > activity.title] (<kbd>⌃⌘0</kbd>). The window has records from all repositories, in three pages chosen in the toolbar:

| Page | What it lists | How long records stay |
|---|---|---|
| :ui[activity.remote] | Fetches, pulls, pushes, and other operations that connect to a remote | 7 days, saved on your Mac |
| :ui[activity.repository] | Other Git operations, and loads you start, such as loading commits | The last 100, until you quit |
| :ui[activity.service] | Requests to GitHub and GitLab | Until you quit |

::screenshot[The Activity window on the Remote page. The list has fetch, pull, and push records for a repository. The push is selected, and its full log is on the right.]{name="advanced-activity" frame="window" markers="55.2,10 32.8,4.6 93.8,4.6"}

1. The pages: :ui[activity.remote], :ui[activity.repository], and :ui[activity.service]
2. :ui[activity.clear]
3. The search field

Loads that Spooky does on its own to keep a window up to date aren’t listed.

Select a record to see its full log on the right. You can select and copy the text.

- Waiting operations are listed here too, as :ui[activity.waiting], with a stop button.
- :ui[activity.clear] removes the finished records on the current page. Running ones stay.
- The search field filters the current page by repository name and log text.

Passwords and tokens are left out of the logs.

## System notifications {#notifications}

Spooky posts a notification when:

- A clone finishes. It shows the remote address, without any username or password in it, and where the repository was cloned to. See [Clone a repository](/guide/repositories/manager/#clone).
- Branches are archived automatically. It shows how many. See [Archive automatically](/guide/branches/review/#auto-archive).

Spooky doesn’t ask for permission, so macOS delivers them quietly to **Notification Center** at first. To choose how they appear, choose **Apple menu › System Settings**, click **Notifications** in the sidebar, then click **Spooky**. Clicking a notification brings Spooky to the front.

:::note[Server repositories]
Each server repository has its own queue, like a local one. Stopping an operation, or an automatic fetch making way, ends the Git process on the server too.
:::

## See also

- [Fetch, Pull, and Push](/guide/branches/sync/)
- [Undo and Recovery](/guide/work/undo/)
- [Connection Status and Reconnecting](/guide/server/connection/)
