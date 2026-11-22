---
title: "Données et confidentialité"
description: "Découvrez ce que Spooky stocke et où, à quelles adresses réseau il se connecte, et ce que contiennent les rapports de plantage et de diagnostic."
---

Il n’existe pas de compte Spooky, et Spooky ne collecte aucune donnée d’utilisation. Cette page liste ce qu’il stocke, où il le stocke, et à quelles adresses il se connecte.

## Sur votre Mac {#mac}

| Quoi | Où |
|---|---|
| Les réglages, la liste des dépôts, les profils utilisateur, la liste des comptes d’hébergement et les emplacements sur ce Mac des dépôts sur un serveur | Les préférences de Spooky, `com.rakuyo.spooky` |
| Les thèmes, un fichier `.spookytheme` chacun | `~/Library/Application Support/Spooky/Themes/` |
| De petits dossiers `.spookyrepo` grâce auxquels les dépôts sur un serveur apparaissent parmi les documents récents | `~/Library/Application Support/Spooky/Locations/` |
| Les entrées des opérations distantes dans :ui[activity.title], comme récupérer, tirer et pousser, conservées 7 jours | `~/Library/Application Support/Spooky/Activity/` |
| La référence à laquelle :ui[activity.title] se compare pour compter les modifications, un fichier par dépôt | `~/Library/Application Support/Spooky/Baselines/` |
| Les noms d’utilisateur et mots de passe que vous avez enregistrés pour Git sur un serveur | Le trousseau, dans des éléments nommés `com.rakuyo.spooky.remote.<host alias>` |
| Les jetons des comptes d’hébergement | Le trousseau, dans des éléments nommés `com.rakuyo.spooky.hosting.<address>` |
| Les caches et cookies que macOS conserve pour les requêtes réseau de Spooky | `~/Library/Caches/com.rakuyo.spooky/`, et les éléments de `~/Library/HTTPStorages/` dont le nom commence par `com.rakuyo.spooky` |
| Les fichiers de connexion des dépôts sur un serveur | Des dossiers `/tmp/spooky-*`, supprimés à la fermeture de la connexion |
| Les copies des fichiers que vous ouvrez dans Coup d’œil ou dans d’autres apps | Des dossiers temporaires `spooky-files-*`, supprimés à la fermeture du dépôt |

Si vous vous connectez à un GitLab autogéré avec un nom d’utilisateur et un mot de passe, Spooky garde les jetons qu’il obtient en échange. Il ne garde pas le mot de passe.

Pour supprimer tout cela, consultez [Désinstaller](/guide/start/install/#uninstall).

## Sur les serveurs {#servers}

En plus du dépôt lui-même, Spooky écrit à deux endroits sur un serveur :

- `~/.spooky/bin/` dans votre dossier de départ : un petit script que Spooky exécute via SSH, ainsi que des liens vers lui pour les demandes et la signature. Il y reste pour la prochaine connexion. Supprimez le dossier pour l’enlever.
- `/tmp/spooky-*` : les fichiers de la connexion en cours. Ils sont supprimés à la fermeture de la connexion.

Quand Spooky cherche l’[emplacement sur ce Mac](/guide/server/local-location/#automatic) d’un dépôt, il place brièvement un fichier vide dans le dossier Git du dépôt. Il supprime le fichier juste après la vérification.

Quand Git sur un serveur demande un mot de passe, Spooky envoie la réponse depuis votre Mac par la connexion SSH, uniquement à la commande Git qui l’a demandée. Git sur le serveur ne l’enregistre pas, car Spooky désactive les assistants d’identification de Git pour ses commandes.

## Dans les dépôts {#repositories}

Spooky enregistre quelques informations dans la configuration Git du dépôt lui-même, sous forme d’entrées `branch.<name>.spooky-*` :

- Les branches épinglées ou archivées
- La branche parente de chaque branche
- Les marques utilisées pour l’archivage automatique

Ces entrées suivent une branche quand vous la renommez, et disparaissent quand vous la supprimez. Les réglages Git que vous modifiez dans les :ui[repositorySettings.title] du dépôt, comme la signature, vont dans la même configuration. Consultez [Réglages du dépôt](/guide/settings/identity/#repository).

La configuration Git n’est pas poussée : rien de tout cela n’atteint vos dépôts distants. Pour un dépôt sur un serveur, elle est stockée sur le serveur.

## Connexions réseau {#network}

| Spooky se connecte à | Quand |
|---|---|
| Vos serveurs, via SSH | Tant qu’un dépôt sur un serveur est ouvert. Spooky utilise l’alias d’hôte de `~/.ssh/config`. Un montage SMB se connecte aussi au partage de fichiers du serveur. |
| Vos dépôts distants Git | Quand vous récupérez, tirez, poussez ou clonez, et pendant la récupération automatique. Pour un dépôt sur un serveur, Git se connecte depuis le serveur, pas depuis votre Mac. |
| `github.com` et `api.github.com`, ou l’adresse de votre GitLab | Quand vous ajoutez ou réauthentifiez un compte d’hébergement, et quand vous utilisez une fonction qui en a besoin : les pull requests et merge requests, la complétion des numéros de tickets, l’état dans la revue des branches et la publication d’un dépôt. Ces requêtes partent de votre Mac. Consultez [Où vont les requêtes](/guide/hosting/accounts/#network). |
| `gravatar.com` | Pour afficher les photos des auteurs de commits |
| `github.com`, pour les versions de Spooky | Pour rechercher les mises à jour |

La récupération automatique a lieu toutes les 30 minutes par défaut. Pour changer cela, ouvrez :ui[app.name > settings.title], cliquez sur :ui[settings.general], puis choisissez une option à côté de :ui[settings.autoFetch]. Choisissez :ui[settings.autoFetch.never] pour ne récupérer que sur demande. Consultez [Opérations](/guide/settings/general/#operations).

Pour la photo de l’auteur d’un commit, Gravatar reçoit un hash de l’adresse e-mail de l’auteur, pas l’adresse elle-même. Les photos téléchargées restent uniquement en mémoire et disparaissent quand vous quittez Spooky. Les photos des utilisateurs GitHub et GitLab viennent de ces services. Aucun réglage ne permet de désactiver les photos.

Spooky recherche les mises à jour une fois par jour par défaut. Pour l’en empêcher, désactivez :ui[updates.automaticChecks] dans :ui[app.name > settings.title] › :ui[settings.updates]. Consultez [Garder Spooky à jour](/guide/start/install/#updates).

Les éléments du menu :ui[menu.help], comme :ui[help.help] et :ui[help.support], ouvrent des pages web dans votre navigateur.

## Rapports de plantage {#crash-reports}

Si Spooky a quitté de manière inattendue la dernière fois, il lit le rapport de plantage que macOS a enregistré sur votre Mac. Au lancement suivant, il demande : :ui[crash.title].

- Cliquez sur :ui[crash.report] pour ouvrir dans votre navigateur une page de nouveau ticket sur GitHub, préremplie avec un résumé du plantage.
- Cliquez sur :ui[crash.dontReport] pour passer. Spooky ne pose plus la question pour ce plantage.

Le résumé contient la version et le build de Spooky, la version de macOS, le type de plantage et jusqu’à 30 lignes de la pile d’appels du thread qui a planté. Avant que le résumé quitte votre Mac, Spooky remplace par des substituts votre dossier de départ, votre nom d’utilisateur, les adresses e-mail, les adresses IP, les jetons et les mots de passe contenus dans les adresses web.

Le résumé fait partie de l’adresse web de la page. GitHub le reçoit dès que la page s’ouvre. Le ticket n’est créé que lorsque vous l’envoyez dans le navigateur. Vous pouvez d’abord modifier le texte, ou fermer la page.

Pour ne plus avoir la question la prochaine fois, sélectionnez :ui[settings.crashReports.always] dans la zone de dialogue. Spooky ouvre alors la page du ticket tout de suite. La même option se trouve dans :ui[app.name > settings.title] › :ui[settings.integration].

## Rapports de diagnostic {#diagnostic-reports}

Quand vous signalez un problème, un rapport de diagnostic aide à montrer ce qui s’est passé. Choisissez :ui[menu.help > help.diagnosticReport] et choisissez où l’enregistrer. Spooky enregistre un fichier texte et l’affiche dans le Finder. Il n’envoie le rapport nulle part.

Le rapport contient :

- La version et le build de Spooky, la version de macOS et vos trois premières langues préférées
- Le binaire Git de ce Mac et sa version
- Les réglages qui influent sur le fonctionnement de Spooky, comme l’apparence, le canal de mise à jour, l’app de terminal, les outils de comparaison et de fusion, l’agent SSH, le binaire Git, et la lecture ou non des variables d’environnement depuis le shell de connexion
- Le nombre de dépôts locaux et de dépôts sur un serveur que vous avez
- Les noms, heures et résultats des 20 dernières opérations
- Le journal de Spooky pour la dernière heure de la session en cours, jusqu’à 500 lignes

Il ne contient ni chemins de dépôts, ni alias d’hôte, ni mots de passe, ni valeurs de variables d’environnement. Spooky remplace par des substituts votre dossier de départ, votre nom d’utilisateur, les adresses e-mail, les adresses IP et les jetons, comme dans les rapports de plantage. Ouvrez le fichier et lisez-le avant de le partager.

Le journal de Spooky note les changements de connexion, ainsi que le début, la fin ou l’échec des opérations. Il n’enregistre ni les arguments ni la sortie des commandes, ni les messages de commit, ni les mots de passe, ni les jetons.

## Voir aussi

- [Installer Spooky](/guide/start/install/)
- [Fonctionnement des dépôts sur un serveur](/guide/server/overview/)
- [Comptes d’hébergement](/guide/hosting/accounts/)
- [Configuration requise](/reference/requirements/)
