---
title: "Hosting Accounts"
description: "Connect GitHub, GitLab.com, and self-managed GitLab accounts, and learn where their tokens are stored and what they are used for."
---

Add your GitHub or GitLab account to work with pull requests and merge requests in Spooky. Git also uses the account to sign in to HTTPS remotes on that service, so you aren’t asked for a user name and password.

## Add an account {#add}

Open :ui[app.name > settings.title] and click :ui[settings.accounts]. Click the add button below the list, and choose where the account is:

| Choose | For | Sign in with |
|---|---|---|
| :ui[accounts.add.github] | github.com | Your browser, or a personal access token |
| :ui[accounts.add.gitlab] | GitLab.com | A personal access token |
| :ui[accounts.add.gitlabSelfManaged] | GitLab on your own server | A personal access token, or a user name and password |

While Spooky checks the account, :ui[accounts.validating] shows at the bottom of the dialog. :ui[action.cancel] stops the check and leaves the dialog open, so you can fix what you entered. If the check fails, a message says why, and what you entered is still there.

Each account appears in the list with its service, instance, and user name. You can add more than one account on the same service.

### GitHub {#github}

With :ui[accounts.authentication.oauth] chosen next to :ui[accounts.authentication], click :ui[accounts.add.submit]:

1. Spooky shows a one-time code, copies it, and opens GitHub in your browser.
2. Paste the code there and authorize Spooky. If you’ve copied something else in the meantime, click :ui[accounts.copyCode] to copy it again.
3. Once you’ve authorized Spooky, the dialog closes and the account is in the list.

If the code expires or you deny access in the browser, start again to get a new code.

To use a token instead, choose :ui[accounts.authentication.token] next to :ui[accounts.authentication]. The token needs the `repo` and `read:org` scopes.

### GitLab.com {#gitlab-com}

Paste a personal access token with the `api` scope.

### Self-managed GitLab {#self-managed}

Next to :ui[accounts.host], enter the address of your GitLab server. Include its port and path if it has them, for example `https://example.com:8443/gitlab`. Then choose how to sign in:

- :ui[accounts.authentication.token]: a token with the `api` scope.
- :ui[accounts.authentication.password]: Spooky uses the password only to get a token, and doesn’t save the password.

Signing in with a user name and password works only when all of these are true:

- The server runs GitLab 18.11 or earlier. GitLab 19.0 and later don’t trade a password for a token anymore.
- The server doesn’t require OAuth application credentials. GitLab 13.9 always does, and GitLab 17.8 or later can be set to.
- The server allows Git over HTTPS with a password.
- Your account has a GitLab or LDAP password, and doesn’t use two-factor authentication or sign in only through single sign-on.

The token you get this way expires, and Spooky renews it on its own. If GitLab stops renewing it, the account is marked as needing re-authentication.

Spooky needs GitLab 9.0 or later. The server must be reachable from your Mac, and your Mac must trust its certificate. If it doesn’t, trust the certificate in **Keychain Access**.

## Manage accounts {#manage}

All windows share the same accounts. In :ui[app.name > settings.title] › :ui[settings.accounts]:

- To re-authenticate an account, select it and click :ui[accounts.reauthenticate] below the list. Sign in again or enter a new token. It has to be the same user. To sign in as someone else, add a new account.
- To remove an account, select it, click the remove button below the list, and confirm. Spooky deletes its token from your keychain.

An account marked :ui[accounts.needsReauthentication] has a token the service no longer accepts, for example because it expired or was revoked. Re-authenticate it to use it again.

Spooky picks up the change right away. An open pull request or merge request list loads again without reopening the window.

## What accounts are used for {#uses}

An account works with the remotes on its service:

- The [pull request and merge request](/guide/hosting/pull-requests/) list
- Issue numbers after `#` in commit messages. See [Autocomplete](/guide/work/commit/#autocomplete).
- Pull request and merge request status in [Branches Review](/guide/branches/review/)
- [Publishing a repository](#publish) to the service
- [Signing in to HTTPS remotes](#git)

## Which account a remote uses {#remotes}

Spooky matches each remote’s address against the instance of each account: github.com, GitLab.com, or your own GitLab server.

- **One account on that instance**: Spooky uses it.
- **Several accounts on that instance**: the pull request list asks you to choose one. Spooky remembers your choice for that remote.
- **No account yet**: for github.com and GitLab.com, the list says so and offers :ui[pullRequests.openAccounts].
- **The address doesn’t match**: for example, when the remote uses a host alias from `~/.ssh/config`. The list shows a note with an :ui[pullRequests.associate] button. If the remote belongs to one of your accounts, click it and choose the account and the project.

HTTPS and SSH addresses of the same project match the same account.

## Sign in to HTTPS remotes {#git}

When an HTTPS remote belongs to one of your accounts, Git signs in with the account’s token. That covers cloning, fetching, pulling, pushing, and automatic fetch.

- SSH remotes keep using your SSH keys. Accounts don’t change them.
- For these addresses, Spooky answers in place of any credential helper you’ve set up for Git, such as the macOS keychain helper. Those helpers don’t see or store the token.
- If you have several accounts on the same instance and haven’t chosen one for the remote, Git asks you for a user name and password as usual.

If Git rejects the token, that command fails. After that, Git asks you for a user name and password on that account’s remotes, and the dialog says the account’s token wasn’t accepted. Re-authenticate the account to go back to signing in with it.

:::note[Server repositories]
Git on the server signs in with the token too. It gets the token from Spooky on your Mac each time it needs it. The token isn’t saved on the server.
:::

## Where tokens are stored {#storage}

- The list of accounts is in Spooky’s preferences, without the tokens.
- Tokens are in your keychain, in items named `com.rakuyo.spooky.hosting.<address>`.
- If you sign in to a self-managed GitLab with a user name and password, Spooky keeps the tokens it gets in return. It doesn’t keep the password.

Tokens don’t go into :ui[activity.title] records or Spooky’s logs.

## Where requests go {#network}

Spooky talks to the service from your Mac, even for server repositories:

- GitHub: `github.com` while you authorize in the browser, and `api.github.com` for everything else.
- GitLab: `gitlab.com`, or the address of your own GitLab.

It does this when you add or re-authenticate an account, and when you use what the account is for: the pull request and merge request list and what you do there, issue numbers after `#`, the status in Branches Review, and publishing a repository. Accounts signed in with a user name and password also renew their tokens there.

Each of these requests shows up on the :ui[activity.service] page of the :ui[activity.title] window.

Pictures of GitHub and GitLab users come from the addresses those services give. Downloaded pictures stay in memory only, and are gone when you quit Spooky.

Git itself connects to the remote from where the repository is. For a server repository, that’s the server. See [Data and Privacy](/reference/data-privacy/#network).

## Publish a repository {#publish}

To create a repository on GitHub or GitLab from the one you have open, choose :ui[menu.repository > publish.menu] in the menu bar. You can also right-click :ui[workspace.title] in the sidebar and choose :ui[workspace.publishMenu] from the menu. If the repository has no remote yet, :ui[sync.push] opens this dialog too. You need at least one account.

| Field | What it does |
|---|---|
| :ui[publish.remote] | The name of the new remote. It starts as `origin`, or `origin-2` if the repository already has an `origin`. |
| :ui[pullRequests.account] | Where to create the repository: under your own user, or an organization or group you belong to |
| :ui[publish.name] | The name on the service. It starts as the name of the repository’s folder. |
| :ui[pullRequests.description] | Optional |
| :ui[publish.visibility] | :ui[publish.visibility.private] or :ui[publish.visibility.public]. GitLab also has :ui[publish.visibility.internal]. |
| :ui[publish.target] | The HTTPS address that the remote will use |

When you click :ui[publish.submit], Spooky:

1. Creates an empty repository on the service.
2. Adds it as a remote, with the HTTPS address.
3. Pushes all local branches and tags to it. Branches without an upstream start tracking their new remote branch. Branches that already have one keep it.

If a repository with that name already exists, Spooky says so and doesn’t overwrite it. Choose another name. If the push fails, the new remote and the repository on the service both stay, so you can push again.

Publishing can’t be undone with <kbd>⌘Z</kbd>, and operations before it can’t be undone anymore either.

## See also

- [Pull Requests and Merge Requests](/guide/hosting/pull-requests/)
- [Password and passphrase prompts](/guide/server/connection/#prompts)
- [Data and Privacy](/reference/data-privacy/)
