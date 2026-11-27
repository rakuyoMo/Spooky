---
title: "Copie de travail"
description: "Lisez l’état de vos fichiers modifiés, affichez-les en liste ou en arborescence, triez-les et recherchez-les, gérez les fichiers non suivis et ignorés, et utilisez les actions sur les fichiers et Coup d’œil."
---

La copie de travail affiche ce que vous avez modifié depuis le dernier commit. C’est ici que vous choisissez les modifications du prochain commit, que vous examinez les fichiers et que vous tenez Git à l’écart des fichiers qu’il ne doit pas suivre.

Pour l’ouvrir, cliquez sur :ui[workspace.title] en haut de la barre latérale, ou choisissez :ui[menu.view > menu.showWorkingCopy] (<kbd>⌘1</kbd>). La zone de commit occupe le haut de la colonne du milieu, et les fichiers modifiés sont listés en dessous. [Valider des modifications](/guide/work/commit/) décrit la zone de commit.

## Lire l’état {#status}

Chaque fichier modifié a une ligne avec une case à cocher, deux pastilles d’état et son nom.

- La case à cocher indique si la modification est indexée. Un tiret signifie que seule une partie du fichier est indexée.
- La pastille de gauche correspond à la modification indexée. Celle de droite correspond à la modification qui n’est pas encore indexée.
- Les lettres sont les codes d’état de Git : M pour modifié, A pour ajouté, D pour supprimé et R pour renommé. Un nouveau fichier que Git ne suit pas encore affiche ?, et un fichier ignoré affiche !.
- Un fichier en conflit affiche deux codes de conflit, comme U U. Consultez [Résoudre les conflits](/guide/work/conflicts/).

Placez le pointeur sur les pastilles pour lire l’état en toutes lettres.

La ligne au-dessus de la liste affiche la branche actuelle, suivie de la branche distante qu’elle suit. Si elle n’en suit aucune, la ligne indique :ui[branch.noTracking].

Spooky met la liste à jour tout seul quand des fichiers changent. Pour tout relire, cliquez sur :ui[action.refresh] ou appuyez sur <kbd>⌘R</kbd>.

:::note[Dépôts sur un serveur]
Spooky vérifie les changements sur le serveur toutes les 2 secondes quand la fenêtre du dépôt est au premier plan, et toutes les 10 secondes sinon. Quand le serveur tarde à répondre, il vérifie moins souvent. Une modification faite sur le serveur peut mettre ce temps à apparaître. Consultez [En quoi les dépôts sur un serveur diffèrent](/guide/server/overview/#differences).
:::

## Afficher une liste ou une arborescence {#view}

Le menu :ui[menu.view > files.statusMenu] change ce que la liste affiche. Le bouton à l’extrémité droite de la ligne de la branche propose les mêmes éléments.

| Élément | Ce qu’il fait |
|---|---|
| :ui[working.list] (<kbd>⌃⌘L</kbd>) | Une ligne par fichier, avec son chemin complet |
| :ui[working.tree] (<kbd>⌃⌘T</kbd>) | Les fichiers regroupés dans leurs dossiers. Double-cliquez sur un dossier pour le développer ou le réduire. |
| :ui[files.showNonModified] (<kbd>⌃⌘M</kbd>) | Liste tous les fichiers du dépôt, pas seulement ceux qui sont modifiés. Disponible dans l’arborescence. |
| :ui[files.showIgnored] (<kbd>⌃⌘I</kbd>) | Liste les fichiers que Git ignore |
| :ui[files.showAssumeUnchanged] | Liste les fichiers marqués assume-unchanged. Consultez [Fichiers non suivis et ignorés](#untracked-ignored). |

Chaque dépôt retient s’il affiche une liste ou une arborescence. Un dépôt commence en liste. Les autres éléments s’appliquent à tous les dépôts.

## Trier {#sort}

Cliquez sur l’en-tête de colonne :ui[status.filename] ou :ui[status.column] pour trier selon cette colonne. Cliquez à nouveau pour inverser l’ordre. L’ordre est le même dans tous les dépôts et toutes les fenêtres.

Le premier clic sur :ui[status.column] place les fichiers indexés en premier. Viennent ensuite les autres modifications, puis les nouveaux fichiers, et enfin les fichiers non modifiés et ignorés.

## Rechercher un fichier {#search}

1. Appuyez sur <kbd>⌘F</kbd>, ou cliquez dans le champ de recherche de la barre d’outils. Il indique :ui[history.search.forFile].
2. Saisissez une partie du chemin du fichier. Spooky suggère les fichiers qui contiennent ces lettres dans le même ordre.
3. Choisissez un fichier pour ne lister que ce chemin. La dernière suggestion liste tous les fichiers dont le chemin contient ce que vous avez saisi.

Appuyez sur <kbd>Esc</kbd> pour quitter le champ de recherche. La liste reste filtrée. Effacez le champ de recherche pour revoir tous les fichiers.

## Fichiers non suivis et ignorés {#untracked-ignored}

Un nouveau fichier n’est pas suivi tant que vous ne l’avez pas indexé et validé. Les fichiers non suivis affichent ? et sont listés avec les autres modifications. Pour en ajouter un au prochain commit, indexez-le comme n’importe quelle autre modification.

Certains fichiers ne doivent jamais être validés, comme les produits de compilation ou des notes personnelles. Pour que Git ne les liste plus, cliquez sur le fichier avec le bouton droit et choisissez une règle :

- :ui[files.ignore] ajoute la règle au fichier `.gitignore` à la racine du dépôt. Validez `.gitignore`, et la règle s’applique à tous ceux qui utilisent le dépôt.
- :ui[files.exclude] ajoute la règle à `info/exclude` dans le dossier Git. La règle ne s’applique qu’à cette copie du dépôt et n’est jamais validée.

Les deux sous-menus permettent d’ignorer uniquement cet élément, tous les éléments du même nom, tous les éléments de même extension, ou un motif que vous saisissez.

Les règles d’exclusion ne s’appliquent pas aux fichiers que Git suit déjà. Si vous ignorez un fichier suivi, Spooky demande s’il faut aussi cesser de le suivre. Cliquez sur :ui[files.untrack] pour ne plus le suivre, ou sur :ui[files.untrackIgnored.skip] pour continuer à le suivre. Dans les deux cas, le fichier reste dans votre dossier.

Pour ne plus suivre un fichier sans règle d’exclusion, cliquez dessus avec le bouton droit et choisissez :ui[files.untrack]. Le prochain commit le retire du dépôt, et le fichier reste dans votre dossier.

:ui[files.mark > files.assumeUnchanged.set] demande à Git de laisser de côté vos modifications locales d’un fichier suivi, par exemple un fichier de configuration que vous ne modifiez que sur votre Mac. Le fichier disparaît de la liste. Pour le revoir, activez :ui[files.showAssumeUnchanged], puis choisissez :ui[files.mark > files.assumeUnchanged.unset].

## Actions sur les fichiers {#file-actions}

Cliquez sur un fichier avec le bouton droit pour afficher ses actions. Si vous cliquez sur une ligne de la sélection, l’action s’applique à tous les fichiers sélectionnés. En dehors de la sélection, elle ne s’applique qu’à la ligne sur laquelle vous avez cliqué.

::screenshot[Le menu contextuel de src/readings.ts dans la copie de travail. De haut en bas, il propose d’ouvrir le fichier et de copier son chemin, Coup d’œil, l’indexation et la mise à la Corbeille, les conflits, l’abandon et le remisage, le blame et l’historique du fichier, les règles pour l’ignorer et la comparaison.]{name="work-file-menu" frame="closeup"}

| Pour | Choisissez |
|---|---|
| Ouvrir le fichier | :ui[files.open], ou une app dans :ui[files.openWith]. Vous pouvez aussi double-cliquer sur le fichier. |
| Copier son chemin | :ui[workspace.copyPathMenu] ou :ui[working.copyRelative] |
| L’afficher dans le Finder ou dans Terminal | :ui[action.revealFinder] ou :ui[action.openTerminal] |
| Le déplacer ou le renommer | :ui[files.move.menu] |
| Le placer dans la Corbeille | :ui[files.trash], ou appuyez sur <kbd>⌘⌫</kbd> |
| Abandonner vos modifications | :ui[working.discard.menu] (consultez [Abandonner des modifications](/guide/work/diff/#discard)) |
| Le mettre dans un remisage | Consultez [Remiser certains fichiers](/guide/work/stash/#partial). |
| Restaurer une version antérieure | :ui[files.revert.menu] |
| Consulter son historique | :ui[quickActions.showFileHistory] ou :ui[quickActions.showBlame] (consultez [Historique du fichier et blame](/guide/history/file-views/)) |
| Le comparer dans une autre app | :ui[externalTool.compare] (consultez [Comparer dans une autre app](/guide/work/diff/#external)) |

:ui[files.trash] ne demande pas de confirmation. Un fichier suivi que vous placez dans la Corbeille apparaît comme une suppression indexée. Pour le récupérer, choisissez :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

:::note[Dépôts sur un serveur]
:ui[files.trash] place les fichiers dans la Corbeille du serveur. Si le serveur n’a pas de Corbeille, l’élément indique :ui[files.delete], et Spooky demande confirmation avant de supprimer les fichiers définitivement. La plupart des apps reçoivent une copie du fichier, et Spooky réécrit vos modifications sur le serveur quand vous enregistrez. Consultez [Terminal et autres apps](/guide/server/local-location/#terminal).
:::

## Coup d’œil {#quick-look}

Pour avoir un aperçu d’un fichier sans ouvrir d’app, cliquez dessus avec le bouton droit et choisissez :ui[files.quickLook.single]{1="README.md"}.

Si vous utilisez souvent Coup d’œil, faites-le ouvrir par la barre d’espace : choisissez :ui[app.name > settings.title] › :ui[settings.general], puis réglez :ui[files.spacebar] sur :ui[files.spacebar.quickLook]. Par défaut, la barre d’espace indexe ou désindexe les fichiers sélectionnés. Consultez [Liste de fichiers](/guide/settings/general/#file-list).

:::note[Dépôts sur un serveur]
Spooky télécharge d’abord le fichier dans un dossier temporaire sur votre Mac. Le dossier est supprimé quand vous fermez le dépôt.
:::

## Réglages de la liste de fichiers {#settings}

Ils se trouvent dans :ui[app.name > settings.title] › :ui[settings.general] :

| Réglage | Choix |
|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] (par défaut) ou :ui[files.doubleClick.openDiff] |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] (par défaut) ou :ui[files.spacebar.quickLook] |
| :ui[files.fontSize] | :ui[files.fontSize.regular] ou :ui[files.fontSize.medium] (par défaut) |
| :ui[files.truncation] | :ui[files.truncation.beginning] (par défaut) ou :ui[files.truncation.middle] |

Consultez [Liste de fichiers](/guide/settings/general/#file-list).

## Voir aussi

- [Examiner et indexer les modifications](/guide/work/diff/)
- [Valider des modifications](/guide/work/commit/)
- [Historique du fichier et blame](/guide/history/file-views/)
