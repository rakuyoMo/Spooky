### New

- A new **SSH Hosts** page in Settings lets you view, add, edit, and delete the host aliases in ~/.ssh/config. Double-click an alias or press Return to edit it; Spooky changes only the lines you edit, and other options and comments stay as they are
- The list of pull requests and merge requests can switch from **Open** to **All** to include closed and merged requests
- Pull requests and merge requests show their labels in the list and in **Conversation**
- A new **CI/CD** view in the request details shows the overall status and the result of each check or job, and stays up to date while anything is pending or running; each row in the list shows the CI/CD status too

### Improved

- Server repositories connect, run Git commands, read and write files, and cancel operations faster, especially on high-latency networks, and notice a dropped connection sooner
- Pasting several lines into **Commit Subject** keeps the first line in the subject and puts the rest into **Detailed description**
- In the **Repositories** window, Return now renames the selected bookmark or group instead of opening it, and Esc cancels; double-click to open a repository. Clicking the name of a selected row no longer starts renaming
- The repository window’s default toolbar adds **Finder**, **Terminal**, **Force Push**, and **Create Branch**, while **Quick Actions**, **Sync**, and **Merge** / **Rebase** can be added from **Customize Toolbar…** when you need them. To switch to the new layout completely, drag the default set onto the toolbar there
- When you delete bookmarks, the Trash checkbox is dimmed for a server repository whose folder is no longer on the server, and only the bookmark is removed
- When you reopen a GitLab repository, Spooky says merge request right away, without waiting for the remotes to load
- GitLab removes a merge request’s source branch reference 14 days after the request is closed or merged; fetching its commits after that shows **The Commits Are No Longer Available**
- When switching branches, staging, or another Git command fails because git-lfs can’t be found, the error now reads **Git LFS Is Unavailable** and explains how to set PATH for a local or server repository
- Old versions of the helper script in ~/.spooky/bin on a server are deleted after 30 days without use
- More consistent terms and punctuation in the interface in every language

### Fixed

- Writing a file in a server repository no longer damages the original when the connection drops or the write is cancelled
- A brief network pause no longer interrupts the connection to a server repository or the commands running on it
- After you cancel a file write in a server repository, Spooky no longer shows the connection as working while rejecting further writes
- Files that Git creates in a server repository get their permissions from the login umask, the same as when you run Git over SSH yourself
- Passwords in remote URLs no longer appear in activity logs or error messages
- Two server repositories whose paths look the same but differ in their bytes no longer share a connection
- Changing the app icon several times in a row now keeps the group you chose last
- The **Clone** toolbar item can be moved and removed, and it’s always listed in **Customize Toolbar…**
- When pulling, activity summaries no longer show Git’s raw fetch result
