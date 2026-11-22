---
title: "Comptes d’hébergement"
description: "Connectez des comptes GitHub, GitLab.com et GitLab autogéré, et découvrez où leurs jetons sont stockés et à quoi ils servent."
---

Ajoutez votre compte GitHub ou GitLab pour travailler avec les pull requests et les merge requests dans Spooky. Git utilise aussi le compte pour se connecter aux dépôts distants HTTPS de ce service : on ne vous demande donc ni nom d’utilisateur ni mot de passe.

## Ajouter un compte {#add}

Ouvrez :ui[app.name > settings.title] et cliquez sur :ui[settings.accounts]. Cliquez sur le bouton d’ajout sous la liste, puis choisissez où se trouve le compte :

| Choisissez | Pour | Connexion avec |
|---|---|---|
| :ui[accounts.add.github] | github.com | Votre navigateur, ou un jeton d’accès personnel |
| :ui[accounts.add.gitlab] | GitLab.com | Un jeton d’accès personnel |
| :ui[accounts.add.gitlabSelfManaged] | GitLab sur votre propre serveur | Un jeton d’accès personnel, ou un nom d’utilisateur et un mot de passe |

::screenshot[La feuille d’ajout d’un compte GitLab autogéré. L’hôte est https://gitlab.example.com, et la méthode d’authentification est le nom d’utilisateur et le mot de passe.]{name="hosting-add-account" frame="dialog" markers="79.2,64.1 83.3,56.3"}

1. L’hôte
2. La méthode d’authentification

Pendant que Spooky vérifie le compte, :ui[accounts.validating] s’affiche en bas de la zone de dialogue. :ui[action.cancel] arrête la vérification et laisse la zone de dialogue ouverte, pour que vous puissiez corriger votre saisie. Si la vérification échoue, un message indique pourquoi, et votre saisie est conservée.

Chaque compte apparaît dans la liste avec son service, son instance et son nom d’utilisateur. Vous pouvez ajouter plusieurs comptes sur le même service.

### GitHub {#github}

Avec :ui[accounts.authentication.oauth] choisi à côté de :ui[accounts.authentication], cliquez sur :ui[accounts.add.submit] :

1. Spooky affiche un code à usage unique, le copie et ouvre GitHub dans votre navigateur.
2. Collez-y le code et autorisez Spooky. Si vous avez copié autre chose entre-temps, cliquez sur :ui[accounts.copyCode] pour le copier de nouveau.
3. Une fois Spooky autorisé, la zone de dialogue se ferme et le compte figure dans la liste.

Si le code expire ou si vous refusez l’accès dans le navigateur, recommencez pour obtenir un nouveau code.

Pour utiliser un jeton à la place, choisissez :ui[accounts.authentication.token] à côté de :ui[accounts.authentication]. Le jeton doit avoir les portées `repo` et `read:org`.

### GitLab.com {#gitlab-com}

Collez un jeton d’accès personnel avec la portée `api`.

### GitLab autogéré {#self-managed}

À côté de :ui[accounts.host], saisissez l’adresse de votre serveur GitLab. Ajoutez son port et son chemin s’il en a, par exemple `https://example.com:8443/gitlab`. Choisissez ensuite comment vous connecter :

- :ui[accounts.authentication.token] : un jeton avec la portée `api`.
- :ui[accounts.authentication.password] : Spooky n’utilise le mot de passe que pour obtenir un jeton, et ne l’enregistre pas.

La connexion avec un nom d’utilisateur et un mot de passe ne fonctionne que si toutes ces conditions sont réunies :

- Le serveur exécute GitLab 18.11 ou antérieur. GitLab 19.0 et les versions suivantes n’échangent plus un mot de passe contre un jeton.
- Le serveur n’exige pas d’identifiants d’application OAuth. GitLab 13.9 les exige toujours, et GitLab 17.8 ou ultérieur peut être réglé pour les exiger.
- Le serveur autorise Git via HTTPS avec un mot de passe.
- Votre compte a un mot de passe GitLab ou LDAP, n’utilise pas l’authentification à deux facteurs et ne se connecte pas uniquement par authentification unique.

Le jeton obtenu de cette façon expire, et Spooky le renouvelle tout seul. Si GitLab cesse de le renouveler, le compte est marqué comme nécessitant une réauthentification.

Spooky nécessite GitLab 9.0 ou ultérieur. Le serveur doit être accessible depuis votre Mac, et votre Mac doit faire confiance à son certificat. Si ce n’est pas le cas, approuvez le certificat dans **Trousseaux d’accès**.

## Gérer les comptes {#manage}

Toutes les fenêtres partagent les mêmes comptes. Dans :ui[app.name > settings.title] › :ui[settings.accounts] :

- Pour réauthentifier un compte, sélectionnez-le et cliquez sur :ui[accounts.reauthenticate] sous la liste. Connectez-vous de nouveau ou saisissez un nouveau jeton. Il doit s’agir du même utilisateur. Pour vous connecter sous une autre identité, ajoutez un nouveau compte.
- Pour retirer un compte, sélectionnez-le, cliquez sur le bouton de suppression sous la liste, puis confirmez. Spooky supprime son jeton de votre trousseau.

Un compte marqué :ui[accounts.needsReauthentication] a un jeton que le service n’accepte plus, par exemple parce qu’il a expiré ou a été révoqué. Réauthentifiez-le pour l’utiliser de nouveau.

Spooky prend le changement en compte tout de suite. Une liste de pull requests ou de merge requests ouverte se recharge sans qu’il faille rouvrir la fenêtre.

## À quoi servent les comptes {#uses}

Un compte fonctionne avec les dépôts distants de son service :

- La liste des [pull requests et merge requests](/guide/hosting/pull-requests/)
- Les numéros de tickets après `#` dans les messages de commit. Consultez [Saisie semi-automatique](/guide/work/commit/#autocomplete).
- L’état des pull requests et merge requests dans la [revue des branches](/guide/branches/review/)
- La [publication d’un dépôt](#publish) sur le service
- La [connexion aux dépôts distants HTTPS](#git)

## Quel compte un dépôt distant utilise {#remotes}

Spooky compare l’adresse de chaque dépôt distant à l’instance de chaque compte : github.com, GitLab.com ou votre propre serveur GitLab.

- **Un seul compte sur cette instance** : Spooky l’utilise.
- **Plusieurs comptes sur cette instance** : la liste des pull requests vous demande d’en choisir un. Spooky retient votre choix pour ce dépôt distant.
- **Pas encore de compte** : pour github.com et GitLab.com, la liste l’indique et propose :ui[pullRequests.openAccounts].
- **L’adresse ne correspond pas** : par exemple, quand le dépôt distant utilise un alias d’hôte de `~/.ssh/config`. La liste affiche une note avec un bouton :ui[pullRequests.associate]. Si le dépôt distant appartient à l’un de vos comptes, cliquez dessus et choisissez le compte et le projet.

Les adresses HTTPS et SSH d’un même projet correspondent au même compte.

## Se connecter aux dépôts distants HTTPS {#git}

Quand un dépôt distant HTTPS appartient à l’un de vos comptes, Git se connecte avec le jeton du compte. Cela vaut pour le clonage, la récupération, le tirage, la poussée et la récupération automatique.

- Les dépôts distants SSH continuent d’utiliser vos clés SSH. Les comptes n’y changent rien.
- Pour ces adresses, Spooky répond à la place de tout assistant d’identification que vous avez configuré pour Git, comme celui du trousseau macOS. Ces assistants ne voient pas le jeton et ne le stockent pas.
- Si vous avez plusieurs comptes sur la même instance et n’en avez pas choisi pour le dépôt distant, Git vous demande un nom d’utilisateur et un mot de passe comme d’habitude.

Si Git rejette le jeton, la commande échoue. Ensuite, Git vous demande un nom d’utilisateur et un mot de passe pour les dépôts distants de ce compte, et la zone de dialogue indique que le jeton du compte n’a pas été accepté. Réauthentifiez le compte pour vous connecter de nouveau avec lui.

:::note[Dépôts sur un serveur]
Git sur le serveur se connecte aussi avec le jeton. Il l’obtient de Spooky, sur votre Mac, chaque fois qu’il en a besoin. Le jeton n’est pas enregistré sur le serveur.
:::

## Où les jetons sont stockés {#storage}

- La liste des comptes se trouve dans les préférences de Spooky, sans les jetons.
- Les jetons se trouvent dans votre trousseau, dans des éléments nommés `com.rakuyo.spooky.hosting.<address>`.
- Si vous vous connectez à un GitLab autogéré avec un nom d’utilisateur et un mot de passe, Spooky garde les jetons qu’il obtient en échange. Il ne garde pas le mot de passe.

Les jetons n’apparaissent ni dans les entrées de :ui[activity.title] ni dans les journaux de Spooky.

## Où vont les requêtes {#network}

Spooky communique avec le service depuis votre Mac, même pour les dépôts sur un serveur :

- GitHub : `github.com` pendant que vous autorisez l’accès dans le navigateur, et `api.github.com` pour tout le reste.
- GitLab : `gitlab.com`, ou l’adresse de votre propre GitLab.

Il le fait quand vous ajoutez ou réauthentifiez un compte, et quand vous utilisez ce à quoi sert le compte : la liste des pull requests et merge requests et ce que vous y faites, les numéros de tickets après `#`, l’état dans la revue des branches et la publication d’un dépôt. Les comptes connectés avec un nom d’utilisateur et un mot de passe y renouvellent aussi leurs jetons.

Chacune de ces requêtes apparaît sur la page :ui[activity.service] de la fenêtre :ui[activity.title].

Les photos des utilisateurs GitHub et GitLab viennent des adresses que ces services fournissent. Les photos téléchargées restent uniquement en mémoire et disparaissent quand vous quittez Spooky.

Git lui-même se connecte au dépôt distant depuis l’endroit où se trouve le dépôt. Pour un dépôt sur un serveur, c’est le serveur. Consultez [Données et confidentialité](/reference/data-privacy/#network).

## Publier un dépôt {#publish}

Pour créer un dépôt sur GitHub ou GitLab à partir de celui qui est ouvert, choisissez :ui[menu.repository > publish.menu] dans la barre des menus. Vous pouvez aussi cliquer avec le bouton droit sur :ui[workspace.title] dans la barre latérale et choisir :ui[workspace.publishMenu] dans le menu. Si le dépôt n’a pas encore de dépôt distant, :ui[sync.push] ouvre aussi cette zone de dialogue. Il vous faut au moins un compte.

| Champ | Ce qu’il fait |
|---|---|
| :ui[publish.remote] | Le nom du nouveau dépôt distant. Au début, c’est `origin`, ou `origin-2` si le dépôt a déjà un `origin`. |
| :ui[pullRequests.account] | Où créer le dépôt : sous votre propre utilisateur, ou dans une organisation ou un groupe dont vous faites partie |
| :ui[publish.name] | Le nom sur le service. Au début, c’est le nom du dossier du dépôt. |
| :ui[pullRequests.description] | Facultatif |
| :ui[publish.visibility] | :ui[publish.visibility.private] ou :ui[publish.visibility.public]. GitLab propose aussi :ui[publish.visibility.internal]. |
| :ui[publish.target] | L’adresse HTTPS que le dépôt distant utilisera |

Quand vous cliquez sur :ui[publish.submit], Spooky :

1. Crée un dépôt vide sur le service.
2. L’ajoute comme dépôt distant, avec l’adresse HTTPS.
3. Y pousse toutes les branches locales et tous les tags. Les branches sans branche amont se mettent à suivre leur nouvelle branche distante. Celles qui en ont déjà une la gardent.

Si un dépôt de ce nom existe déjà, Spooky l’indique et ne l’écrase pas. Choisissez un autre nom. Si la poussée échoue, le nouveau dépôt distant et le dépôt sur le service restent tous les deux : vous pouvez pousser de nouveau.

La publication ne peut pas être annulée avec <kbd>⌘Z</kbd>, et les opérations qui la précèdent ne peuvent plus l’être non plus.

## Voir aussi

- [Pull requests et merge requests](/guide/hosting/pull-requests/)
- [Demandes de mot de passe et de phrase secrète](/guide/server/connection/#prompts)
- [Données et confidentialité](/reference/data-privacy/)
