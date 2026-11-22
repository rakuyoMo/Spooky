---
title: "Branches"
description: "Branches erstellen, auschecken, verfolgen, umbenennen, löschen, anheften und archivieren, Eltern-Branches festlegen und Branches in der Seitenleiste filtern und gruppieren."
---

Ihre lokalen Branches stehen in der Seitenleiste unter :ui[branch.group]. Das meiste, was Sie mit einem Branch tun, beginnt dort: Klicken Sie mit der rechten Maustaste darauf, um sein Menü zu öffnen, oder ziehen Sie ihn an eine andere Stelle.

::screenshot[Der untere Teil der Seitenleiste. Unter „Branches“ trägt main eine HEAD-Plakette mit ↑3, und ein Ordner feature enthält dark-mode, station-map und units-toggle. „Archivierte Branches“ ist leer. Unter „Tags“ stehen v0.1.0 bis v0.4.0. Unter „Remotes“ hat origin den Branch main mit einem Haussymbol und einen reduzierten Ordner feature. Die Leiste ganz unten enthält links das Filterfeld und rechts die Tasten zum Hinzufügen und für die Darstellungsoptionen.]{name="branches" frame="closeup" markers="57,7 57,12.1 75,33.6 17,96.8 73,96.8"}

1. Der Branch, auf dem Sie sich befinden, mit seiner HEAD-Plakette und den noch nicht gepushten Commits
2. Ein Ordner für die Branches, deren Namen mit `feature/` beginnen
3. :ui[sidebar.archived]
4. :ui[sidebar.filter]
5. Die Hinzufügen-Taste und die Taste für die Darstellungsoptionen

## In der Seitenleiste {#sidebar}

Klicken Sie auf einen Branch, um seine Commits im Verlauf zu sehen. Mit einem Doppelklick checken Sie ihn aus.

Ein Branch, der einen Remote-Branch verfolgt, zeigt, wie weit die beiden auseinanderliegen. ↑ zählt Ihre Commits, die noch nicht auf dem Remote sind. ↓ zählt die Commits auf dem Remote, die Sie noch nicht haben. Bewegen Sie den Zeiger auf einen Branch, um zu sehen, was er verfolgt.

Ein Branch, der eine Weile keinen neuen Commit bekommen hat, ist veraltet. Sein Name ist abgeblendet, dahinter stehen eine Uhr und die Dauer. `main`, `master`, `trunk`, `dev`, `develop`, `next` und jeder Branch, der Eltern-Branch eines anderen ist, veralten nie.

Unter :ui[remote.group] kennzeichnet ein Haussymbol den Standard-Branch jedes Remotes.

## Einen Branch erstellen {#create}

1. Wählen Sie :ui[menu.repository > branch.createMenu] (<kbd>⌘B</kbd>). Sie können auch unten in der Seitenleiste auf die Hinzufügen-Taste klicken oder mit der rechten Maustaste auf :ui[branch.group] klicken und den Befehl im Menü wählen.
2. Geben Sie den Namen in :ui[reference.name] ein.
3. Wählen Sie in :ui[branch.start], wo der Branch beginnt. Anfangs ist das der Branch, auf dem Sie sich befinden, oder das, worauf Sie mit der rechten Maustaste geklickt haben.
4. Legen Sie die Optionen fest:
   - Mit :ui[branch.trackStart] verfolgt der neue Branch seinen Ausgangspunkt. Die Option ist nur verfügbar, wenn der Ausgangspunkt ein Branch ist.
   - :ui[branch.pin] legt den neuen Branch unter :ui[sidebar.pinned] ab.
   - :ui[branch.checkoutCreated] wechselt sofort zum neuen Branch. Spooky merkt sich diese Auswahl.
   - :ui[branch.parentOption] macht den Ausgangspunkt zum [Eltern-Branch](#parent) des neuen Branches.
5. Klicken Sie auf :ui[branch.create].

Um einen Branch ab einem bestimmten Branch, Tag oder Commit zu beginnen, klicken Sie mit der rechten Maustaste darauf und wählen Sie :ui[branch.createFromMenu]{1="main"} aus dem Menü. Sie können ihn auch auf :ui[branch.group] ziehen.

Während Sie tippen, passt Spooky den Namen für Git an: Leerzeichen und Zeichen, die Git nicht erlaubt, werden zu `-` oder entfallen. Um Namen unverändert einzugeben, deaktivieren Sie :ui[branch.cleanNames] unter :ui[app.name > settings.title] › :ui[settings.general]. Siehe [Vorgänge](/guide/settings/general/#operations).

Ein `/` im Namen legt den Branch in einen Ordner, etwa `feature/units-toggle` in `feature`. Klicken Sie mit der rechten Maustaste auf einen Ordner und wählen Sie :ui[branch.createMenu] aus dem Menü, dann beginnt der Name bereits mit dem Ordner.

## Einen Branch auschecken {#checkout}

Doppelklicken Sie auf einen Branch, oder klicken Sie mit der rechten Maustaste darauf und wählen Sie :ui[branch.checkoutNamed]{1="feature/dark-mode"} aus dem Menü.

Auch ein Doppelklick auf einen Remote-Branch funktioniert:

- Wenn ihn bereits ein lokaler Branch verfolgt, checkt Spooky diesen Branch aus.
- Wenn es einen gleichnamigen lokalen Branch gibt, der ihn nicht verfolgt, fragt Spooky zuerst in :ui[branch.trackExisting.title] nach. Dann checkt es diesen Branch aus und lässt ihn den Remote-Branch verfolgen.
- Andernfalls erstellt Spooky einen gleichnamigen lokalen Branch, der den Remote-Branch verfolgt. Danach checkt es den Branch aus.

Wenn Sie Änderungen an versionierten Dateien haben, fragt Spooky, ob sie zuerst gestasht werden sollen. Siehe [Automatisches Stashen](/guide/work/stash/#auto-stash).

Ein Branch, der in einem anderen Worktree ausgecheckt ist, lässt sich hier nicht auschecken. Bei einem Doppelklick öffnet Spooky stattdessen diesen Worktree. Halten Sie beim Doppelklick <kbd>⌘</kbd> gedrückt, um ihn in einem neuen Tab zu öffnen.

### Ein Tag oder einen Commit auschecken {#checkout-revision}

Doppelklicken Sie auf ein Tag, um seinen Commit auszuchecken. Für alles andere wählen Sie :ui[workspace.title > rewrite.checkout.menu] (<kbd>⇧⌘B</kbd>), wählen einen Branch, Tag oder Commit und klicken auf :ui[rewrite.checkout.button].

Wenn Ihre Auswahl kein lokaler Branch ist, warnt das Dialogfenster, dass HEAD losgelöst wird. Ein losgelöster HEAD bedeutet, dass Sie sich auf einem Commit befinden, nicht auf einem Branch. Um Commits zu behalten, die Sie dort erstellen, erstellen Sie daraus einen Branch.

## Einen Remote-Branch verfolgen {#track}

Ein lokaler Branch kann einen Branch auf einem Remote verfolgen, seinen Upstream. Pullen und Pushen verwenden den Upstream, sofern Sie nichts anderes wählen. Die Zähler ↑ und ↓ vergleichen mit ihm.

So erhalten Sie einen lokalen Branch für einen Remote-Branch:

1. Klicken Sie mit der rechten Maustaste auf den Remote-Branch und wählen Sie :ui[branch.trackMenu]{1="origin/feature/station-map"} aus dem Menü, oder ziehen Sie ihn auf :ui[branch.group].
2. :ui[branch.remoteField] zeigt den Remote-Branch. Ändern Sie bei Bedarf den Namen in :ui[reference.name].
3. :ui[branch.track.checkout] ist jedes Mal aktiviert. Deaktivieren Sie die Option, um auf dem aktuellen Branch zu bleiben.
4. Klicken Sie auf :ui[branch.track.submit].

Um zu ändern, was ein vorhandener Branch verfolgt, klicken Sie mit der rechten Maustaste darauf und wählen Sie unter :ui[branch.tracking] einen Branch. :ui[branch.tracking.remove] beendet das Verfolgen. Beim Branch, auf dem Sie sich befinden, können Sie auch <kbd>⌥</kbd> gedrückt halten und einen Remote-Branch darauf ziehen.

Wenn ein Branch, auf dem Sie sich nicht befinden, hinter seinem Upstream zurückliegt und keine eigenen Commits hat, enthält sein Menü :ui[branch.fastForward]{1="main"}. Der Befehl spult den Branch bis zum Upstream vor, ohne ihn auszuchecken.

## Einen Branch umbenennen {#rename}

Klicken Sie mit der rechten Maustaste auf den Branch und wählen Sie :ui[reference.renameMenu]{1="feature/dark-mode"} aus dem Menü. Geben Sie den neuen Namen ein und klicken Sie auf :ui[reference.rename].

Die Einstellungen zum Anheften, Archivieren und zum Eltern-Branch bleiben beim Branch. Wenn Sie einen Remote-Branch umbenennen, wird er auf dem Remote umbenannt.

Um einen Branch in einen Ordner zu verschieben, ziehen Sie ihn auf den Ordner. Siehe [Drag & Drop](/guide/branches/merge-rebase/#drag-and-drop).

## Einen Branch löschen {#delete}

Klicken Sie mit der rechten Maustaste auf den Branch und wählen Sie :ui[reference.deleteMenu]{1="feature/dark-mode"} aus dem Menü. Sie können auch einen oder mehrere Branches auswählen und <kbd>⌘⌫</kbd> drücken, während die Seitenleiste den Fokus hat.

Spooky fragt immer zuerst nach. Das Dialogfenster hat zwei Optionen:

- :ui[branch.forceDelete] löscht den Branch auch dann, wenn er nicht vollständig zusammengeführt ist. Ohne die Option listet Spooky die nicht vollständig zusammengeführten Branches auf und fragt erneut.
- :ui[branch.deleteUpstream] löscht auch den Remote-Branch, den er verfolgt. Die Option erscheint, wenn Sie einen einzelnen Branch löschen, dessen Remote-Branch noch existiert.

Den Branch, auf dem Sie sich befinden, können Sie nicht löschen. Checken Sie zuerst einen anderen Branch aus.

Wenn Sie einen Remote-Branch löschen, wird er auf dem Remote gelöscht.

Um einen gelöschten lokalen Branch zurückzuholen, wählen Sie :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>). Das funktioniert auch, wenn :ui[branch.deleteUpstream] aktiviert war. Wenn Sie nur einen Remote-Branch löschen, lässt sich das nicht widerrufen. Siehe [Widerrufen und Wiederherstellen](/guide/work/undo/).

## Einen Branch anheften {#pin}

Angeheftete Branches wandern von :ui[branch.group] nach :ui[sidebar.pinned] ganz oben in der Liste. Das eignet sich für Branches, zu denen Sie oft zurückkehren.

Klicken Sie mit der rechten Maustaste auf einen Branch und wählen Sie :ui[branch.pinNamed]{1="feature/station-map"} aus dem Menü, oder ziehen Sie ihn auf :ui[sidebar.pinned]. Sind mehrere Branches ausgewählt, heißt der Befehl :ui[branch.pinMultiple]{1="2"}. Um einen Branch zurückzulegen, wählen Sie stattdessen :ui[branch.unpinNamed]{1="feature/station-map"}.

## Einen Branch archivieren {#archive}

Beim Archivieren räumen Sie einen Branch aus dem Weg, ohne ihn zu löschen. Er wandert von :ui[branch.group] nach :ui[sidebar.archived]. Sie können ihn weiter wie bisher verwenden.

Klicken Sie mit der rechten Maustaste auf einen Branch und wählen Sie :ui[branch.archiveNamed]{1="feature/dark-mode"} aus dem Menü, oder ziehen Sie ihn auf :ui[sidebar.archived]. Um ihn zurückzuholen, wählen Sie stattdessen :ui[branch.unarchiveNamed]{1="feature/dark-mode"}.

Spooky kann auch Branches finden, die sich zum Archivieren anbieten, und sie für Sie archivieren. Siehe [Branch-Übersicht](/guide/branches/review/#archive-suggestions).

:::note[Server-Repositorys]
Anheften, Archivieren und Eltern-Branches werden in der Git-Konfiguration des Repositorys gesichert. Bei einem Server-Repository werden sie auf dem Server gesichert.
:::

## Eltern-Branch {#parent}

Ein Eltern-Branch ist der Branch, auf dem Ihrer aufbaut und mit dem er Schritt halten soll, etwa `main` für `feature/units-toggle`.

Um ihn festzulegen, klicken Sie mit der rechten Maustaste auf den Branch und wählen Sie unter :ui[branch.parent] einen vorgeschlagenen Branch. Für jeden anderen Branch wählen Sie :ui[branch.parent.setMenu], wählen ihn in :ui[branch.parent.field] aus und klicken auf :ui[branch.parent.set]. Sie können ihn auch beim Erstellen des Branches festlegen. :ui[branch.parent.remove] entfernt ihn.

Sobald ein Branch einen Eltern-Branch hat:

- Der Vergleich von Branches im Verlauf beginnt mit dem Eltern-Branch. Siehe [Mit einem anderen Branch vergleichen](/guide/history/browse/#compare-branches).
- Wenn der Eltern-Branch Commits hat, die Ihrem Branch fehlen, zeigt der Verlauf Ihres Branches :ui[history.parentBanner.title]. Im Menü des Branches holt :ui[branch.updateNamed]{1="feature/units-toggle"} sie herein. Siehe [Einen Branch von seinem Eltern-Branch aktualisieren](/guide/branches/merge-rebase/#update).
- Beim Branch, auf dem Sie sich befinden, öffnen :ui[branch.mergeWith]{1="main"} und :ui[branch.rebaseOn]{1="main"} im Menü die Dialogfenster zum Zusammenführen und für den Rebase, mit dem Eltern-Branch bereits ausgewählt.
- Der Eltern-Branch selbst veraltet nie.

## Filtern und gruppieren {#filter}

Tippen Sie unten in der Seitenleiste in :ui[sidebar.filter], um nur passende Branches, Tags, Remote-Branches, Submodule und Worktrees zu zeigen. Die Buchstaben müssen nicht nebeneinanderstehen: `stm` findet `station-map`. Groß- und Kleinschreibung sowie Akzente spielen keine Rolle. Ordner öffnen sich, während Sie filtern, und <kbd>Esc</kbd> leert das Feld.

Klicken Sie unten rechts auf die Taste für die Darstellungsoptionen oder wählen Sie :ui[menu.view > sidebar.menu], um festzulegen, was die Seitenleiste zeigt. Die Einstellungen gelten für jedes Fenster.

- :ui[sidebar.groupRefs] legt Namen mit einem `/` in Ordner. Die Option ist anfangs aktiviert. :ui[sidebar.groupedRefsOnTop] führt die Ordner vor den anderen Branches auf.
- :ui[sidebar.showStaleInfo] zeigt, welche Branches veraltet sind. :ui[sidebar.staleInterval] legt fest, wie lange ein Branch ohne Commit bleiben darf, anfangs 6 Monate.
- :ui[sidebar.remoteFilter] und :ui[sidebar.tagsFilter] beschränken die Liste auf die neuesten Einträge, die Anzahl wählen Sie unter :ui[sidebar.showNewest]. Die Grenze gilt für jedes Remote einzeln. Tags lassen sich außerdem unter :ui[sidebar.sortBy] sortieren. Während Sie filtern, erscheint jeder Treffer.
- :ui[sidebar.autoArchive] ist unter [Branch-Übersicht](/guide/branches/review/#auto-archive) beschrieben.

## Siehe auch

- [Abrufen, Pullen und Pushen](/guide/branches/sync/)
- [Zusammenführen und Rebase](/guide/branches/merge-rebase/)
- [Branch-Übersicht](/guide/branches/review/)
- [Worktrees](/guide/advanced/worktrees/)
