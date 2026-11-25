---
title: "Spooky im Überblick"
description: "Lernen Sie das Fenster „Repositorys“ und das Repository-Fenster kennen: die Seitenleiste, die Symbolleiste, die drei Spalten und die Schnellaktionen."
---

Die Fenster von Spooky zeigen eines von zwei Dingen. Die Ansicht „Repositorys“ führt Ihre Repositorys auf. In einem Repository-Fenster erledigen Sie die eigentliche Arbeit. Diese Seite benennt die Teile von beiden. Der Rest des Handbuchs verwendet diese Namen.

## Das Fenster „Repositorys“ {#repositories-window}

Wenn Sie Spooky zum ersten Mal öffnen, zeigt es die Ansicht „Repositorys“. Die Seitenleiste führt Ihre Repositorys unter :ui[repositories.title] auf. Sie können sie in Gruppen ordnen.

- Wählen Sie ein Repository aus, um rechts seine Details zu sehen: wo es liegt, wann Sie es zuletzt geöffnet haben, seinen letzten Commit, seinen aktuellen Branch mit den Änderungen und seine Remotes.
- Wählen Sie eine Gruppe oder nichts aus, um einen Bereich mit dem Text :ui[bookmarks.dropZone.title] und den Tasten :ui[bookmarks.dropZone.add], :ui[action.addRemote], :ui[bookmarks.dropZone.create] und :ui[bookmarks.dropZone.clone] zu sehen.
- Die Hinzufügen-Taste unten in der Seitenleiste fügt Gruppen und Repositorys hinzu.

Doppelklicken Sie auf ein Repository, um es zu öffnen. Es öffnet sich im selben Fenster anstelle der Ansicht „Repositorys“. Um die Liste zurückzuholen, klicken Sie oben in der Seitenleiste auf :ui[toolbar.bookmarks]. [Das Fenster „Repositorys“](/guide/repositories/manager/) behandelt die Liste im Detail.

## Das Repository-Fenster {#repository-window}

Sobald ein Repository geöffnet ist, zeigt der Fenstertitel dessen Namen. Unter dem Namen steht die aktuelle Ansicht mit einer kurzen Zusammenfassung, etwa dem Branch und der Anzahl geänderter Dateien.

::screenshot[Ein Repository-Fenster. Die Seitenleiste links führt die Ansichten, Branches, Tags und Remotes des Repositorys auf. Die Symbolleiste verläuft oben. Die mittlere Spalte zeigt den Commit-Bereich über einer Liste geänderter Dateien, und die rechte Spalte zeigt die Änderungen in der ausgewählten Datei.]{name="tour-window" frame="window" markers="16.5,47 50,3.25 36,72 85,31"}

1. Die Seitenleiste
2. Die Symbolleiste
3. Die mittlere Spalte: die Liste der aktuellen Ansicht
4. Die rechte Spalte: Details zu dem, was in der mittleren Spalte ausgewählt ist

:::note[Server-Repositorys]
Der Fenstertitel beginnt mit dem Host-Alias, wie in `alias:name`. Die Symbolleiste zeigt den Host-Alias außerdem im Objekt :ui[toolbar.host]. [Verbindungsstatus und erneutes Verbinden](/guide/server/connection/) erklärt, was das Fenster zeigt, wenn die Verbindung abbricht.
:::

### Seitenleiste {#sidebar}

Der Abschnitt :ui[workspace.group] ganz oben wechselt zwischen den Ansichten des Repositorys:

| Ansicht | Was sie zeigt |
|---|---|
| :ui[workspace.title] | Ihre nicht committeten Änderungen. Die Zahl daneben zählt die geänderten Dateien. |
| :ui[history.title] | Die Commits |
| :ui[stash.title] | Änderungen, die Sie beiseitegelegt haben |
| :ui[pr.title] | Pull Requests oder Merge Requests des Hosting-Dienstes |
| :ui[review.title] | Ihre Branches, um die zu finden, die Sie aufräumen können |
| :ui[reflog.title] | Wo HEAD gewesen ist. Erscheint, nachdem Sie :ui[sidebar.showReflog] unter :ui[sidebar.viewSettings] eingeschaltet haben. |
| :ui[repositorySettings.title] | Einstellungen für dieses Repository. Siehe [Repository-Einstellungen](/guide/settings/identity/#repository). |

Darunter folgen :ui[sidebar.pinned] (sobald Sie einen Branch anheften), :ui[branch.group], :ui[sidebar.archived], :ui[sidebar.tags], :ui[remote.group], :ui[submodule.group] und :ui[worktree.group]. Unter :ui[branch.group] markiert eine HEAD-Plakette den Branch, auf dem Sie sich befinden. Ein Pfeil mit einer Zahl, etwa ↑3, zählt die Commits, die Sie noch nicht gepusht haben.

Die Leiste unten in der Seitenleiste enthält das Feld :ui[sidebar.filter], die Taste :ui[reference.addMenu] zum Erstellen von Branches und anderen Referenzen sowie :ui[sidebar.viewSettings], um festzulegen, was die Seitenleiste zeigt.

### Symbolleiste {#toolbar}

Von links nach rechts enthält die Symbolleiste diese Tasten:

- :ui[toolbar.bookmarks]: zurück zur Ansicht „Repositorys“
- :ui[toolbar.previous] und :ui[toolbar.next]: vor und zurück durch die Ansichten, die Sie besucht haben
- :ui[toolbar.finder] und :ui[toolbar.terminal]: den Ordner des Repositorys im Finder zeigen oder im Terminal öffnen
- :ui[sync.fetch], :ui[sync.pull] und :ui[sync.push]: Commits mit Remotes austauschen
- :ui[toolbar.forcePush]: einen Remote-Branch durch Ihren ersetzen, nachdem Sie Commits umgeschrieben haben
- :ui[toolbar.applyStash] und :ui[toolbar.saveStash]: beiseitegelegte Änderungen zurückholen oder die aktuellen Änderungen beiseitelegen
- :ui[toolbar.createBranch]: einen neuen Branch anlegen
- :ui[action.refresh]: das Repository neu einlesen
- :ui[action.search]: die Liste der aktuellen Ansicht filtern

Halten Sie <kbd>⌥</kbd> gedrückt, und :ui[sync.fetch], :ui[sync.pull] und :ui[sync.push] werden zu Schnellversionen, etwa :ui[sync.quickPush]. Eine Schnellversion arbeitet sofort mit dem Tracking-Branch, ohne ein Dialogfenster zu öffnen.

:ui[toolbar.clone] erscheint, solange es kürzlich geklonte Repositorys gibt. Siehe [Das Fenster „Repositorys“](/guide/repositories/manager/). Wählen Sie :ui[menu.view > menu.customizeToolbar], um Tasten hinzuzufügen oder zu entfernen. Neben den Tasten oben können Sie :ui[toolbar.quickActions], :ui[toolbar.synchronize], :ui[sync.merge] und :ui[sync.rebaseHead] sowie :ui[toolbar.pushTo] hinzufügen.

### Die drei Spalten {#columns}

Die linke Spalte ist die Seitenleiste. Die mittlere Spalte zeigt die Liste der gewählten Ansicht. Unter :ui[workspace.title] sind das der Commit-Bereich und die geänderten Dateien. Unter :ui[history.title] sind es die Commits.

Die rechte Spalte zeigt die Details zu dem, was Sie in der Mitte auswählen. Unter :ui[workspace.title] sind das die Änderungen in der ausgewählten Datei. Wenn eine Datei sowohl gestagte als auch nicht gestagte Änderungen hat, wechseln Sie oben mit :ui[working.staged] und :ui[working.unstaged] zwischen ihnen. Ist nichts ausgewählt, zeigt die Spalte :ui[detail.empty.title].

### Schmale Fenster {#narrow-window}

Wird das Fenster zu schmal für drei Spalten, wechselt es in ein Layout für schmale Fenster. Machen Sie das Fenster breiter, kommen die drei Spalten zurück, so breit wie zuvor.

::screenshot[Ein schmales Repository-Fenster. Eine Zeile unter der Symbolleiste wechselt zwischen den Ansichten. Der Commit-Bereich und die Liste der geänderten Dateien stehen über den Änderungen in der ausgewählten Datei.]{name="tour-narrow-window" frame="window" markers="75,9 75,40 75,84"}

1. Die Ansichtszeile anstelle der Seitenleiste
2. Die Liste der aktuellen Ansicht
3. Details zu dem, was in der Liste ausgewählt ist

- Die Ansichtszeile enthält :ui[workspace.title], :ui[history.title] und :ui[stash.title]. Für Branches, Tags, Remotes und die übrigen Ansichten klicken Sie am Anfang der Zeile auf :ui[sidebar.menu]. Die Seitenleiste öffnet sich über der Ansicht. Klicken Sie erneut auf :ui[sidebar.menu] oder neben die Seitenleiste, um sie zu schließen.
- Die Liste steht über den Details. Ziehen Sie die Linie dazwischen, um einem der beiden mehr Platz zu geben.
- Tasten, die nicht mehr in die Symbolleiste passen, wandern in das Menü » an ihrem Ende. :ui[sync.fetch], :ui[sync.pull] und :ui[sync.push] bleiben in der Symbolleiste.

Die aktuelle Ansicht, Ihre Auswahl und die Commit-Nachricht, an der Sie schreiben, bleiben beim Wechsel des Layouts erhalten.

### Schnellaktionen {#quick-actions}

Wählen Sie :ui[menu.file > quickActions.menu] oder drücken Sie <kbd>⇧⌘A</kbd>, um ein Panel zu öffnen. Tippen Sie, um eine Ansicht, einen Branch, eine Datei oder einen Commit zu finden, und führen Sie dann eine Aktion darauf aus, ohne die Tastatur zu verlassen. [Fenster und Navigation](/guide/repositories/navigation/) erklärt, was es findet und welche Tasten es verwendet.

## Siehe auch

- [Ihr erstes Repository](/guide/start/first-repository/)
- [Das Fenster „Repositorys“](/guide/repositories/manager/)
- [Fenster und Navigation](/guide/repositories/navigation/)
