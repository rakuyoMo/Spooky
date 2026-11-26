### New

- When the repository window gets too narrow for three columns, it switches to a narrow layout: a row below the toolbar takes the place of the sidebar and switches between **Working Copy**, **History**, and **Stashes**, and the list sits above the details. Click **Sidebar** at the start of the row to open the full sidebar on top of the view. Widen the window and the three columns come back as wide as you left them; the view you’re in, your selection, and the commit message you’re writing stay as they are
- In a narrow window, buttons that don’t fit on the toolbar move into the » menu, while **Fetch**, **Pull**, and **Push** stay on the toolbar
- When the **Repositories** window gets narrow, it changes layout too: the list of repositories sits above the details of the selected one, and you can drag the line between them
- To keep one layout at any width, choose **Narrow** or **Wide** from **View › Window Layout**; with **Automatic**, the default, the layout follows the width of the window. The choice applies to all windows
- You can change a repository’s location in the **Repositories** window instead of removing it and adding it again: in the details, move the pointer over the **Location** row and click **Edit**. For a server repository, you can change just the host alias or just the path. The repository stays in its group and keeps a name you gave it
- In the **CI/CD** view of the request details, a check or job that has a log can be expanded to show the log below its row. GitHub Actions jobs have a log once they finish; every job of a GitLab pipeline can be expanded, and while a job is running, its log updates along with the status
- You can add and remove a request’s labels in **Conversation**: click the × after a label’s name to remove it, click **Add** to choose one of the project’s labels, or use **New Label…** to create one and add it to the request
- To mention someone in a comment on a request, including a reply or an edit, type @. Spooky lists the people in the request and the members of the project and narrows the list as you type a username or name; press Return to insert the username

### Improved

- The list of pull requests and merge requests now shows each request’s state as an icon before the title instead of text after it: green for an open request, gray for a draft, red for a closed one, and purple for a merged one
- On the **Updates** page in Settings, the release channels are now **Stable**, **Beta**, and **Alpha**. Beta and alpha versions carry the label in their version number, such as 1.2.0-beta.1, so you can tell them apart in **About Spooky** and in the update window

### Fixed

- macOS no longer asks for your keychain password after every Spooky update when Spooky reads an account’s token or the credentials saved in your keychain. After you install this version, it asks one more time for each saved item
- After you change an alias on the **SSH Hosts** page in Settings, the bookmarked repositories on that host no longer fail to connect under the old alias; their settings and the credentials saved in your keychain move to the new alias too
- While you’re viewing pull requests or merge requests, **Refresh** and ⌘R now reload the list and the selected request, and the list loads again when you return to the repository in the same window
- Reloading the list of pull requests or merge requests no longer clears the selection and details of a request further down the list
- With **Show Worktrees in Repository List** turned off on the **General** page in Settings, opening a worktree no longer adds a bookmark for it
