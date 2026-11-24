---
title: "Commit-Details"
description: "Details, Änderungssatz, Dateibaum und Signaturstatus eines Commits ansehen, Revisionen vergleichen und Dateien exportieren."
---

Wählen Sie im [Verlauf](/guide/history/browse/) einen Commit aus, und die rechte Spalte zeigt seine Details: wer ihn wann erstellt hat, die vollständige Nachricht und die Dateien, die er geändert hat.

## Der Kopf {#header}

Die Leiste oben zeigt den Kurz-Hash des Commits und die Tasten :ui[history.changeset] und :ui[history.tree]. Sie können den Hash auswählen und kopieren. Unter der Leiste listet der Kopf auf:

- :ui[history.author] und :ui[history.committer], mit ihren Datumsangaben. Der Avatar rechts gehört dem Autor. Hat jemand anderes committet, steht der Avatar des Committers links daneben.
- :ui[history.refs], die Branches und Tags, die auf den Commit zeigen
- :ui[history.hash], der vollständige Hash
- :ui[history.parentHash], eine Zeile für jeden Eltern-Commit
- :ui[history.treeHash]
- Die Signatur, falls der Commit signiert ist. Siehe [Signaturen](#signatures).

Klicken Sie oben rechts auf den Pfeil, um den Kopf auf Autor, Datum und Refs zu verkleinern. Spooky merkt sich Ihre Wahl. Auf den Kopf folgt die vollständige Nachricht.

### Aktionstasten {#actions}

Bewegen Sie den Zeiger über die Details, und auf der Linie zwischen Kopf und Nachricht wird eine Reihe von Tasten eingeblendet:

- :ui[history.rollback] öffnet das Dialogfenster zum Zurücksetzen des aktuellen Branches auf diesen Commit. Siehe [Auf einen älteren Commit zurücksetzen](/guide/history/rewrite/#reset).
- :ui[rewrite.revert.button] öffnet das Dialogfenster zum Hinzufügen eines Commits, der diesen aufhebt. Siehe [Einen Commit per Revert rückgängig machen](/guide/history/rewrite/#revert).
- :ui[history.diffTool] öffnet alle Änderungen des Commits in Ihrem Vergleichswerkzeug. Siehe [In einer anderen App vergleichen](/guide/work/diff/#external).

:ui[history.rollback] und :ui[rewrite.revert.button] erscheinen nur, solange die Liste den Branch zeigt, auf dem Sie sich befinden.

## Der Änderungssatz {#changeset}

:ui[history.changeset] listet die Dateien auf, die der Commit geändert hat, sortiert nach Pfad. Die Zeile über der Liste zählt Dateien, Hinzufügungen und Löschungen.

- Klicken Sie auf den Pfeil neben einer Datei, um ihre Änderungen zu zeigen. Um die Änderungen aller Dateien ein- oder auszublenden, klicken Sie am Anfang der Zeile über der Liste auf :ui[history.expandAll] oder :ui[history.collapseAll], oder drücken Sie <kbd>⌃⌘→</kbd> oder <kbd>⌃⌘←</kbd>.
- Klicken Sie auf eine Datei, um sie auszuwählen. Mit <kbd>⇧</kbd>-Klick oder <kbd>⌘</kbd>-Klick wählen Sie mehrere aus. <kbd>↑</kbd> <kbd>↓</kbd> bewegen die Auswahl.

Dateien sind anfangs eingeklappt. Damit sie sich von selbst öffnen, wählen Sie unter :ui[history.autoExpand.title] in :ui[menu.view > history.diffs] eine Zahl. Ein Commit, der nicht mehr Dateien ändert, öffnet jeden Diff. :ui[history.autoExpand.always] öffnet sie immer.

Bei einem Merge-Commit entscheidet :ui[history.mergeDiff] unter :ui[app.name > settings.title] › :ui[settings.general], was der Änderungssatz zeigt:

- :ui[history.mergeDiff.firstParent] (der Standard) zeigt die Änderungen, die der Merge in den Branch gebracht hat.
- :ui[history.mergeDiff.mergedFilePaths] zeigt nur die Dateien, die sich von jedem Eltern-Commit unterscheiden.
- :ui[history.mergeDiff.off] zeigt keine Änderungen.

Siehe [Verlauf und Diffs](/guide/settings/general/#history).

Klicken Sie mit der rechten Maustaste auf eine Datei, um:

- Ihren Pfad oder ihren Pfad innerhalb des Repositorys zu kopieren
- Die Datei im Zustand dieses Commits, ihren Blame oder ihren Verlauf anzusehen. Siehe [Dateiverlauf und Blame](/guide/history/file-views/).
- Sie in Ihrem Vergleichswerkzeug zu öffnen, verglichen mit dem ersten Eltern-Commit des Commits
- Sie in der Arbeitskopie auf die Version dieses Commits zurückzusetzen. Siehe [Eine Datei aus einer Revision wiederherstellen](/guide/history/file-views/#restore).
- Ihre Version aus diesem Commit auf Ihrem Mac zu sichern

Sind mehrere Dateien ausgewählt, können Sie sie zusammen im Vergleichswerkzeug öffnen, wiederherstellen oder exportieren.

## Der Dateibaum {#tree}

:ui[history.tree] zeigt jede Datei im Repository im Zustand dieses Commits, nicht nur die geänderten. Klicken Sie auf den Pfeil neben einem Ordner, um ihn zu öffnen.

Klicken Sie mit der rechten Maustaste auf eine Datei oder einen Ordner, um:

- Die Datei in ihrer Standard-App oder in einer App Ihrer Wahl zu öffnen
- Die Datei, ihren Blame oder ihren Verlauf anzusehen
- Das Objekt in der Arbeitskopie auf die Version dieses Commits zurückzusetzen
- Es zu exportieren oder als ZIP-Archiv zu sichern

Öffnen und Ansehen funktionieren nur mit Dateien. Sind mehrere Objekte ausgewählt, können Sie sie zusammen öffnen, wiederherstellen, exportieren oder archivieren. Exportierte Objekte kommen in einen Ordner Ihrer Wahl. Liegen dort bereits Objekte mit denselben Namen, fragt Spooky nach, bevor es sie überschreibt.

## Details als ganze Seite {#full-page}

Doppelklicken Sie in der Liste auf einen Commit, um seinen Details das ganze Fenster zu geben. Die linke Spalte zeigt den Commit, darunter die Liste der geänderten Dateien. Die rechte Spalte zeigt die Änderungen in der ausgewählten Datei.

- Klicken Sie oben links auf den Kurz-Hash, um einen anderen Commit zu wählen. Doppelklicken Sie in der Liste auf einen Commit, um zu ihm zu wechseln.
- Doppelklicken Sie auf eine Datei oder drücken Sie den <kbd>Zeilenschalter</kbd>, um ihre Version aus diesem Commit in der Standard-App zu öffnen.

Um zum Verlauf zurückzukehren, wählen Sie :ui[menu.view > navigation.back] (<kbd>⌘[</kbd>) oder klicken Sie in der Symbolleiste auf :ui[toolbar.previous].

## Mehrere Commits {#multiple}

Wählen Sie mehr als einen Commit aus, und die rechte Spalte zeigt, wie viele es sind. Darunter liegen diese Tasten:

- :ui[rewrite.cherryPick.button] wendet die Commits auf den Branch an, auf dem Sie sich befinden. Zeigt die Liste diesen Branch, heißt die Taste stattdessen :ui[rewrite.revert.button]. Siehe [Verlauf umschreiben](/guide/history/rewrite/).
- :ui[compare.submit] erscheint, wenn genau zwei Commits ausgewählt sind. Die Taste zeigt, was sich vom älteren zum neueren Commit geändert hat. Halten Sie <kbd>⌥</kbd> gedrückt, um in der anderen Richtung zu vergleichen.

## Signaturen {#signatures}

Die Details prüfen die Signatur des Commits, den Sie auswählen. Der erweiterte Kopf zeigt den Schlüssel und den Status, etwa :ui[signature.good].

Um Signaturen auch in der Liste zu sehen, aktivieren Sie :ui[signature.verify] in den [Darstellungsoptionen](/guide/history/browse/#view-options). Signierte Commits erhalten dann einen Punkt am Ende der Zeile:

- Grün: Die Signatur ist gültig.
- Rot: Die Signatur ist ungültig.
- Gelb: jeder andere Status, etwa ein abgelaufener Schlüssel oder eine Signatur, die Spooky nicht prüfen kann.

Klicken Sie auf den Punkt, um den Schlüssel und den Status zu sehen.

## Zwei Revisionen vergleichen {#compare}

So sehen Sie, was sich zwischen zwei beliebigen Commits, Branches oder Tags geändert hat:

1. Wählen Sie :ui[menu.repository > compare.menu] in der Menüleiste. Oder klicken Sie mit der rechten Maustaste auf einen Commit und wählen Sie :ui[compare.menuFrom]{1="e2dda2bc"}, um von ihm auszugehen.
2. Füllen Sie :ui[compare.base] und :ui[compare.target] aus. Die Menüs listen Ihre Branches, Remote-Branches und Tags auf. Sie können auch einen Hash eingeben.
3. Klicken Sie auf :ui[compare.submit].

Die rechte Spalte zeigt den Vergleich. :ui[compare.commits] listet die Commits auf, die die zweite Revision hat und die erste nicht. :ui[history.changeset] zeigt die Änderungen von der ersten zur zweiten. Zum Schließen klicken Sie oben rechts auf × oder wählen Sie einen anderen Commit aus.

Sind zwei Commits ausgewählt, bietet das Menü direkt :ui[compare.menuPair]{1="e2dda2bc" 2="f6b437e0"} an.

## Dateien exportieren {#export}

So sichern Sie alle Dateien eines Commits im damaligen Zustand:

1. Klicken Sie mit der rechten Maustaste auf einen Commit und wählen Sie :ui[export.menuFrom]{1="e2dda2bc"} im Menü. :ui[menu.repository > export.menu] in der Menüleiste geht vom ausgewählten Commit aus.
2. Prüfen Sie die Revision. Für eine einzelne ZIP-Datei aktivieren Sie :ui[export.createArchive].
3. Klicken Sie auf :ui[export.submit] und wählen Sie den Speicherort.

Ohne Archiv erhalten Sie einen Ordner, der nach dem Repository und dem Kurz-Hash benannt ist.

Der Export erscheint im [Fenster „Aktivität“](/guide/advanced/queue-activity/), wo Sie ihn abbrechen können.

## Einen Patch sichern {#patch}

Ein Patch ist eine Textdatei mit den Änderungen eines Commits. Sie können ihn mit `git am` in einem anderen Repository anwenden.

1. Klicken Sie mit der rechten Maustaste auf einen Commit und wählen Sie :ui[patch.menu]{1="e2dda2bc"} im Menü. Sind mehrere Commits ausgewählt, sichert der Eintrag für jeden einen Patch.
2. Aktivieren Sie :ui[patch.omitPrefixes], um `a/` und `b/` vor jedem Pfad wegzulassen.
3. Klicken Sie auf :ui[patch.save] und wählen Sie einen Ordner.

Jeder Commit erhält eine eigene Datei, nummeriert vom ältesten zum neuesten, wie `0001-Add-a-theme-toggle-to-the-header.patch`. Danach öffnet sich der Finder mit den ausgewählten Dateien. Auch das Sichern erscheint im Fenster „Aktivität“.

Halten Sie im Menü <kbd>⌥</kbd> gedrückt, um :ui[patch.quickMenu]{1="e2dda2bc"} zu erhalten. Der Eintrag sichert sofort in den Ordner des Repositorys, mit Ihrer letzten Wahl für :ui[patch.omitPrefixes].

:::note[Server-Repositorys]
Exporte und Patches, die Sie mit :ui[patch.save] sichern, kommen auf Ihren Mac. Ein schnell gesicherter Patch kommt in den Ordner des Repositorys auf dem Server.
:::

## Commit-Informationen kopieren {#copy}

Klicken Sie mit der rechten Maustaste auf einen Commit, um Folgendes zu kopieren:

- :ui[history.copyHash], den vollständigen Hash
- :ui[history.copyInfo], den Kurz-Hash und die erste Zeile der Nachricht

Sind mehrere Commits ausgewählt, erhalten Sie für jeden eine Zeile.

## Siehe auch

- [Verlauf durchsuchen](/guide/history/browse/)
- [Dateiverlauf und Blame](/guide/history/file-views/)
- [Verlauf umschreiben](/guide/history/rewrite/)
