---
title: "Tastaturkurzbefehle"
description: "Schlagen Sie jeden Tastaturkurzbefehl in Spooky nach."
---

Menüeinträge zeigen ihre Kurzbefehle neben sich an. Diese Seite sammelt sie alle, zusammen mit den Tasten, die an bestimmten Stellen funktionieren, etwa im Commit-Bereich, in Listen und in Dialogfenstern. Die Symbole sind unter [Tastaturkurzbefehle](/guide/#shortcuts) erklärt.

Ein Kurzbefehl funktioniert nur, solange sein Menüeintrag verfügbar ist. Wenn ein Eintrag abgeblendet ist, bewirkt sein Kurzbefehl nichts.

## Menüs {#menus}

### App und Fenster {#app-windows}

| Kurzbefehl | Menüeintrag |
|---|---|
| <kbd>⌘,</kbd> | :ui[app.name > settings.title] |
| <kbd>⌘H</kbd> | :ui[app.name > menu.hide] |
| <kbd>⌥⌘H</kbd> | :ui[app.name > menu.hideOthers] |
| <kbd>⌘Q</kbd> | :ui[app.name > menu.quit] |
| <kbd>⌘N</kbd> | :ui[menu.file > menu.newWindow] |
| <kbd>⌘T</kbd> | :ui[menu.file > menu.newTab] |
| <kbd>⌘W</kbd> | :ui[menu.file > menu.closeWindow] |
| <kbd>⌃⌘F</kbd> | :ui[menu.view > menu.fullscreen] |
| <kbd>⌘M</kbd> | :ui[menu.window > menu.minimize] |
| <kbd>⌃⌘0</kbd> | :ui[menu.window > activity.title] |
| <kbd>⌘?</kbd> | :ui[menu.help > help.help] |

### Repositorys {#repositories}

| Kurzbefehl | Menüeintrag |
|---|---|
| <kbd>⌘O</kbd> | :ui[menu.file > action.openLocal] |
| <kbd>⌃⌘C</kbd> | :ui[menu.file > clone.menu] |
| <kbd>⇧⌘A</kbd> | :ui[menu.file > quickActions.menu] |
| <kbd>⌃⌘R</kbd> | :ui[menu.view > menu.showRepositories] |

### Ansichten {#views}

| Kurzbefehl | Menüeintrag |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.view > menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.view > menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[menu.view > stash.show] |
| <kbd>⌘4</kbd> | :ui[menu.view > pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[menu.view > review.show] |
| <kbd>⌘6</kbd> | :ui[menu.view > reflog.show] |
| <kbd>⌘0</kbd> | :ui[menu.view > history.showHead] |
| <kbd>⌘[</kbd> | :ui[menu.view > navigation.back] |
| <kbd>⌘]</kbd> | :ui[menu.view > navigation.forward] |
| <kbd>⌘R</kbd> | :ui[menu.view > action.refresh] |
| <kbd>⌃⌘T</kbd> | :ui[menu.view > files.statusMenu > working.tree] |
| <kbd>⌃⌘L</kbd> | :ui[menu.view > files.statusMenu > working.list] |
| <kbd>⌃⌘M</kbd> | :ui[menu.view > files.statusMenu > files.showNonModified] |
| <kbd>⌃⌘I</kbd> | :ui[menu.view > files.statusMenu > files.showIgnored] |
| <kbd>⌃⌘G</kbd> | :ui[menu.view > history.title > history.showGraph] |
| <kbd>⌃⌥⌘C</kbd> | :ui[menu.view > history.title > history.compareBranches] |
| <kbd>⌃⌘→</kbd> | :ui[menu.view > history.diffs > history.expandAll] |
| <kbd>⌃⌘←</kbd> | :ui[menu.view > history.diffs > history.collapseAll] |

### Bearbeiten und Suchen {#edit}

| Kurzbefehl | Menüeintrag |
|---|---|
| <kbd>⌘Z</kbd> | :ui[menu.edit > menu.undo] |
| <kbd>⇧⌘Z</kbd> | :ui[menu.edit > menu.redo] |
| <kbd>⌘X</kbd> | :ui[menu.edit > menu.cut] |
| <kbd>⌘C</kbd> | :ui[menu.edit > menu.copy] |
| <kbd>⌘V</kbd> | :ui[menu.edit > menu.paste] |
| <kbd>⌥⇧⌘V</kbd> | :ui[menu.edit > menu.pasteAndMatchStyle] |
| <kbd>⌘⌫</kbd> | :ui[menu.edit > menu.delete] |
| <kbd>⌘A</kbd> | :ui[menu.edit > menu.selectAll] |
| <kbd>⇧⌘W</kbd> | :ui[menu.edit > commit.reformatParagraph] |
| <kbd>⌘F</kbd> | :ui[menu.edit > menu.find > action.find] |
| <kbd>⌥⌘F</kbd> | :ui[menu.edit > menu.find > action.search] |
| <kbd>⌘G</kbd> | :ui[menu.edit > menu.find > menu.findNext] |
| <kbd>⇧⌘G</kbd> | :ui[menu.edit > menu.find > menu.findPrevious] |
| <kbd>⌘E</kbd> | :ui[menu.edit > menu.find > menu.useSelectionForFind] |
| <kbd>⌘J</kbd> | :ui[menu.edit > menu.find > menu.jumpToSelection] |
| <kbd>⌘:</kbd> | :ui[menu.edit > menu.spelling > menu.showSpelling] |
| <kbd>⌘;</kbd> | :ui[menu.edit > menu.spelling > menu.checkDocument] |

- Was :ui[menu.undo] widerrufen kann, lesen Sie unter [Widerrufen und Wiederholen](/guide/work/undo/#undo).
- :ui[menu.delete] löscht in einigen Listen auch die Auswahl. Siehe [Listen](#lists).
- :ui[action.find] und :ui[action.search] setzen beide die Einfügemarke in das Suchfeld in der Symbolleiste. Siehe [Suchen und filtern](/guide/history/browse/#search) und [Eine Datei finden](/guide/work/working-copy/#search).
- :ui[commit.reformatParagraph] funktioniert in der Commit-Nachricht. Siehe [Die Nachricht schreiben](/guide/work/commit/#write).

### Branches und Synchronisation {#sync}

| Kurzbefehl | Menüeintrag |
|---|---|
| <kbd>⌘B</kbd> | :ui[menu.repository > branch.createMenu] |
| <kbd>⇧⌘T</kbd> | :ui[menu.repository > tag.createMenu] |
| <kbd>⌃⌘P</kbd> | :ui[menu.repository > pr.create.menu] |
| <kbd>⇧⌘F</kbd> | :ui[menu.repository > sync.fetchMenu] |
| <kbd>⌥⇧⌘F</kbd> | :ui[menu.repository > sync.quickFetch] |
| <kbd>⇧⌘P</kbd> | :ui[menu.repository > sync.pullMenu] |
| <kbd>⌥⇧⌘P</kbd> | :ui[menu.repository > sync.quickPull] |
| <kbd>⇧⌘Y</kbd> | :ui[menu.repository > sync.syncMenu] |
| <kbd>⌥⇧⌘Y</kbd> | :ui[menu.repository > sync.quickSync] |
| <kbd>⇧⌘U</kbd> | :ui[menu.repository > sync.pushMenu] |
| <kbd>⌥⇧⌘U</kbd> | :ui[menu.repository > sync.quickPushMenu] |
| <kbd>⌃⌘U</kbd> | :ui[menu.repository > sync.forcePushMenu] |
| <kbd>⇧⌘B</kbd> | :ui[workspace.title > rewrite.checkout.menu] |
| <kbd>⇧⌘M</kbd> | :ui[workspace.title > sync.mergeMenu] |
| <kbd>⌥⇧⌘M</kbd> | :ui[workspace.title > sync.quickMerge] |
| <kbd>⇧⌘R</kbd> | :ui[workspace.title > sync.rebaseMenu] |
| <kbd>⌥⇧⌘R</kbd> | :ui[workspace.title > sync.quickRebase] |
| <kbd>⌃⇧⌘R</kbd> | :ui[workspace.title > rewrite.rebaseOnto.menu] |

Die Einträge mit <kbd>⌥⇧⌘</kbd> sind Schnellversionen. Sie ersetzen den Eintrag über ihnen, solange Sie bei geöffnetem Menü <kbd>⌥</kbd> gedrückt halten. Sie laufen sofort, ohne Dialogfenster. Ihre Kurzbefehle funktionieren, ohne das Menü zu öffnen. Siehe die Schnellversionen unter [Abrufen, Pullen und Pushen](/guide/branches/sync/#quick) und [Zusammenführen und Rebase](/guide/branches/merge-rebase/#quick).

### Änderungen und Commits {#changes}

| Kurzbefehl | Menüeintrag |
|---|---|
| <kbd>⇧⌘C</kbd> | :ui[workspace.title > working.commitMenu] |
| <kbd>⇧⌘E</kbd> | :ui[workspace.title > working.stageAllMenu] |
| <kbd>⌥⇧⌘E</kbd> | :ui[workspace.title > working.unstageAllMenu] |
| <kbd>⇧⌘⌫</kbd> | :ui[workspace.title > working.discardMenu] |
| <kbd>⇧⌘S</kbd> | :ui[workspace.title > stash.saveMenu] |
| <kbd>⌥⇧⌘S</kbd> | :ui[workspace.title > stash.applyMenu] |
| <kbd>⌃⇧⌘S</kbd> | :ui[workspace.title > stash.snapshotMenu] |
| <kbd>⌃⇧⌘D</kbd> | :ui[workspace.title > externalTool.compare > externalTool.compare.workingTreeToBase] |
| <kbd>⇧⌘D</kbd> | :ui[menu.repository > externalTool.openDiffTool] |

## Wahltaste gedrückt halten {#option}

Wenn Sie <kbd>⌥</kbd> gedrückt halten, ändern sich einige Tasten und Menüs. Lassen Sie los, und sie wechseln zurück.

| Wo | Was sich ändert |
|---|---|
| Die Tasten zum Abrufen, Pullen und Pushen in der Symbolleiste, sowie die zum Synchronisieren, Zusammenführen und für den Rebase, wenn Sie sie hinzugefügt haben | Sie werden zu Schnellversionen. Siehe [Abrufen, Pullen und Pushen](/guide/branches/sync/#quick). |
| Der Commit-Bereich, solange keines der Nachrichtenfelder bearbeitet wird | Er wechselt zum Ändern des letzten Commits. Siehe [Den letzten Commit ändern](/guide/work/commit/#amend). |
| :ui[working.stageAll] über der Dateiliste, solange nur ein Teil der Änderungen gestagt ist | Die Taste wird zu :ui[working.unstageAll]. Siehe [Ganze Dateien stagen](/guide/work/diff/#stage-file). |
| Das Menü von Dateien in der Arbeitskopie | Die Stash-Einträge werden zu Schnellversionen. Siehe [Einzelne Dateien stashen](/guide/work/stash/#partial). |
| Das Menü eines Submoduls | Abrufen und Aktualisieren werden zu Schnellversionen. Siehe [Abrufen und aktualisieren](/guide/advanced/submodules/#update). |
| Das Menü eines Branches mit Eltern-Branch | Das Aktualisieren vom Eltern-Branch wird zur Schnellversion. Siehe [Einen Branch von seinem Eltern-Branch aktualisieren](/guide/branches/merge-rebase/#update). |
| Das Menü eines Commits | Das Sichern eines Patches wird zur Schnellversion. Sind zwei Commits ausgewählt, läuft ihr Vergleich in umgekehrter Richtung. Siehe [Einen Patch sichern](/guide/history/commit-details/#patch). |
| :ui[compare.submit], wenn zwei Commits ausgewählt sind | Der Vergleich läuft in umgekehrter Richtung. Siehe [Mehrere Commits](/guide/history/commit-details/#multiple). |
| Ziehen | Siehe [Ziehen mit der Wahltaste](#drag). |

## Commit-Bereich {#commit-area}

| Tasten | Was sie bewirken |
|---|---|
| <kbd>↩</kbd> oder <kbd>Tab</kbd> im Betreff | Wechselt zur Beschreibung |
| <kbd>Tab</kbd> in der Beschreibung | Wechselt zur Dateiliste |
| <kbd>⇧Tab</kbd> in der Beschreibung | Wechselt zurück zum Betreff |
| <kbd>⌘↩</kbd>, während Sie in der Nachricht tippen | Klickt auf die Haupttaste des Commit-Bereichs, etwa :ui[working.commit]. Die <kbd>Eingabetaste</kbd> auf einem Ziffernblock bewirkt dasselbe. |
| <kbd>⌥⌘↩</kbd>, solange keines der Nachrichtenfelder bearbeitet wird | Ändert den letzten Commit. Siehe [Den letzten Commit ändern](/guide/work/commit/#amend). |
| <kbd>↑</kbd> <kbd>↓</kbd>, <kbd>↩</kbd>, <kbd>Esc</kbd> in der Vervollständigungsliste | Einen Treffer wählen, ihn einfügen und die Liste schließen |

Siehe [Änderungen committen](/guide/work/commit/).

## Dateiliste {#file-list}

Diese Tasten funktionieren in der Dateiliste der Arbeitskopie:

| Tasten | Was sie bewirken |
|---|---|
| <kbd>Leertaste</kbd> | Stagt oder unstagt die ausgewählten Dateien. Wenn :ui[files.spacebar] auf :ui[files.spacebar.quickLook] steht, zeigt sie die Dateien stattdessen in der Übersicht. Siehe [Dateiliste](/guide/settings/general/#file-list). |
| <kbd>⌘⌫</kbd> | Legt die ausgewählten Dateien in den Papierkorb |
| <kbd>⇧Tab</kbd> | Wechselt zurück zur Beschreibung der Commit-Nachricht |

## Zeilen in einem Diff {#diff-lines}

Drücken Sie in der Arbeitskopie <kbd>Tab</kbd>, bis die Zeilennummern eines Blocks den Tastaturfokus haben. Dann:

| Tasten | Was sie bewirken |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Bewegen zwischen den auswählbaren Zeilen |
| <kbd>Leertaste</kbd> | Wählt die Zeile aus oder hebt die Auswahl auf |
| <kbd>Tab</kbd> oder <kbd>⇧Tab</kbd> | Verlässt die Zeilennummern |

Mit der Maus halten Sie <kbd>⇧</kbd> gedrückt und klicken auf eine Zeilennummer, um alle Zeilen dazwischen auszuwählen. Siehe [Zeilen stagen](/guide/work/diff/#lines).

## Listen {#lists}

| Wo | Tasten | Was sie bewirken |
|---|---|---|
| Die Commit-Liste im Verlauf | <kbd>⌘C</kbd> | Kopiert die vollständigen Hashes der ausgewählten Commits |
| Der Änderungssatz eines Commits | <kbd>↑</kbd> <kbd>↓</kbd> | Bewegen die Auswahl |
| Die geänderten Dateien in den ganzseitigen Details | <kbd>↩</kbd> | Öffnet die ausgewählten Dateien in ihren Standard-Apps |
| Der Dateibaum eines Commits | <kbd>↩</kbd> | Öffnet oder schließt den ausgewählten Ordner |
| Dateiverlauf | <kbd>↩</kbd> | Öffnet den ausgewählten Commit in den ganzseitigen Details |
| Die Seitenleiste | <kbd>⌘⌫</kbd> | Löscht nach Rückfrage die ausgewählten Branches, Tags, das Remote oder das Submodul |
| Das Filterfeld der Seitenleiste | <kbd>Esc</kbd> | Leert das Feld |
| Stashes | <kbd>⌘⌫</kbd> | Löscht nach Rückfrage die ausgewählten Stashes |
| Branch-Übersicht | <kbd>⌘⌫</kbd> | Löscht nach Rückfrage die ausgewählten Branches |
| Das Fenster „Repositorys“ | <kbd>↩</kbd> | Benennt den ausgewählten Eintrag um |
| Das Fenster „Repositorys“ | <kbd>⌫</kbd> oder <kbd>⌦</kbd> | Entfernt die ausgewählten Einträge. Siehe [Repositorys entfernen](/guide/repositories/manager/#delete). |
| Das beim Start gezeigte Fenster | <kbd>↩</kbd> | Öffnet das ausgewählte Repository. Siehe [Dort weitermachen, wo Sie aufgehört haben](/guide/repositories/navigation/#restore). |
| Die Konversation eines Pull Requests | <kbd>↩</kbd> | Öffnet den ausgewählten Commit |
| Die Konversation eines Pull Requests | <kbd>⌘S</kbd> | Klickt auf :ui[pullRequests.addComment] |
| :ui[settings.themes] in den Einstellungen | <kbd>↩</kbd> | Benennt das ausgewählte Thema um |
| :ui[settings.appIcon.label] in den Einstellungen | Pfeiltasten, <kbd>Leertaste</kbd> | Bewegen zwischen den Symbolen und verwenden das aktuelle |
| :ui[settings.sshHosts] in den Einstellungen | <kbd>↩</kbd> | Öffnet den ausgewählten Alias zum Bearbeiten |

In Listen, in denen Sie mehrere Objekte auswählen können, wählt ein Klick mit <kbd>⇧</kbd> einen Bereich aus. Ein Klick mit <kbd>⌘</kbd> fügt ein einzelnes Objekt hinzu oder entfernt es. Klicken Sie in der Seitenleiste mit <kbd>⌘</kbd> auf Branches und Tags, um ihren Verlauf gemeinsam zu sehen. Siehe [Den Verlauf öffnen](/guide/history/browse/#open).

Halten Sie <kbd>⌘</kbd> gedrückt und doppelklicken Sie auf einen Branch, der in einem anderen Worktree ausgecheckt ist. Dieser Worktree öffnet sich in einem neuen Tab. Siehe [Einen Branch auschecken](/guide/branches/branches/#checkout).

## Schnellaktionen {#quick-actions}

Diese Tasten funktionieren im Fenster [Schnellaktionen](/guide/repositories/navigation/#quick-actions):

| Tasten | Was sie bewirken |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Bewegen die Auswahl |
| <kbd>↩</kbd> | Führt die Standardaktion des ausgewählten Objekts aus |
| <kbd>Tab</kbd>, oder <kbd>→</kbd> am Ende des Textes | Listet alle Aktionen für das ausgewählte Objekt auf |
| <kbd>←</kbd> ohne Text, oder <kbd>⇧Tab</kbd> | Kehrt aus der Liste der Aktionen zurück |
| <kbd>Esc</kbd> | Löscht den Text. Ohne Text: kehrt aus der Liste der Aktionen zurück oder schließt das Fenster. |

## Dialogfenster {#dialogs}

In einem Dialogfenster klickt <kbd>↩</kbd> auf die hervorgehobene Taste. <kbd>Esc</kbd> klickt auf die Taste zum Abbrechen. Wenn ein Dialogfenster keine solche Taste hat, klickt auch <kbd>Esc</kbd> auf die hervorgehobene Taste.

## Ziehen mit der Wahltaste {#drag}

Halten Sie beim Loslassen <kbd>⌥</kbd> gedrückt, um etwas anderes zu tun:

| Ziehen | Auf | Ohne <kbd>⌥</kbd> | Mit <kbd>⌥</kbd> |
|---|---|---|---|
| Einen lokalen Branch | :ui[workspace.title] oder den Branch, auf dem Sie sich befinden | Das Dialogfenster zum Zusammenführen | Das Dialogfenster für den Rebase |
| Einen Remote-Branch | Den Branch, auf dem Sie sich befinden | Das Dialogfenster zum Pullen | Er wird zum Upstream Ihres Branches. |
| Commits aus dem Verlauf | :ui[workspace.title] oder den Branch, auf dem Sie sich befinden | Sie per Cherry-Pick übernehmen | Sie per Revert rückgängig machen |
| Commits im Verlauf | Einen anderen Commit in der Liste | Sie in ihn zusammenfassen | Stattdessen per Fixup einfügen |

Siehe [Drag & Drop](/guide/branches/merge-rebase/#drag-and-drop) und [Zusammenfassen, Fixup, Löschen und Verschieben](/guide/history/rewrite/#interactive).

## Siehe auch

- [Fenster und Navigation](/guide/repositories/navigation/)
- [Änderungen committen](/guide/work/commit/)
- [Änderungen prüfen und stagen](/guide/work/diff/)
- [Zusammenführen und Rebase](/guide/branches/merge-rebase/)
