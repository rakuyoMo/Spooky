---
title: "Installer Spooky"
description: "Vérifiez la configuration requise, téléchargez Spooky, ouvrez-le pour la première fois, gardez-le à jour, choisissez sa langue et désinstallez-le."
---

Cette page vous accompagne du téléchargement de Spooky à sa première ouverture. Elle couvre aussi les mises à jour, la langue de l’interface et la suppression de Spooky.

## Configuration requise {#requirements}

- macOS 26 ou ultérieur
- Git 2.41 ou ultérieur

Spooky utilise le Git situé à `/usr/bin/git`, sauf si vous en choisissez un autre. Pour cela, ouvrez :ui[app.name > settings.title] (<kbd>⌘,</kbd>), cliquez sur :ui[settings.gitConfig] et choisissez un programme dans le menu :ui[settings.gitProgram]. Le menu liste les programmes Git assez récents que Spooky a trouvés. Choisissez :ui[settings.gitProgram.choose] pour en utiliser un qui se trouve ailleurs. La version minimale est indiquée sous le menu. Consultez [Binaire Git](/guide/settings/identity/#git-program).

:::note[Dépôts sur un serveur]
Le serveur a lui aussi besoin de Git 2.41 ou ultérieur. Spooky s’y connecte via SSH avec un alias d’hôte de `~/.ssh/config`. Le Git choisi dans les réglages ne s’applique qu’aux dépôts sur votre Mac. Les dépôts sur un serveur utilisent le Git du serveur. Consultez [Configuration requise](/reference/requirements/) et [Préparer SSH](/guide/server/prepare-ssh/).
:::

## Télécharger {#download}

1. Ouvrez la [page des versions de Spooky](https://github.com/rakuyoMo/Spooky/releases) sur GitHub.
2. Repérez la version stable la plus récente. Son nom est `v` suivi du numéro de version. Les noms qui se terminent par « (beta) » ou « (development) » sont des versions de test.
3. Téléchargez le fichier zip nommé `Spooky-` suivi du numéro de version.
4. Double-cliquez sur le fichier zip téléchargé pour le décompresser.
5. Faites glisser Spooky dans votre dossier **Applications**.

## Ouvrir Spooky pour la première fois {#first-launch}

Spooky n’est pas notarié par Apple. La première fois que vous l’ouvrez, macOS le bloque et affiche un avertissement. Pour l’ouvrir quand même :

1. Double-cliquez sur Spooky dans votre dossier **Applications**. Quand l’avertissement apparaît, fermez-le.
2. Choisissez **menu Pomme › Réglages Système**, puis cliquez sur **Confidentialité et sécurité** dans la barre latérale. Vous devrez peut-être faire défiler vers le bas.
3. Accédez à **Sécurité**, puis cliquez sur **Ouvrir quand même**. Le bouton reste disponible environ une heure après votre tentative d’ouverture de Spooky.
4. Saisissez votre mot de passe de session, puis cliquez sur **OK**.

macOS retient votre choix. Par la suite, Spooky s’ouvre normalement. Il démarre sur la fenêtre Dépôts. [Découvrir Spooky](/guide/start/tour/) explique ce que vous y voyez.

## Garder Spooky à jour {#updates}

Par défaut, Spooky recherche lui-même les mises à jour. :ui[app.name > updates.check] lance une recherche tout de suite.

Chaque mise à jour est signée. Spooky vérifie la signature avant d’installer une mise à jour. Si la vérification échoue, la mise à jour ne remplace pas la copie que vous avez.

Pour changer la façon dont Spooky se met à jour, ouvrez :ui[app.name > settings.title] et cliquez sur :ui[settings.updates] :

| Réglage | Ce qu’il fait |
|---|---|
| :ui[updates.channel] | Les versions que vous recevez. Consultez [Canaux de mise à jour](#channels). |
| :ui[updates.automaticChecks] | Recherche les mises à jour en arrière-plan. Activé par défaut. |
| :ui[updates.automaticDownloads] | Télécharge les mises à jour en arrière-plan et les installe quand vous quittez Spooky. Désactivé par défaut. Disponible seulement quand la recherche automatique est activée et que Spooky se trouve dans un dossier où vous pouvez écrire. |
| :ui[updates.interval] | La fréquence des recherches : :ui[updates.interval.hourly], :ui[updates.interval.daily] ou :ui[updates.interval.weekly]. Par défaut, chaque jour. Disponible seulement quand la recherche automatique est activée. |

La dernière ligne, :ui[updates.lastCheck], indique quand Spooky a cherché pour la dernière fois. S’il n’a pas encore cherché, elle affiche :ui[updates.never].

### Canaux de mise à jour {#channels}

| Canal | Vous recevez |
|---|---|
| :ui[updates.channel.stable] | Les versions stables. C’est le réglage par défaut. |
| :ui[updates.channel.beta] | Les versions stables et bêta |
| :ui[updates.channel.development] | Toutes les versions, y compris les versions de développement |

### Nouveautés {#whats-new}

La première fois que vous lancez une nouvelle version de Spooky, les fenêtres de dépôt affichent :ui[whatsNew.card.title] en bas de la barre latérale. Cliquez sur :ui[whatsNew.card.learnMore] pour lire ce qui a changé. Vous pouvez aussi simplement fermer la carte.

Pour lire ces notes plus tard, choisissez :ui[menu.help > help.whatsNew]. :ui[menu.help > help.releaseNotes] ouvre les versions sur GitHub.

## Choisir la langue de l’interface {#language}

Spooky existe en anglais, chinois simplifié, chinois traditionnel, japonais, coréen, allemand, français et espagnol. Il suit l’ordre des langues défini dans macOS. Si aucune de vos langues n’est disponible, il utilise l’anglais.

Pour utiliser une autre langue rien que pour Spooky :

1. Choisissez **menu Pomme › Réglages Système**, puis cliquez sur **Général** dans la barre latérale.
2. Cliquez sur **Langue et région**, puis accédez à **Applications**.
3. Cliquez sur le bouton **Ajouter**, choisissez Spooky et une langue, puis cliquez sur **Ajouter**.
4. Si Spooky est ouvert, quittez-le et rouvrez-le.

Pour revenir à la langue du système, sélectionnez Spooky dans la même liste et cliquez sur le bouton **Supprimer**.

## Désinstaller {#uninstall}

1. Quittez Spooky avec :ui[app.name > menu.quit] (<kbd>⌘Q</kbd>).
2. Déplacez Spooky de votre dossier **Applications** vers la **Corbeille**.

Vos réglages et vos données restent sur votre Mac. Pour les supprimer aussi :

- Réglages : exécutez `defaults delete com.rakuyo.spooky` dans **Terminal**.
- Autres données, comme vos thèmes et les enregistrements d’activité : supprimez le dossier `~/Library/Application Support/Spooky/`.
- Caches : supprimez le dossier `~/Library/Caches/com.rakuyo.spooky/`, ainsi que les éléments de `~/Library/HTTPStorages/` dont le nom commence par `com.rakuyo.spooky`.
- Mots de passe et jetons enregistrés par Spooky : supprimez les éléments de votre trousseau dont le nom commence par `com.rakuyo.spooky.`.
- Sur chaque serveur utilisé : supprimez-y le dossier `~/.spooky/` de votre dossier de départ.

Les dépôts conservent les entrées `branch.<name>.spooky-*` que Spooky a ajoutées à leur configuration Git. [Données et confidentialité](/reference/data-privacy/) liste ce que Spooky stocke et à quel endroit.

## Voir aussi

- [Découvrir Spooky](/guide/start/tour/)
- [Configuration requise](/reference/requirements/)
- [Données et confidentialité](/reference/data-privacy/)
