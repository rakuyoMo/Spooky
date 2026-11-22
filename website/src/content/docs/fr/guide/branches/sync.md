---
title: "Récupérer, tirer et pousser"
description: "Récupérez, tirez et poussez, publiez une branche pour la première fois, synchronisez, poussez de force et récupérez automatiquement."
---

Ces opérations échangent des commits avec les [dépôts distants](/guide/branches/tags-remotes/#remotes) :

- Récupérer télécharge les nouveaux commits d’un dépôt distant. Vos branches et la copie de travail restent telles quelles.
- Tirer récupère une branche distante et intègre ses commits dans la branche actuelle.
- Pousser envoie vos commits vers une branche distante.

La barre d’outils affiche :ui[sync.fetch], :ui[sync.pull] et :ui[sync.push] côte à côte, et :ui[sync.sync] juste à côté. Les mêmes opérations figurent dans le menu :ui[menu.repository].

Récupérer, tirer, pousser et synchroniser ne sont pas consignés dans l’historique d’annulation : ces opérations ne peuvent donc pas être annulées. La publication d’une branche peut l’être.

:::note[Dépôts sur un serveur]
Les dépôts distants sont contactés depuis le serveur, avec le réseau et les clés SSH du serveur. Quand un dépôt distant demande un mot de passe, Spooky vous le demande. Consultez [Demandes de mot de passe et de phrase secrète](/guide/server/connection/#prompts).
:::

## Récupérer {#fetch}

1. Cliquez sur :ui[sync.fetch] dans la barre d’outils, ou choisissez :ui[menu.repository > sync.fetchMenu] (<kbd>⇧⌘F</kbd>). Pour récupérer un seul dépôt distant, cliquez dessus avec le bouton droit dans la barre latérale et choisissez :ui[remote.fetchMenu]{1="origin"} dans le menu.
2. Choisissez le dépôt distant dans :ui[sync.remote], ou sélectionnez :ui[sync.allRemotes].
3. Réglez les options :
   - :ui[sync.prune] retire les branches distantes qui ont été supprimées sur le dépôt distant. L’option est activée au début.
   - :ui[sync.fetchSubmodules] récupère aussi les nouveaux commits des sous-modules extraits.
   - :ui[sync.allTags] récupère aussi tous les tags du dépôt distant.
4. Cliquez sur :ui[sync.fetch].

Spooky retient toutes les options, sauf :ui[sync.allTags].

Après une récupération, les branches distantes de la barre latérale sont à jour, et ↓ sur une branche locale compte les commits que vous pouvez tirer.

:ui[menu.repository > sync.fetchAll] récupère tous les dépôts distants tout de suite, sans zone de dialogue. Les dépôts distants réglés sur :ui[remote.skipFetchAll] dans leurs [réglages](/guide/branches/tags-remotes/#remote-settings) sont ignorés.

## Tirer {#pull}

1. Cliquez sur :ui[sync.pull] dans la barre d’outils, ou choisissez :ui[menu.repository > sync.pullMenu] (<kbd>⇧⌘P</kbd>). Pour tirer une branche distante précise, cliquez dessus avec le bouton droit et choisissez :ui[branch.pullMenu]{1="origin/main"} dans le menu.
2. Choisissez la branche dans :ui[sync.remoteBranch]. Au début, c’est la [branche amont](/guide/branches/branches/#track) de la branche actuelle.
3. Sélectionnez :ui[sync.rebase] pour placer vos commits au-dessus des commits tirés, au lieu de réunir les deux avec un commit de fusion. Spooky retient ce choix.
4. Sous les options, un aperçu indique si le tirage va provoquer des conflits. Consultez [Prévisualiser les conflits](/guide/branches/merge-rebase/#preview).
5. Réglez les options :
   - :ui[merge.verify] arrête le tirage si le commit tiré n’a pas de signature de confiance. Spooky retient cette option.
   - :ui[sync.skipHooks] ignore les crochets Git du dépôt pour cette fois.
6. Cliquez sur :ui[sync.pull].

Un tirage exige que vos fichiers suivis soient sans modification. Sinon, Spooky propose de remiser d’abord les modifications. Consultez [Remisage automatique](/guide/work/stash/#auto-stash). Les nouveaux fichiers ne gênent que si le tirage devait les écraser.

Si le tirage provoque des conflits, Spooky passe à la copie de travail et affiche une bannière. Consultez [Résoudre les conflits](/guide/work/conflicts/#banner).

## Pousser {#push}

1. Cliquez sur :ui[sync.push] dans la barre d’outils, ou choisissez :ui[menu.repository > sync.pushMenu] (<kbd>⇧⌘U</kbd>).
2. Choisissez la branche distante dans :ui[sync.destination]. Au début, c’est la branche amont de la branche actuelle.
3. Réglez les options :
   - :ui[sync.pushAllTags] pousse aussi tous les tags locaux.
   - :ui[sync.forcePush] écrase la branche distante quand une poussée normale est impossible. Consultez [Pousser de force](#force-push).
   - :ui[sync.pushSubmodules] traite les commits de sous-modules auxquels cette poussée fait référence. Choisissez entre :ui[sync.pushSubmodules.onDemand] et :ui[sync.pushSubmodules.check].
   - :ui[sync.skipHooks] ignore les crochets Git du dépôt pour cette fois.
4. Cliquez sur :ui[sync.pushHead].

Spooky retient les options des tags et des sous-modules.

Si la branche actuelle ne suit pas encore de branche distante, :ui[sync.push] ouvre la zone de dialogue de publication à la place. Consultez [Publier une branche](#publish). Si le dépôt n’a aucun dépôt distant, c’est la zone de dialogue de publication du dépôt qui s’ouvre. Consultez [Publier un dépôt](/guide/hosting/accounts/#publish).

Si quelqu’un d’autre a poussé avant vous vers la branche distante, le dépôt distant refuse votre poussée. Tirez ses commits, puis poussez de nouveau.

Pour pousser une branche autre que la branche actuelle, faites-la glisser sur une branche distante dans la barre latérale. La zone de dialogue :ui[sync.pushBranch] l’y pousse. C’est une poussée simple, sans options, qui ne change pas ce que la branche suit.

## Publier une branche {#publish}

Une nouvelle branche n’existe que dans votre dépôt tant que vous ne la publiez pas, ce qui la crée sur un dépôt distant.

1. Choisissez :ui[menu.repository > sync.publishMenu], ou cliquez avec le bouton droit sur la branche et choisissez :ui[branch.publishMenu]{1="feature/station-map"} dans le menu. Vous pouvez aussi faire glisser la branche sur un dépôt distant dans la barre latérale.
2. Vérifiez :ui[branch.local] et :ui[sync.remote]. :ui[branch.name] est le nom sur le dépôt distant, identique au nom local au début.
3. :ui[sync.setUpstream] fait suivre la nouvelle branche distante à votre branche : les prochains tirages et poussées iront là. L’option est activée au début.
4. Sélectionnez :ui[sync.skipHooks] pour ignorer les crochets Git du dépôt.
5. Cliquez sur :ui[sync.publish].

Pour revenir en arrière, choisissez :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

## Synchroniser {#sync}

La synchronisation récupère, tire et pousse la branche actuelle, dans cet ordre.

1. Cliquez sur :ui[sync.sync] dans la barre d’outils, ou choisissez :ui[menu.repository > sync.syncMenu] (<kbd>⇧⌘Y</kbd>).
2. Choisissez la branche dans :ui[sync.remoteBranch]. Au début, c’est la branche amont de la branche actuelle.
3. Sélectionnez :ui[sync.rebase] si vous le souhaitez. L’aperçu en dessous indique si le tirage va provoquer des conflits.
4. Réglez les options : :ui[merge.verify], :ui[sync.pushAllTags], :ui[sync.pushSubmodules] et :ui[sync.skipHooks] fonctionnent comme pour tirer et pousser.
5. Cliquez sur :ui[sync.syncHead].

Comme pour un tirage, Spooky propose d’abord de remiser les modifications des fichiers suivis.

Si une étape échoue, Spooky s’arrête là et vous indique à quelle étape il s’est arrêté, et lesquelles ont été faites. Dans :ui[activity.title], le tirage et la poussée ont chacun leur entrée.

## Pousser ailleurs {#push-to}

Pour pousser une branche, un tag ou un commit vers n’importe quelle branche ou référence d’un dépôt distant :

1. Choisissez :ui[menu.repository > sync.pushToMenu], ou cliquez avec le bouton droit sur une branche et choisissez :ui[branch.pushToMenu]{1="main"} dans le menu. Le menu des tags contient aussi :ui[tag.pushToMenu]{1="v0.4.0"}.
2. Choisissez ce qu’il faut pousser dans :ui[sync.revision], et le dépôt distant dans :ui[sync.remote].
3. Dans :ui[sync.refSpec], saisissez la destination : un nom de branche, nouvelle ou existante, ou une référence complète comme `refs/tags/v0.4.0`.
4. Cliquez sur :ui[sync.pushRevision].

Pour une branche, la zone de dialogue propose d’abord la branche distante qu’elle suit. Pour un tag, elle propose `refs/tags/` suivi du nom du tag.

## Pousser de force {#force-push}

Après avoir réécrit des commits déjà poussés, par exemple en corrigeant un commit ou en rebasant, une poussée normale est refusée : la branche distante a des commits que votre branche n’a plus. Une poussée forcée remplace la branche distante par la vôtre.

Spooky ne pousse de force qu’avec bail. La poussée n’aboutit que si la branche distante est toujours là où elle était lors de votre dernière récupération. Si quelqu’un a poussé entre-temps, Git refuse et rien n’est écrasé. Spooky ne se rabat jamais sur une poussée forcée sans protection.

1. Choisissez :ui[menu.repository > sync.forcePushMenu] (<kbd>⌃⌘U</kbd>), ou cliquez avec le bouton droit sur une branche locale et choisissez cet élément dans le menu.
2. Choisissez la branche locale dans :ui[branch.target], et la branche distante dans :ui[sync.destination].
3. Lisez la comparaison en dessous. Elle indique combien de commits la poussée ajoute à la branche distante et combien elle en écrase. Ensuite :
   - Une ligne verte signifie que la branche distante est à la version qu’avait votre branche avant que vous la réécriviez. C’est le cas habituel.
   - Une ligne jaune signifie que la branche distante est ailleurs, ou qu’elle a des commits que votre branche n’a jamais eus. Vérifiez que vous voulez vraiment les écraser.
   - Si les deux branches sont sur le même commit, il n’y a rien à pousser.
4. Cliquez sur :ui[sync.forcePush].

::screenshot[La zone de dialogue Pousser de force avec bail. La branche locale est feature/units-toggle et la branche distante est origin/feature/units-toggle. En dessous, une ligne avec une coche verte indique que la branche distante est à la version qu’avait cette branche avant sa réécriture.]{name="branches-force-push" frame="dialog" markers="16.4,65.9"}

1. La comparaison

L’option :ui[sync.forcePush] de la zone de dialogue de poussée utilise la même protection.

:::tip
Choisissez :ui[menu.view > menu.customizeToolbar] pour ajouter :ui[toolbar.forcePush] et :ui[toolbar.pushTo] à la barre d’outils.
:::

## Versions rapides {#quick}

Maintenez <kbd>⌥</kbd>, et :ui[sync.fetch], :ui[sync.pull], :ui[sync.push] et :ui[sync.sync] dans la barre d’outils deviennent :ui[sync.quickFetch], :ui[sync.quickPull], :ui[sync.quickPush] et :ui[sync.quickSync]. Les éléments de menu changent de la même façon, par exemple :ui[sync.quickPushMenu].

Une version rapide s’exécute tout de suite, sans zone de dialogue :

- Elle travaille avec la branche amont de la branche actuelle.
- Elle reprend les options choisies la dernière fois dans la zone de dialogue. :ui[sync.skipHooks] n’est jamais repris.
- :ui[sync.quickFetch] récupère le dépôt distant que suit la branche actuelle. Il récupère tous les dépôts distants si vous avez choisi :ui[sync.allRemotes] la dernière fois, ou si la branche ne suit rien.
- Si la branche actuelle ne suit pas de branche distante, :ui[sync.quickPush] et :ui[sync.quickSync] vous le signalent.

Les menus contextuels ont aussi des versions rapides, comme :ui[sync.quickFetchNamed]{1="origin"} pour un dépôt distant et :ui[sync.quickPullNamed]{1="origin/main"} pour une branche distante.

## Récupérer automatiquement {#auto-fetch}

Spooky peut récupérer en arrière-plan pour que les branches distantes et les compteurs ↓ restent à jour. Choisissez la fréquence dans :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.autoFetch] : :ui[settings.autoFetch.never], toutes les 5, 10 ou 30 minutes, ou :ui[settings.autoFetch.hour]. Au début, c’est toutes les 30 minutes. Consultez [Opérations](/guide/settings/general/#operations).

- Spooky cherche les dépôts distants à récupérer environ 10 secondes après l’ouverture d’un dépôt, puis toutes les quelques minutes. Un dépôt distant est à récupérer s’il ne l’a jamais été, ou si l’intervalle s’est écoulé depuis sa dernière récupération.
- La récupération n’a lieu que si la fenêtre affiche le dépôt et qu’aucune zone de dialogue n’est ouverte. Elle continue quand Spooky est en arrière-plan.
- Elle ne démarre que si rien d’autre ne s’exécute dans le dépôt. Si vous lancez une opération pendant une récupération, celle-ci s’arrête et laisse passer la vôtre. :ui[activity.title] note pour quelle opération elle s’est arrêtée.
- Elle ne demande jamais de mot de passe. Si elle échoue, l’erreur n’apparaît que dans :ui[activity.title].
- Elle reprend les options d’élagage et de sous-modules choisies la dernière fois dans la zone de dialogue de récupération, et ignore les dépôts distants réglés sur :ui[remote.skipFetchAll].
- Dans un dépôt local, elle ignore les dépôts distants qui sont des chemins sur votre Mac, et ne récupère pas quand le Mac est hors ligne.

## Voir aussi

- [Fusionner et rebaser](/guide/branches/merge-rebase/)
- [Branches](/guide/branches/branches/)
- [File d’attente et activité](/guide/advanced/queue-activity/)
- [Remisages](/guide/work/stash/)
