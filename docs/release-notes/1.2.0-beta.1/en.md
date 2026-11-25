### New

- When the repository window gets too narrow for three columns, it switches to a narrow layout: a row below the toolbar takes the place of the sidebar and switches between **Working Copy**, **History**, and **Stashes**, and the list sits above the details. Click **Sidebar** at the start of the row to open the full sidebar on top of the view. Widen the window and the three columns come back as wide as you left them; the view you’re in, your selection, and the commit message you’re writing stay as they are
- In a narrow window, buttons that don’t fit on the toolbar move into the » menu, while **Fetch**, **Pull**, and **Push** stay on the toolbar
- In the **CI/CD** view of the request details, a check or job that has a log can be expanded to show the log below its row. GitHub Actions jobs have a log once they finish; every job of a GitLab pipeline can be expanded, and while a job is running, its log updates along with the status
- You can add and remove a request’s labels in **Conversation**: click the × after a label’s name to remove it, click **Add** to choose one of the project’s labels, or use **New Label…** to create one and add it to the request

### Improved

- The list of pull requests and merge requests now shows each request’s state as an icon before the title instead of text after it: green for an open request, gray for a draft, red for a closed one, and purple for a merged one
- On the **Updates** page in Settings, the release channels are now **Stable**, **Beta**, and **Alpha**. Beta and alpha versions carry the label in their version number, such as 1.2.0-beta.1, so you can tell them apart in **About Spooky** and in the update window

### Fixed

- macOS no longer asks for your keychain password after every Spooky update when Spooky reads an account’s token or the credentials saved in your keychain. After you install this version, it asks one more time for each saved item
- After you change an alias on the **SSH Hosts** page in Settings, the bookmarked repositories on that host no longer fail to connect under the old alias; their settings and the credentials saved in your keychain move to the new alias too
