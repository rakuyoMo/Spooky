<h1 align="center">Spooky</h1>

<div align="center">

English | [简体中文](README-ZH.md)

A native Git client for macOS that works with repositories on your Mac and on your servers.

[![CI](https://github.com/rakuyoMo/Spooky/actions/workflows/ci.yml/badge.svg)](https://github.com/rakuyoMo/Spooky/actions/workflows/ci.yml)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

</div>

> [!NOTE]
> To use Spooky, download it from [GitHub Releases](https://github.com/rakuyoMo/Spooky/releases/latest). Before you open it for the first time, read [Install Spooky](https://spooky.rakuyo.dev/guide/start/install/) in the user guide.

## About

Spooky opens Git repositories on your Mac, and works directly with repositories on another machine over SSH.

A server repository's working tree stays on the server: Git runs there and files are read and written over SFTP, so the repository never has to be cloned to your Mac.

Connections use the system's SSH and the host aliases in `~/.ssh/config`. OpenSSH handles authentication, host keys, and connection sharing.

This README is for developers. It covers the tools you need, how to build, run, test, and debug Spooky, and how to contribute.

## Requirements

### Development

- macOS 26 or later

- Xcode with Swift 6.2 or later. CI and releases build with the Xcode set by `DEVELOPER_DIR` in [`ci.yml`](.github/workflows/ci.yml); use the same version to get the same results

- [mise](https://mise.jdx.dev), which runs the build, test, code style, release, and website tasks defined in `mise.toml`

### Git and servers

Spooky runs Git on the machine where each repository is, so the machines you test with need:

- Git `2.41.0` or later on your Mac and on servers, as Spooky uses `git fetch --porcelain`
  - Local repositories use `/usr/bin/git` unless another Git program is chosen in Settings
  - Server repositories use the Git on that host

- On servers:
  - OpenSSH with reverse Unix socket forwarding
  - OpenSSH `8.4` or later, to enter SSH private key passphrases for Git on the server
  - `MaxSessions` of 10 or more in the sshd configuration (the OpenSSH default)
  - `/usr/bin/perl` with the core modules `IO::Socket::UNIX`, `JSON::PP`, and `POSIX`
  - No root access or background services

- Git LFS `2.9.0` or later for repositories that use it, on the machine where the repository is and in the `PATH` that Git uses there

- sshfs with macFUSE or FUSE-T on your Mac, to mount server repositories with sshfs

- An account on github.com, GitLab.com, or a self-managed GitLab `9.0` or later, for pull requests and merge requests

## Building and running

Run commands from the repository root:

```sh
# Get the source code
git clone https://github.com/rakuyoMo/Spooky.git
cd Spooky

# Build the core library and the app
mise run build

# Launch the app
swift run Spooky
```

`swift run` starts the bare executable, without the app icons, release notes, licenses, and localized permission prompts that come with an app bundle. Updates and system notifications are turned off as well.

Build a development app when you need any of these, or when you want to open Spooky from the Finder or set its language separately in System Settings:

```sh
# Build .build/Spooky.app
./scripts/build-app.sh

# Launch the built app
open .build/Spooky.app
```

The release app uses a release build and is ad-hoc signed and verified:

```sh
# Build build/Spooky.app
mise run bundle
```

## Architecture

Spooky is a Swift package with two main targets, each organized into folders by feature:

- `SpookyKit`, in `Sources/SpookyKit/`: the core library. It runs Git on your Mac or on a server, reads and writes repository files, and parses Git's output

- `Spooky`, in `Sources/Spooky/`: the app. AppKit manages its windows, split views, toolbars, and menus, and SwiftUI provides the content

A few designs run through the whole codebase:

- **One way to run Git**: every Git call goes through `GitRunner`, which works the same way for local and server repositories. Local repositories run the Git program chosen in Settings, and server repositories run Git on the server through `/usr/bin/ssh`

- **One write at a time**: each repository has one write queue shared by all its windows. Writes run one at a time in the order they were started, and a write started while another is running waits its turn. Read-only Git commands are registered in `RepositoryOperationQueue.isReadOnly`, and every other command is treated as a write

- **Server connections**: each server working tree gets its own SSH master connection (ControlMaster), which exits after 10 idle minutes. After the first connection check, the Perl helper `spooky-remote.pl` is installed in `~/.spooky/bin/` on the server, named after a digest of its contents, to manage remote processes and callbacks. Files are read and written over SFTP on the same master connection

- **Callbacks**: when Git asks for a password, a passphrase, or an editor, `CallbackRelay` brings the request back to the Mac, through a reverse Unix socket for server repositories and a private Unix socket for local ones

- **Refreshing**: local repositories refresh when FSEvents reports a change. Server repositories are polled every 2 seconds in the foreground and every 10 seconds in the background, and less often while the server stays slow to answer

- **Files for other apps**: Quick Look, external tools, and dragged-out files get their files through `RepositoryFileCache`, so server paths never reach local file APIs

- **Hosting services**: requests to GitHub and GitLab are made from the Mac through `HostingClient`

[Architecture](docs/architecture.md) describes what each folder is for and the designs that span modules, and [AGENTS.md](AGENTS.md) lists the rules that code must follow. Both are in Chinese.

## Testing

```sh
# Run the tests that are on by default
mise run test

# Run a single suite
swift test --filter LocalizationTests
```

- Tests use Swift Testing. Tests that use Git run in temporary repositories and ignore the system and user Git configuration

- App tests make their windows transparent and turn off sheet animations, so nothing shows up on screen while they run

- Tests that read windows through the Accessibility API only run when the process running them has Accessibility access. In a terminal, that's the terminal app

- Git LFS tests only run when `git-lfs` is in `PATH` or in Homebrew's folders

- Tests have no time limits. If a run seems stuck, the test that started but never finished is the stuck one; CI stops the test job after 30 minutes

Tests that need a server, github.com, or a large repository are skipped unless you turn them on:

| Variable | Turns on |
|---|---|
| `SPOOKY_REMOTE_TESTS=1` | Server tests, run against the SSH host alias `spooky-test` |
| `SPOOKY_GITHUB_TESTS=1` | Pull request tests on a github.com test repository, together with `SPOOKY_GITHUB_TOKEN` and `SPOOKY_GITHUB_REPOSITORY` |
| `SPOOKY_PERFORMANCE_TESTS=1` | Performance tests on a generated repository with 100,000 files and 60,000 commits |

[Testing](docs/testing/README.md) (in Chinese) explains how to set them up, and has manual acceptance steps for each milestone.

## Debugging

### Logs

Spooky logs under the `com.rakuyo.spooky` subsystem, with each type as its own category:

```sh
# Stream the logs live
/usr/bin/log stream --predicate 'subsystem == "com.rakuyo.spooky"' --level info

# Show the logs from the last 5 minutes
/usr/bin/log show --last 5m --predicate 'subsystem == "com.rakuyo.spooky"' --info
```

The logs record connection state changes, remote sessions, failed and cancelled Git commands, writes, and callback requests. They never contain command arguments or output, commit messages, or credentials.

Repository paths, host aliases, and other user data are marked private, so the logs show them as `<private>`. In zsh, `log` is a built-in command, so use the full path.

### Developer menu

Turn on **Show Developer menu** in **Settings › General** to add the **Developer** menu:

- **User Defaults**: log all preferences to standard output, reset settings while keeping bookmarks, user profiles, accounts, and the locations of server repositories on this Mac, or clear the whole preferences domain without asking

- **Test Crash Reporting**: crash with a fake exception or a bad access, to test crash reports

- **Auto-Archive Branches**: run auto-archive now, or reset the times each repository was last checked

- **Show What’s New Card**: show the What’s New card in the sidebar again

- **Auto-Reload Repository**: turn refreshing on file changes and polling on or off

### Where data is stored

On your Mac:

| Data | Location |
|---|---|
| Settings, bookmarks, user profiles, the account list, and the locations of server repositories on this Mac | Preferences domain `com.rakuyo.spooky` |
| Themes, one `.spookytheme` file each | `~/Library/Application Support/Spooky/Themes/` |
| The `.spookyrepo` folders that list server repositories in recent documents | `~/Library/Application Support/Spooky/Locations/` |
| Remote operations in the Activity window, kept for 7 days | `~/Library/Application Support/Spooky/Activity/` |
| The previous lists that the Activity window compares against | `~/Library/Application Support/Spooky/Baselines/` |
| Credentials saved to the Keychain | Keychain service `com.rakuyo.spooky.remote.<host alias>` |
| Hosting account tokens | Keychain service `com.rakuyo.spooky.hosting.<instance address>` |
| Connections and callbacks | Private `/tmp/spooky-*` directories, removed when the session closes |
| File copies for Quick Look and other apps | Private `spooky-files-*` temporary directories, removed when the repository closes |

On servers:

| Data | Location |
|---|---|
| The remote helper and its askpass, GPG, and ssh-keygen entry points | `~/.spooky/bin/`, kept for later connections |
| Session runtime files | `/tmp/spooky-*`, removed when the session closes |

In repositories, pins, archives, parent branches, and branch review marks are stored in the repository's own Git configuration as `branch.<name>.spooky-*`. Repository settings are written to the same configuration.

## Localization

Spooky is localized into English, Simplified Chinese, Traditional Chinese, Japanese, Korean, German, French, and Spanish. It follows the system language and falls back to English. Strings are in `Sources/Spooky/Resources/<language>.lproj/`.

When you add a string, add it to every language with the same format arguments. `LocalizationTests` fails when a language is missing a key, a translation is empty, format arguments don't match, or a key isn't used anywhere. Keys built at run time are registered in `LocalizationTests.dynamicKeys`.

## Website

The website at [spooky.rakuyo.dev](https://spooky.rakuyo.dev), with the home page and the user guide, is built from `website/` with [Astro](https://astro.build) and [Starlight](https://starlight.astro.build). It needs Node.js 24, which mise installs for the website tasks only:

```sh
# Install the dependencies and start the development server
mise run website:dev

# Run the website's tests, check types and internal links, and build the site into website/dist/
mise run website:build
```

Pages quote the app's labels from `Localizable.strings` by resource key, so renaming or removing a key that the website uses breaks its build. The simulated window on the home page also takes its colors from `BuiltinThemes.json` and `NamedColors.json`. The app icon and the ghosts on the home page and the 404 page are drawn at build time by the app icon scripts in `scripts/make-icon/`. Screenshots are stored with [Git LFS](https://git-lfs.com); install it before cloning to get them.

When the home page is opened on your machine (the development server, or a preview of the built site), a numbered grid covers the page and the header reads out where the top of the viewport and the ghost's center are, in grid cells, so you can point at where the scrolling ghost should do what. The published site doesn't show the grid.

GitHub Actions builds the website on pull requests that change it, and deploys it to GitHub Pages when it changes on `main`.

## Code style

The code style follows [RakuyoKit/swift](https://github.com/RakuyoKit/swift):

```sh
# Format the code and fix what can be fixed automatically
mise run swift:format

# Check the code style
mise run swift:lint
```

SwiftLint runs in strict mode, so warnings fail the check too. The other coding conventions are in [AGENTS.md](AGENTS.md) (in Chinese).

## Releasing

Maintainers release new versions from `main`:

```sh
# Open a release PR for version X.Y.Z; the channel defaults to stable
mise run release X.Y.Z [stable|beta|development]
```

The script checks the version, the release notes in `docs/release-notes/X.Y.Z/`, and the state of the repository, then opens a release PR. Once it's merged, GitHub Actions bundles the app, signs the update, tags the merge commit, and creates the GitHub Release.

[Releasing](docs/releasing.md) (in Chinese) has the details.

## Contributing

- Before opening a pull request, run `mise run swift:lint`, `mise run build`, and `mise run test`, and make sure they all pass. CI runs the same checks on every pull request and push to `main`, and bundles the app as well

- If you change the app, launch it and check that your change works. [M1](docs/testing/M1.md) has the basic steps

- [AGENTS.md](AGENTS.md) has the conventions for code, comments, logs, tests, branch names, commit messages, and pull requests. Coding agents such as Claude Code and Codex follow it too. It's in Chinese

- Before bringing in outside code, make sure its license is compatible with GPL-3.0

## License

Spooky is licensed under the [GNU General Public License v3.0](LICENSE).

### Third-party software

- [Sparkle](https://sparkle-project.org) 2.10.0, used for updates. Licensed under the MIT License; the license ships with the app as `Contents/Resources/Sparkle-LICENSE.txt`
- [highlight.js](https://highlightjs.org) 11.12.0, used for syntax coloring. Copyright (c) 2006, Ivan Sagalaev. Licensed under the BSD 3-Clause License; the full license is in [`Sources/Spooky/HighlightJS/LICENSE`](Sources/Spooky/HighlightJS/LICENSE) and ships with the app
- [swift-subprocess](https://github.com/swiftlang/swift-subprocess) 1.0.1, used to launch Git and other subprocesses. Licensed under the Apache License 2.0; the license ships with the app as `Contents/Resources/Subprocess-LICENSE.txt`
