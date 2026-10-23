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

- **Local and server repositories**: both kinds share the same interface, and recent repositories appear in one list. Server repositories show the host in their title, recent entry, and copied path

- **Connection checks and recovery**: before adding a server repository, Spooky checks the connection, the Git version, and the server environment. If the connection drops, the last snapshot stays on screen while Spooky reconnects in the background. Writes are disabled until the connection recovers

- **Automatic refresh**: local repositories refresh when files change. Server repositories refresh every 2 seconds in the foreground and every 10 seconds in the background. You can also refresh at any time

- **Per-repository view state**: each window remembers the view, selection, and commit message draft of up to 15 repositories, and restores them when you switch back

- **Clear errors**: errors show their category, the repository, and the original Git or SSH output, which you can select and copy

- **Stage files, hunks, or lines**: view the working copy as a list or a tree, with multiple selection and three-state checkboxes. Select lines in a diff to stage or discard just those lines

- **Commits and conflicts**: amend the most recent commit. During a merge, rebase, cherry-pick, or revert, resolve files using ours or theirs, mark them as resolved, then continue or abort

- **History**: commits load page by page, with a commit graph, ref badges, and ahead and behind counts. Merge commits show their diff against the first parent

- **Branches**: create, track, check out, and delete branches. Branch names are converted into valid ref names as you type

- **Sync and merge**: fetch, pull, push, and publish branches. Merges are previewed for conflicts first. Every operation is logged in the **Activity** window, and running operations can be cancelled

- **Drag and drop**: drag branches or commits in the sidebar to create branches, merge, pull, publish, or push

- **Open in Terminal**: supports Terminal, iTerm, Warp, Ghostty, WezTerm, Prompt, and Otty. For a server repository, the terminal connects over SSH and opens the remote path

- **Default themes**: Default and Default (Dark) are built in and follow your Mac's light or dark appearance

- **Eight languages**: English, Simplified Chinese, Traditional Chinese, Japanese, Korean, German, French, and Spanish. The app uses your system language, or English if that language isn't supported

## Requirements

- macOS 26 or later
- Git `2.41.0` or later on both your Mac and your servers, as Spooky uses `git fetch --porcelain`
  - Local repositories use `/usr/bin/git`. If it's too old, Spooky asks you to update Xcode or the Command Line Tools
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
swift build --package-path SpookyKit

# Launch the app
swift run --package-path SpookyKit Spooky
```

You can also build a development app that opens from Finder:

```sh
# Build SpookyKit/.build/Spooky.app
./scripts/build-app.sh

# Launch the built app
open SpookyKit/.build/Spooky.app
```

The release app uses a release build, includes the app icon, and is ad-hoc signed:

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
- Polling reads only the status and the selected file's content hash, and reads everything else only when something changed. History pages and commit details, which depend only on commit hashes, are cached to save round trips

### Writes and disconnections

- Writes to the same repository run one at a time. Only one window can start a write to a repository at a time, and every window showing the repository refreshes when the write finishes
- If the connection drops during a write, Spooky doesn't retry it. After reconnecting, it checks the branch, working copy, index lock, and any merge or rebase in progress, tells you whether HEAD changed, and only then allows writes again
- To cancel an operation on a server, Spooky closes the command channel, then ends the remote process group: it sends TERM, waits 2 seconds, sends KILL, and confirms that the processes have exited
  - If it can't confirm this, Spooky says so and blocks writes until a reconnection check

### Credentials

- When Git on the server needs a password, an SSH private key passphrase, or an editor, the request comes back to your Mac through a reverse Unix socket on the current master connection, and Spooky shows a dialog
  - Each request carries a random session token, can be answered only once, and times out after 120 seconds
- Network operations in local repositories also ask for credentials through a private Unix socket callback. After an SSH private key is unlocked, OpenSSH adds it to the current SSH agent
- Credentials stay in memory by default. They're written to your Mac's Keychain only when you select **Save in this Mac’s Keychain**
- Credentials are never written to temporary files, activity logs, or error messages, and credentials echoed in output are hidden

### Data and system changes

On your Mac:

- Settings and recent repositories are stored in the preferences domain `com.rakuyo.spooky`
- Credentials saved to the Keychain use the service name `com.rakuyo.spooky.remote.<host alias>`
- Connections and callbacks use private `/tmp/spooky-*` temporary directories, which are removed when the session closes
- Opening a server repository in Warp writes `Spooky-*.yaml` to `~/.warp/launch_configurations/`, and opening it in Prompt uses a temporary `.command` file. When Spooky quits, it removes only the files it created

On the server:

- `~/.spooky/bin/`: the remote helper and askpass entry points, with `0700` permissions. They stay after the session ends so later connections can use them
- `/tmp/spooky-*`: a private runtime directory for the session, removed when the session closes

## Development

### Tests

```sh
swift test --package-path SpookyKit
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
SPOOKY_REMOTE_TESTS=1 swift test --package-path SpookyKit --filter RemoteConnectionTests

# SFTP and server commits
SPOOKY_REMOTE_TESTS=1 swift test --package-path SpookyKit --filter RemoteWorkingCopyTests

# Server history, sync, and cancellation
SPOOKY_REMOTE_TESTS=1 swift test --package-path SpookyKit --filter RemoteHistorySyncTests
```

Each run creates and removes its own subdirectory there, and doesn't change the SSH configuration, `known_hosts`, or global Git configuration on either machine.

Performance tests for large repositories are also skipped by default. They generate a temporary repository with 100,000 files and 50,000 commits, and check how long the first status takes to load and how much memory is used:

```sh
SPOOKY_PERFORMANCE_TESTS=1 swift test --package-path SpookyKit -c release -Xswiftc -enable-testing --filter PerformanceTests
```

## Contributing

- Before opening a pull request, use [mise](https://mise.jdx.dev) to run `mise run swift:lint`, `mise run build`, and `mise run test`, and make sure they all pass. CI runs the same checks on every pull request
- If you change the app, also launch it and check that your change works
- See [AGENTS.md](AGENTS.md) for branch names, commit messages, and other contribution guidelines (in Chinese)
- Before bringing in outside code, make sure its license is compatible with GPL-3.0

## License

Spooky is licensed under the [GNU General Public License v3.0](LICENSE).
