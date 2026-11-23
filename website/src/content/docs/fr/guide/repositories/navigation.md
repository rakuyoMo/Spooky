---
title: "Fenêtres et navigation"
description: "Travaillez avec les fenêtres et les onglets, reculez et avancez, utilisez les Actions rapides, restaurez les fenêtres, utilisez le menu du Dock et ouvrez des liens spooky://."
---

Cette page parle des déplacements dans Spooky. Vous verrez comment garder plusieurs dépôts ouverts, passer d’une vue à l’autre, aller n’importe où avec les Actions rapides et reprendre là où vous vous étiez arrêté.

## Fenêtres et onglets {#windows}

Chaque fenêtre ou onglet affiche soit la vue Dépôts, soit un dépôt.

- :ui[menu.file > menu.newTab] (<kbd>⌘T</kbd>) ouvre un nouvel onglet avec la vue Dépôts. Le bouton d’ajout au bout de la barre d’onglets fait la même chose.
- :ui[menu.file > menu.newWindow] (<kbd>⌘N</kbd>) ouvre une nouvelle fenêtre avec la vue Dépôts.
- :ui[menu.view > menu.showRepositories] (<kbd>⌃⌘R</kbd>) affiche la vue Dépôts dans la fenêtre actuelle.

Si un dépôt est déjà ouvert, l’ouvrir à nouveau vous amène à la fenêtre qui l’affiche. Pour l’ouvrir quand même dans une seconde fenêtre, cliquez dessus avec le bouton droit dans la liste Dépôts et choisissez :ui[bookmarks.openNewWindow]{1="driftwood"}.

### Changer de vue {#views}

Le menu :ui[menu.view] permet de passer d’une vue du dépôt à l’autre :

| Raccourci | Élément de menu |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[stash.show] |
| <kbd>⌘4</kbd> | :ui[pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[review.show] |
| <kbd>⌘6</kbd> | :ui[reflog.show] |
| <kbd>⌘0</kbd> | :ui[history.showHead] |

:ui[menu.window > activity.title] (<kbd>⌃⌘0</kbd>) ouvre la fenêtre Activité. Elle liste ce que Spooky a exécuté et ce qu’il exécute en ce moment. Consultez [File d’attente et activité](/guide/advanced/queue-activity/).

## Reculer et avancer {#back-forward}

Chaque fenêtre retient les vues et les dépôts que vous avez visités, y compris la vue Dépôts. Pour revenir sur vos pas :

- :ui[menu.view > navigation.back] (<kbd>⌘[</kbd>) ou :ui[toolbar.previous] dans la barre d’outils
- :ui[menu.view > navigation.forward] (<kbd>⌘]</kbd>) ou :ui[toolbar.next] dans la barre d’outils

Si vous reculez puis ouvrez autre chose, les endroits vers lesquels vous pouviez avancer sont oubliés.

## Actions rapides {#quick-actions}

Les Actions rapides vous permettent de trouver quelque chose en tapant, puis d’agir dessus sans quitter le clavier. Elles sont disponibles tant qu’un dépôt est affiché. Choisissez :ui[menu.file > quickActions.menu] (<kbd>⇧⌘A</kbd>).

::screenshot[Les Actions rapides ouvertes par-dessus une fenêtre de dépôt, avec « dark » saisi. Le premier résultat, la branche feature/dark-mode, est sélectionné et affiche son action par défaut ainsi que l’indication pour plus d’actions. En dessous figurent la branche distante origin/feature/dark-mode, l’apparence Sombre, le thème Default (Dark) et deux commits dont le message mentionne dark.]{name="quick-actions" frame="window"}

Si rien n’est saisi, le panneau liste les vues du dépôt, puis les branches (la branche actuelle en premier), les worktrees, les dépôts distants, les sous-modules, les branches distantes, les tags, les remisages, les profils utilisateur, et enfin les apparences et les thèmes. La liste se resserre à mesure que vous tapez. Spooky cherche aussi :

- les fichiers de la branche actuelle dont le nom correspond
- un commit, quand vous tapez de 5 à 64 caractères hexadécimaux de son hash
- les commits de la branche actuelle dont le message contient le texte, 100 au maximum

Les fichiers et les commits apparaissent à la fin de la liste un instant après que vous avez cessé de taper.

Utilisez ces touches dans le panneau :

| Touche | Ce qu’elle fait |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Déplace la sélection |
| <kbd>↩</kbd> | Lance l’action par défaut de l’élément sélectionné |
| <kbd>Tab</kbd>, ou <kbd>→</kbd> à la fin du texte | Liste toutes les actions de l’élément sélectionné |
| <kbd>←</kbd> sans texte, ou <kbd>⇧Tab</kbd> | Quitte la liste des actions |
| <kbd>Esc</kbd> | Efface le texte ; sans texte, quitte la liste des actions ou ferme le panneau |

Seules les actions que vous pouvez lancer à ce moment-là sont listées.

## Reprendre là où vous vous étiez arrêté {#restore}

:ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.windowRestoration] décide de ce que Spooky affiche au démarrage :

| Choix | Au démarrage de Spooky |
|---|---|
| :ui[settings.windowRestoration.always] | Rouvre vos fenêtres et vos onglets, chacun avec le dépôt et la vue qu’il affichait quand vous avez quitté |
| :ui[settings.windowRestoration.never] | Affiche seulement la fenêtre Dépôts |
| :ui[settings.windowRestoration.system] | Suit le réglage de macOS sur la conservation des fenêtres à la fermeture d’une app. C’est le réglage par défaut. |

Si un dépôt restauré est devenu introuvable, sa fenêtre le signale. Consultez [Dépôts introuvables](/guide/repositories/manager/#missing).

Activez :ui[settings.showLaunchWindow] pour obtenir au démarrage une fenêtre qui liste vos dépôts récents. Double-cliquez sur l’un d’eux, ou sélectionnez-le et appuyez sur <kbd>↩</kbd>, pour l’ouvrir. La fenêtre se ferme d’elle-même dès qu’une fenêtre de dépôt passe au premier plan. Consultez [Fenêtres et liste Dépôts](/guide/settings/general/#windows) pour ces deux réglages.

:::note[Dépôts sur un serveur]
Les dépôts sur un serveur restaurés se reconnectent à leur serveur au démarrage de Spooky.
:::

## Dépôts récents et Dock {#recent}

:ui[menu.file > menu.openRecent] liste les dépôts ouverts récemment, sur votre Mac et sur des serveurs. :ui[menu.clearRecent], en bas, vide la liste. Vos signets de la fenêtre Dépôts sont conservés.

Cliquez avec le bouton droit sur l’icône de Spooky dans le **Dock** pour obtenir un menu avec :ui[menu.newWindow] et vos dépôts récents. Choisissez un dépôt pour l’ouvrir. Cela fonctionne même quand Spooky n’est pas encore lancé.

Vous pouvez aussi déposer un dossier sur l’icône de Spooky dans le Dock pour ouvrir le dépôt dont il fait partie. Si le dossier ne fait pas partie d’un dépôt Git, Spooky propose d’en créer un.

## Ouvrir Spooky depuis un lien {#links}

Un lien qui commence par `spooky://` ouvre un dépôt ou un clonage. Vous pouvez placer ces liens dans d’autres apps, des scripts ou des notes.

### Ouvrir un dépôt {#link-open}

```
spooky://open?repository=<repository>&view=<view>
```

- `repository` est obligatoire. C’est le chemin absolu du dépôt sur votre Mac, ou `alias:path` pour un dépôt sur un serveur, encodé pour une URL.
- `view` est facultatif. Sans lui, le dépôt s’ouvre dans la vue qu’il affichait en dernier.
- Deux raccourcis remplacent `view` : `branch=<name>` ouvre l’historique de cette branche, et `commit=<hash>` ouvre ce commit.

| `view` | Ouvre | Paramètres supplémentaires |
|---|---|---|
| `workingCopy` | La copie de travail | |
| `history` | L’historique | `ref=<reference>`, un nom de référence complet comme `refs/heads/main` ; peut être répété |
| `commit` | Un commit | `commit=<hash>` |
| `stashes` | Les remisages | |
| `reflog` | Le reflog | |
| `pullRequests` | Les pull requests ou merge requests | |
| `branchesReview` | La revue des branches | |
| `settings` | Les réglages du dépôt | |
| `remote` | Un dépôt distant | `remote=<name>` |
| `submodule` | Un sous-module | `path=<path>` |
| `worktree` | Un worktree | `path=<path>` |
| `fileHistory` | L’historique d’un fichier | `path=<path>` |
| `file` | Un fichier | `path=<path>`, et éventuellement `revision=<revision>` et `mode=blame` ou `mode=raw` |

Par exemple, ce lien ouvre l’historique de la branche `main` dans le dépôt situé à `/Volumes/Projects/driftwood` :

```
spooky://open?repository=%2FVolumes%2FProjects%2Fdriftwood&branch=main
```

### Cloner un dépôt {#link-clone}

```
spooky://clone?url=<address>
```

Ce lien ouvre la zone de dialogue de clonage avec l’adresse renseignée. Rien n’est cloné tant que vous n’avez pas choisi la destination et cliqué sur :ui[clone.submit]. Consultez [Cloner un dépôt](/guide/repositories/manager/#clone).

Réglez :ui[app.name > settings.title] › :ui[settings.integration] › :ui[settings.github] sur Spooky, et les liens de github.com qui ouvrent un dépôt dans une app de bureau ouvrent eux aussi cette zone de dialogue de clonage. Consultez [Liens depuis github.com](/guide/settings/integration/#github-links).

Certains liens sont inutilisables, par exemple un lien qui nomme une vue inconnue ou qui donne un chemin relatif. Dans ce cas, Spooky affiche :ui[link.invalid.title] et ne fait rien d’autre.

## Voir aussi

- [Découvrir Spooky](/guide/start/tour/)
- [La fenêtre Dépôts](/guide/repositories/manager/)
- [Raccourcis clavier](/reference/shortcuts/)
