---
title: "Appearance and Themes"
description: "Choose the appearance, use a built-in theme or create, import, and export your own, set the text and editor options, and pick an app icon."
---

Four pages of :ui[app.name > settings.title] decide how Spooky looks: :ui[settings.appearance] for the app as a whole, :ui[settings.themes] for the colors of diffs and files, :ui[settings.text] for how text is shown, and :ui[settings.editor] for the commit message.

## Appearance {#appearance}

Click a picture in the :ui[settings.appearance.label] row to switch the whole app:

- :ui[appearance.system] follows macOS. This is the default.
- :ui[appearance.light] and :ui[appearance.dark] stay the same whatever macOS uses.

In a repository window, you can also switch from [Quick Actions](/guide/repositories/navigation/#quick-actions): find the appearance and run :ui[quickActions.setAppearance].

## App icon {#app-icon}

Below the appearance, :ui[settings.appIcon.label] lists the icons you can pick, in two series:

| Series | Icons |
|---|---|
| :ui[appIcon.series.hideAndSeek] | :ui[appIcon.rise] (the default), :ui[appIcon.front], :ui[appIcon.hide], :ui[appIcon.reveal] |
| :ui[appIcon.series.cherryPick] | :ui[appIcon.midnight], :ui[appIcon.perch], :ui[appIcon.cherryPick], :ui[appIcon.armful] |

Point at an icon to see it large on the left. Under it are the four ways it shows up in the Dock: as it is, connected to a server, dark, and dark while connected. Click the icon to use it. When the icons have keyboard focus, the arrow keys move between them and <kbd>Space</kbd> uses the one you’re on.

The new icon shows up in the Dock, the app switcher (<kbd>⌘Tab</kbd>), and Finder, even while Spooky isn’t running. A few things to know:

- While a server repository is connected, the icon lights up. In the :ui[appIcon.series.hideAndSeek] icons, the server’s lights come on. In the :ui[appIcon.series.cherryPick] icons, the ghost’s eyes turn into glowing stars.
- The dark version shows when the icon and widget style in **System Settings › Appearance** is dark, or is automatic while Spooky is dark. With a clear or tinted style, the icon doesn’t light up.
- When you switch to or away from :ui[appIcon.rise], the Dock restarts once. Otherwise, a Spooky kept in the Dock would still show the old icon.
- Spooky saves any other icon into `Spooky.app`. If it can’t write there, the page says why, and the icon doesn’t change.

## Themes {#themes}

A theme sets the font and colors that diffs and file contents use. Spooky comes with two: Default for the light appearance, and Default (Dark) for the dark one.

The theme selected in the list is the one the current appearance uses. Light and dark each remember their own. To set the theme for the other appearance, switch to it first. Quick Actions can switch themes too, with :ui[quickActions.applyTheme].

::screenshot[The Themes page of the Settings window. The list on the left has Default and Default (Dark), with Default selected, and the add and remove buttons at the bottom. On the right are a font field with Menlo-Regular 11.0, a list of text kinds such as Plain Text, Keyword, String, and Comment, each in its color, and color wells labeled Font Color, Background, Selection, Added, and Deleted. Below is a short diff preview with unchanged, deleted, and added lines.]{name="themes" frame="window" markers="13.3,30 9.4,95.3 58.3,17.8 61.1,37.3 66.7,56.9 61.1,82.7"}

1. The theme list
2. :ui[themes.add] and :ui[themes.remove]
3. The font
4. The kinds of text that syntax coloring tells apart
5. The color wells
6. A preview of a diff in this theme

### Make and edit a theme {#edit-theme}

1. Click the add button below the list. Spooky adds :ui[themes.newName], with the colors of the built-in theme for the current appearance, and selects its name.
2. Type a name and press <kbd>Return</kbd>.
3. Click the font field to pick a font and size in the font panel.
4. Select a kind of text in the list, then click :ui[themes.text] to change its color. :ui[themes.background], :ui[themes.selection], :ui[themes.added], and :ui[themes.deleted] set the colors around the text.

Changes are saved right away. The preview shows them as you go. To rename a theme later, select it and press <kbd>Return</kbd>.

You can edit the built-in themes, but not rename or delete them. To delete another theme, select it and click the remove button. Spooky asks first, because this can’t be undone. An appearance that used the theme goes back to its built-in one.

### Share themes {#share-themes}

Each theme is a `.spookytheme` file.

- **Export**: drag a theme from the list to a folder in Finder.
- **Import**: drag `.spookytheme` files onto the list. You can also open them from Finder or drop them on Spooky’s icon in the Dock.

If a theme with the same name exists, Spooky asks whether to replace it. A file that isn’t a valid theme is skipped with a message.

Spooky keeps themes in `~/Library/Application Support/Spooky/Themes/`. See [Data and Privacy](/reference/data-privacy/#mac).

## Text {#text}

The :ui[settings.text] page sets how text looks in diffs and file contents. The colors come from the theme.

| Setting | Default | What it does |
|---|---|---|
| :ui[text.enableSyntaxColoring] | On | Colors code by its language |
| :ui[text.syntaxColoringInDiffs] | Off | Uses syntax colors in diffs too. Needs syntax coloring on. |
| :ui[text.showInvisibles] | Off | Shows spaces, tabs, and line endings as symbols |
| :ui[text.tabWidth] | 4 | How wide a tab is, from 1 to 100 spaces |

## Editor {#editor}

The :ui[settings.editor] page sets up the commit message fields. See [Write the message](/guide/work/commit/#write) for how they behave.

| Setting | Default | What it does |
|---|---|---|
| :ui[editor.showsCounter] | On | Counts down the characters left in the subject |
| :ui[editor.subjectLimit] | 50 | The longest the subject should be, in characters. Choose a value or type one from 1 to 1,000. |
| :ui[editor.wrapping] | :ui[editor.softWrap] | Or :ui[editor.hardWrap], with a fixed-width font and no automatic wrapping |
| :ui[editor.bodyLimit] | 72 | The line limit for :ui[editor.hardWrap] |
| :ui[editor.showsGuide] | On | Draws a line at that limit, for :ui[editor.hardWrap] |
| :ui[editor.warnsComments] | On | Warns about lines that Git would treat as comments. See [Comments in the message](/guide/work/commit/#comments). |
| :ui[editor.stripsComments] | Off | Removes those lines when you commit. Available while the warning is off. |
| :ui[editor.completesIssues] | On | Completes issue numbers after `#`. See [Autocomplete](/guide/work/commit/#autocomplete). |

## See also

- [General, Updates, and Environment](/guide/settings/general/)
- [Review and Stage Changes](/guide/work/diff/)
- [Commit Changes](/guide/work/commit/)
- [Windows and Navigation](/guide/repositories/navigation/)
