<h1 align="center">Spooky</h1>

<div align="center">

English | [简体中文](README-ZH.md)

A native Git client for macOS that works with repositories on your Mac and on your servers.

</div>

> [!NOTE]
> Spooky is still in development and hasn't been released yet. For now, you can only build it from source, and features and interface may still change.

## About

Spooky opens Git repositories on your Mac, and works directly with repositories on another machine over SSH.

A server repository's working tree stays on the server: Git runs there and files are read and written over SFTP, so you don't need to clone the repository to your Mac.

Connections use the system's SSH and the host aliases in `~/.ssh/config`. OpenSSH handles authentication, host keys, and connection sharing.

## Features

- **Local and server repositories**: both kinds share the same interface. Server repositories show the host in their title, bookmark, and copied path

- **Repository bookmarks**: organize local and server repositories in folders, sort them by hand or by name, and rename them. See each repository's location, current branch, last commit, committer identity, description, and remotes, and edit the description and identity. Repositories that can't be found are marked instead of removed

- **Create, clone, and find repositories**: create repositories on your Mac or on a server, and clone in the background with LFS and submodule options while the bookmark shows the progress. Search a folder on your Mac or on a server for existing repositories; server searches run on the server, and server folders can be typed in or browsed

- **Windows and navigation**: tabs, window restoration, a quick start window, back and forward between views, Quick Actions to find views, branches, tags, commits, files, stashes, and more and act on them, and a customizable toolbar

- **Connection checks and recovery**: before adding a server repository, Spooky checks the connection, the Git version, and the server environment. If the connection drops, the last snapshot stays on screen while Spooky reconnects in the background. Writes are disabled until the connection recovers

- **Automatic refresh**: local repositories refresh when files change. Server repositories refresh every 2 seconds in the foreground and every 10 seconds in the background. You can also refresh at any time

- **Per-repository view state**: each window remembers the view, selection, and commit message draft of up to 15 repositories, and restores them when you switch back

- **Clear errors**: errors show their category, the repository, and the original Git or SSH output, which you can select and copy

- **Working copy**: view changes as a list or a tree, or browse every file in the repository. Show ignored and assume-unchanged files, and filter by path. Untrack, delete, move, ignore, or exclude files, restore them to a revision, and apply patch files. Preview files with Quick Look, drag them out, or open them in their default app

- **Stage files, hunks, or lines**: multiple selection and three-state checkboxes. Select lines in a diff to stage or discard just those lines

- **Diff options**: change the number of context lines, show the entire file, ignore whitespace, show invisible characters, and set the tab width. Changed words within modified lines are highlighted. Syntax coloring uses highlight.js and covers its 192 languages; files whose language can't be identified are shown as plain text. Images are compared side by side or one at a time

- **Commit messages**: a subject length counter, soft or hard wrapping for the body, handling of comment lines, and completion for recent commits, changed files, and `fixup!` or `squash!` subjects. Amend the most recent commit, sign off, or skip hooks

- **Identities and signing**: switch the committer identity of a repository with user profiles, and pick a profile's signing key from the GPG and SSH keys on your Mac. Sign commits with GPG or SSH; for a server repository, signing happens on the server and passphrase prompts come back to your Mac

- **Conflict wizard**: during a merge, rebase, cherry-pick, or revert, see how many conflicts are left, and the current step of a rebase. Compare both versions of each file and use one or both of them, or fix the file in another editor and use that version, then continue, skip, or abort

- **Stashes**: save all or only selected changes, take snapshots that leave the working copy as it is, and apply a stash with its staged state or apply a single file from it. When local changes block a checkout, pull, or merge, Spooky offers to stash them first and reapply them afterward

- **File history and blame**: follow a file through history, filtered by author, committer, or revision, with author names suggested as you type. See who last changed each line, view any committed version of a file, and export versions from its history

- **History**: commits load page by page, with a commit graph, ref badges, and ahead and behind counts. Search by message, author, committer, file, commit hash, and date, and combine several conditions. Sort by date or topology, group commits by day, week, or month, or follow only first parents. Dates can be shown in full or relative to now, and authors appear with their Gravatar picture or their initials

- **Commit details**: browse the full file tree of a commit and check GPG and SSH signatures. Merge commits can be shown against their first parent, as only the files that were actually merged, or without a diff. Compare any two revisions, export the files of a revision as a folder or a zip archive, and save commits as patch files

- **Branches, tags, and remotes**: the sidebar groups refs into folders by “/” and can be filtered. Pin and archive branches, and see which ones are fully merged, stale, or tracking a branch that no longer exists. Fast-forward, rename, and delete local and remote branches, set upstream and parent branches, create lightweight, annotated, or signed tags, and manage remotes with their URLs and refspecs. Branch names are converted into valid ref names as you type

- **Sync and merge**: fetch, pull, push, and sync, with options for pruning, all tags, submodules, and hooks. Force pushes only overwrite the version you last saw, and any revision can be pushed to any ref, such as a Gerrit review. Remotes can be fetched automatically while Spooky is in the foreground, without asking for credentials. Merges are previewed for conflicts first. Every operation is logged in the **Activity** window, and running operations can be cancelled

- **Rewriting history**: revert, cherry-pick, reset with a soft, mixed, or hard mode, check out any revision, and rebase onto a new base. Rebase interactively to squash, fixup, edit, reword, delete, or reorder commits, add staged changes to an older commit, or autosquash. Before rewriting, Spooky lists the affected commits and warns about those that were already pushed or merged

- **Branches review**: compare local branches with a base branch to see whether they're merged, can be merged cleanly, or would conflict. Update a branch from its parent branch by merging or rebasing, and archive obsolete branches in bulk or automatically, after you confirm the list

- **Reflog and undo**: browse and search the reflog of HEAD or any branch, and restore a branch or create a new one from any entry. Undo and redo Git operations in each repository; Spooky checks the repository before restoring it, and tells you when an operation can't be undone

- **Drag and drop**: drag branches, commits, and tags in the sidebar to create branches and tags, merge, rebase, cherry-pick, revert, pull, publish, push, pin, archive, or rename. Drag commits within the history to squash, fixup, or move them

- **Open in Terminal**: supports Terminal, iTerm, Warp, Ghostty, WezTerm, Prompt, and Otty. For a server repository, the terminal connects over SSH and opens the remote path

- **External tools**: compare and merge with external diff and merge tools, and open files with other apps. Server files are copied to your Mac for these tools, and merge results and edited files are written back only after Spooky checks that the server's version hasn't changed. VS Code opens server files directly over Remote - SSH

- **Links**: `spooky://` links open a repository, a view, a branch, or a commit, or start a clone, for local and server repositories alike. The “Open with Desktop” links on github.com can open in Spooky

- **Settings**: appearance, global Git identity and signing, the Git program, external tools, Gerrit pushes, issue tracker links, the SSH agent, and environment variables. Repository settings cover the description, issue tracking, committer identity, line wrapping, signing, LFS tracking patterns, ignores, and excludes

- **Updates and diagnostics**: Spooky checks for signed updates on the stable, beta, or development channel. Help can export a diagnostic report with personal details removed, and after a crash Spooky can open a pre-filled GitHub issue that you submit yourself

- **Themes**: Default and Default (Dark) are saved as regular themes that you can edit, rename, or delete, and are restored the next time Spooky starts if they're missing or damaged. Create your own themes for diffs and file contents, import and export them by drag and drop, and choose one for the light appearance and one for the dark appearance

- **Eight languages**: English, Simplified Chinese, Traditional Chinese, Japanese, Korean, German, French, and Spanish. The app uses your system language, or English if that language isn't supported

## Requirements

- macOS 26 or later
- Git `2.41.0` or later on both your Mac and your servers, as Spooky uses `git fetch --porcelain`
  - Local repositories use `/usr/bin/git` unless you choose another Git program in Settings. If it's too old, Spooky asks you to update Xcode or the Command Line Tools
  - Server repositories use the Git on that host
- Servers also need:
  - OpenSSH with reverse Unix socket forwarding
  - `/usr/bin/perl` with the core modules `IO::Socket::UNIX`, `JSON::PP`, and `POSIX`
  - OpenSSH `8.4` or later, to enter SSH private key passphrases for Git on the server
  - No root access or background services are needed

## Building from source

Spooky isn't available for download yet, so you need to build it from source. Building requires Swift 6.2 or later.

The project uses Swift Package Manager. Run these commands from the repository root:

```sh
# Build the core library and the app
swift build

# Launch the app
swift run Spooky
```

You can also build a development app that opens from Finder:

```sh
# Build .build/Spooky.app
./scripts/build-app.sh

# Launch the built app
open .build/Spooky.app
```

The release app uses a release build, includes the app icon and the update framework, and is ad-hoc signed:

```sh
# Build build/Spooky.app
./scripts/bundle.sh
```

## Permissions

### Automation

When your terminal application is Terminal or iTerm, Spooky uses AppleScript to have it open the repository. The first time, macOS asks whether to allow Spooky to control that application.

If you declined, you can turn it on again in **System Settings › Privacy & Security › Automation**.

## How it works

### Server connections

- Each server working tree uses its own SSH master connection (ControlMaster), which exits after 10 minutes of inactivity. Spooky never uses or closes your other SSH master connections
- SSH agent forwarding is off by default. If a host key is unknown or has changed, verify it in a trusted terminal first
- After the first successful connection check, Spooky installs a small helper program, named after a digest of its contents, in `~/.spooky/bin/` on the server with your user permissions. It manages remote processes and callbacks, relies on the server's Perl, and doesn't keep running in the background
- Files are read and written with the system's SFTP over the same master connection
  - The system SFTP batch mode can't represent paths that contain CR or LF, so file operations on such paths fail with a clear error
- Quick Look, other apps, and files you drag out never receive a server path. They get a copy of the file in a private temporary directory on your Mac, which is removed when the repository closes
- Polling reads only the status and the selected file's content hash, and reads everything else only when something changed. History pages and commit details, which depend only on commit hashes, are cached to save round trips
- Exports, archives, and patches of a server repository are produced by Git on the server and streamed to your Mac over the same master connection. Nothing is written on the server
- Interactive rebases run entirely on the server: the commit sequence and messages are written by an editor built into the command, so no editor opens on your Mac

### Writes and disconnections

- Writes to the same repository run one at a time. Only one window can start a write to a repository at a time, and every window showing the repository refreshes when the write finishes
- If the connection drops during a write, Spooky doesn't retry it. After reconnecting, it checks the branch, working copy, index lock, remote-tracking branches, and any merge or rebase in progress, tells you whether HEAD and the remote-tracking branches changed, and only then allows writes again
- Undo records HEAD, branches, tags, branch settings, the stash list, the index, and the content of tracked files before and after each operation. The snapshots are written to the object database of the repository, on your Mac or on the server, and Spooky checks that the repository still matches the record before restoring it
- To cancel an operation on a server, Spooky closes the command channel, then ends the remote process group: it sends TERM, waits 2 seconds, sends KILL, and confirms that the processes have exited
  - If it can't confirm this, Spooky says so and blocks writes until a reconnection check

### Credentials

- When Git on the server needs a password, an SSH private key passphrase, a signing key passphrase, or an editor, the request comes back to your Mac through a reverse Unix socket on the current master connection, and Spooky shows a dialog
  - Each request carries a random session token, can be answered only once, and times out after 120 seconds
  - Commits on a server are signed there by the signing program the repository is configured with. GPG is asked for a passphrase only when it actually needs one
- Network operations in local repositories also ask for credentials through a private Unix socket callback. After an SSH private key is unlocked, OpenSSH adds it to the current SSH agent
- Local commits, merges, rebases, cherry-picks, and reverts ask for SSH signing key passphrases the same way. GPG passphrases are handled by your Mac's own pinentry
- Credentials stay in memory by default. They're written to your Mac's Keychain only when you select **Save in this Mac’s Keychain**
- Credentials are never written to temporary files, activity logs, or error messages, and credentials echoed in output are hidden
- Automatic fetches never show a dialog. They only use credentials saved in the Keychain, and if none are available, the failure is only recorded in the **Activity** window
- Signature checks never download keys from key servers or update the GPG trust database, on your Mac or on the server

### Data and system changes

On your Mac:

- Settings, user profiles, and repository bookmarks are stored in the preferences domain `com.rakuyo.spooky`
- Themes, including Default and Default (Dark), are stored in `~/Library/Application Support/Spooky/Themes`, one `.spookytheme` file per theme
- Credentials saved to the Keychain use the service name `com.rakuyo.spooky.remote.<host alias>`
- Connections and callbacks use private `/tmp/spooky-*` temporary directories, which are removed when the session closes. Signature checks in local repositories use one of these directories as well, removed as soon as the check finishes
- Author pictures are requested from Gravatar with a SHA-256 hash of each author's email address, and are kept in memory only while Spooky is running
- File copies for Quick Look and other apps are kept in private `spooky-files-*` temporary directories, which are removed when the repository closes
- Opening a server repository in Warp writes `Spooky-*.yaml` to `~/.warp/launch_configurations/`, and opening it in Prompt uses a temporary `.command` file. When Spooky quits, it removes only the files it created
- At launch, Spooky reads its own crash reports in `~/Library/Logs/DiagnosticReports/` to offer a GitHub issue. Nothing is uploaded automatically
- Updates are checked against `appcast.xml` on GitHub Releases, and downloaded updates are verified with an EdDSA signature before they're installed

On the server:

- `~/.spooky/bin/`: the remote helper and its askpass, GPG, and ssh-keygen entry points, with `0700` permissions. They stay after the session ends so later connections can use them
- `/tmp/spooky-*`: a private runtime directory for the session, removed when the session closes

In your repositories:

- Pins, archives, parent branches, and branch review marks are stored in the repository's own Git configuration, as `branch.<name>.spooky-*`. They move with a branch when it's renamed and are removed when it's deleted
- Repository settings are written to the repository's own Git configuration. Line wrapping and issue tracking use the keys `spooky.commitbodylimit`, `spooky.commitshowsguide`, `spooky.issuetrackertemplate`, and `spooky.issuenumberprefix`
- When a server repository has many untracked files, Spooky can turn on `core.untrackedCache`, `core.fsmonitor`, and the commit-graph in that repository on the server, only after you confirm

## Development

### Tests

```sh
swift test
```

- Tests use Swift Testing
- Tests that use Git run in temporary repositories and ignore the system and user Git configuration

Server tests are skipped by default. Running them requires a dedicated test server:

- A host alias `spooky-test` in `~/.ssh/config`
- Authentication with the key `~/.ssh/spooky-test_ed25519`
- Read and write access to `/Users/wgy/spooky-test/` on the server

Once it's set up, enable them explicitly:

```sh
# Connections, connection checks, recovery, and callbacks
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteConnectionTests

# SFTP, the local file cache, and server commits
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteWorkingCopyTests

# Server history, sync, force pushes, and cancellation
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteHistorySyncTests

# File operations, patches, and diff options
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteWorkingCopyFilesTests
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteDiffTests

# Stashes and the conflict wizard
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteStashTests
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteConflictTests

# File history, blame, and commit signing
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteFileViewsTests
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteCommitSigningTests

# History search, commit details, and the sidebar
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteHistorySearchTests
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteHistoryDetailsTests
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteSidebarTests

# Branch, tag, and remote management, rewriting history, and branches review
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteReferenceManagementTests
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteRewriteTests
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteBranchesReviewTests

# Reflog, undo, and redo
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteReflogUndoTests

# Listing folders, creating, searching, and cloning on the server
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteHostOperationsTests
```

Each run creates and removes its own subdirectory there, and doesn't change the SSH configuration, `known_hosts`, or global Git configuration on either machine.

Performance tests for large repositories are also skipped by default. They generate a temporary repository with 100,000 files and 50,000 commits, and check how long the first status takes to load and how much memory is used:

```sh
SPOOKY_PERFORMANCE_TESTS=1 swift test -c release -Xswiftc -enable-testing --filter PerformanceTests
```

## Contributing

- Before opening a pull request, use [mise](https://mise.jdx.dev) to run `mise run swift:lint`, `mise run build`, and `mise run test`, and make sure they all pass. CI runs the same checks on every pull request
- If you change the app, also launch it and check that your change works
- See [AGENTS.md](AGENTS.md) for branch names, commit messages, and other contribution guidelines (in Chinese)
- Before bringing in outside code, make sure its license is compatible with GPL-3.0

## License

Spooky is licensed under the [GNU General Public License v3.0](LICENSE).

### Third-party software

- [Sparkle](https://sparkle-project.org) 2.10.0, used for updates. Licensed under the MIT License; the license ships with the app as `Contents/Resources/Sparkle-LICENSE.txt`
- [highlight.js](https://highlightjs.org) 11.12.0, used for syntax coloring. Copyright (c) 2006, Ivan Sagalaev. Licensed under the BSD 3-Clause License; the full license is in [`Sources/Spooky/HighlightJS/LICENSE`](Sources/Spooky/HighlightJS/LICENSE) and ships with the app
