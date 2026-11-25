---
title: "Install Spooky"
description: "Check the system requirements, download Spooky, open it for the first time, keep it up to date, choose its language, and uninstall it."
---

This page walks you from downloading Spooky to opening it for the first time. It also covers updates, the interface language, and how to remove Spooky.

## System requirements {#requirements}

- macOS 26 or later
- Git 2.41 or later

Spooky uses the Git at `/usr/bin/git` unless you pick another one. To pick one, open :ui[app.name > settings.title] (<kbd>⌘,</kbd>), click :ui[settings.gitConfig], and choose a program from the :ui[settings.gitProgram] menu. The menu lists the Git programs Spooky found that are new enough. Choose :ui[settings.gitProgram.choose] to use one from somewhere else. The minimum version is shown below the menu. See [Git program](/guide/settings/identity/#git-program).

:::note[Server repositories]
The server needs Git 2.41 or later too. Spooky reaches it over SSH with a host alias from `~/.ssh/config`. The Git you pick in Settings only applies to repositories on your Mac. Server repositories use the Git on the server. See [System Requirements](/reference/requirements/) and [Prepare SSH](/guide/server/prepare-ssh/).
:::

## Download {#download}

1. Open the [Spooky releases page](https://github.com/rakuyoMo/Spooky/releases) on GitHub.
2. Find the newest stable release. Its name is `v` followed by the version number. Releases marked **Pre-release** are betas and alphas, and their version numbers end in `-beta.` or `-alpha.` and a number.
3. Download the zip file named `Spooky-` followed by the version number.
4. Double-click the downloaded zip file to unzip it.
5. Drag Spooky into your **Applications** folder.

## Open Spooky for the first time {#first-launch}

Spooky isn’t notarized by Apple. The first time you open it, macOS stops it and shows a warning. To open it anyway:

1. Double-click Spooky in your **Applications** folder. When the warning appears, close it.
2. Choose **Apple menu › System Settings**, then click **Privacy & Security** in the sidebar. You may need to scroll down.
3. Go to **Security**, then click **Open Anyway**. The button is available for about an hour after you tried to open Spooky.
4. Enter your login password, then click **OK**.

macOS remembers your choice. From then on, Spooky opens normally. It starts with the Repositories window. [A Tour of Spooky](/guide/start/tour/) explains what you see there.

## Keep Spooky up to date {#updates}

Spooky checks for updates on its own by default. :ui[app.name > updates.check] checks right away.

Every update is signed. Spooky checks the signature before installing an update. If an update fails the check, it doesn’t replace the copy you have.

To change how Spooky updates, open :ui[app.name > settings.title] and click :ui[settings.updates]:

| Setting | What it does |
|---|---|
| :ui[updates.channel] | Which releases you receive. See [Release channels](#channels). |
| :ui[updates.automaticChecks] | Checks for updates in the background. On by default. |
| :ui[updates.automaticDownloads] | Downloads updates in the background and installs them when you quit Spooky. Off by default. Available only when automatic checks are on and Spooky is in a folder you can write to. |
| :ui[updates.interval] | How often to check: :ui[updates.interval.hourly], :ui[updates.interval.daily], or :ui[updates.interval.weekly]. The default is daily. Available only when automatic checks are on. |

The last row, :ui[updates.lastCheck], shows when Spooky last checked. If it hasn’t checked yet, it says :ui[updates.never].

### Release channels {#channels}

| Channel | You receive |
|---|---|
| :ui[updates.channel.stable] | Stable releases. This is the default. |
| :ui[updates.channel.beta] | Stable and beta releases |
| :ui[updates.channel.development] | All releases, including alphas |

### What changed {#whats-new}

The first time you start a new version of Spooky, repository windows show :ui[whatsNew.card.title] at the bottom of the sidebar. Click :ui[whatsNew.card.learnMore] to read what changed. You can also just close the card.

To read the notes later, choose :ui[menu.help > help.whatsNew]. :ui[menu.help > help.releaseNotes] opens the releases on GitHub.

## Choose the interface language {#language}

Spooky comes in English, Simplified Chinese, Traditional Chinese, Japanese, Korean, German, French, and Spanish. It follows the language order you set in macOS. If none of your languages is available, it uses English.

To use a different language just for Spooky:

1. Choose **Apple menu › System Settings**, then click **General** in the sidebar.
2. Click **Language & Region**, then go to **Applications**.
3. Click the **Add** button, choose Spooky and a language, then click **Add**.
4. If Spooky is open, quit it and open it again.

To go back to the system language, select Spooky in the same list and click the **Remove** button.

## Uninstall {#uninstall}

1. Quit Spooky with :ui[app.name > menu.quit] (<kbd>⌘Q</kbd>).
2. Move Spooky from your **Applications** folder to the **Trash**.

Your settings and data stay on your Mac. To remove them too:

- Settings: run `defaults delete com.rakuyo.spooky` in **Terminal**.
- Other data, such as your themes and Activity records: delete the folder `~/Library/Application Support/Spooky/`.
- Caches: delete the folder `~/Library/Caches/com.rakuyo.spooky/`, and the items in `~/Library/HTTPStorages/` whose names begin with `com.rakuyo.spooky`.
- Passwords and tokens Spooky saved: delete the items in your keychain whose names begin with `com.rakuyo.spooky.`.
- On each server you used: delete the folder `~/.spooky/` in your home folder there.

Repositories keep the `branch.<name>.spooky-*` entries that Spooky added to their Git configuration. [Data and Privacy](/reference/data-privacy/) lists what Spooky stores and where.

## See also

- [A Tour of Spooky](/guide/start/tour/)
- [System Requirements](/reference/requirements/)
- [Data and Privacy](/reference/data-privacy/)
