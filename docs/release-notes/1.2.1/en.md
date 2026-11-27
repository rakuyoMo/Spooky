### Improved

- In the narrow layout, the row of views below the toolbar now has every view listed under **Workspace** in the sidebar: besides **Working Copy**, **History**, and **Stashes**, there are **Pull Requests** (**Merge Requests** when the remote is on GitLab), **Branches Review**, and **Settings**, plus **Reflog** when **View › Sidebar › Show Reflog** is on. Scroll the row sideways to reach the ones that don’t fit; with a mouse wheel, hold down Shift as you scroll. The row always scrolls to show the view you’re in
- In the narrow layout, **Bookmarks** and **Clone** sit with **Prev** and **Next** before the window title, and **Bookmarks**, **Prev**, **Next**, and the search field stay on the toolbar at any width. Other buttons that don’t fit move into the » menu, and **Fetch**, **Pull**, and **Push** are the last to go
- While **Working Copy** is loading, a progress indicator takes the place of its folder icon, in the sidebar and in the narrow layout alike, so the number of changed files and the icon of an operation in progress stay visible and nothing next to it shifts. Quick loads no longer show it, and once it appears it stays for a moment, so it doesn’t flicker

### Fixed

- Pressing Esc in the toolbar’s search field now leaves the field; your search text stays, and the list stays filtered
