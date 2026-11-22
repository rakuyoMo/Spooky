---
title: "Dateiverlauf und Blame"
description: "Eine Datei durch ihren Verlauf verfolgen, mit Blame sehen, wer jede Zeile geändert hat, eine Datei im Zustand einer Revision ansehen und sie aus dieser Revision wiederherstellen."
---

Diese Ansichten betrachten jeweils eine Datei: die Commits, die sie geändert haben, wer jede Zeile geschrieben hat und wie sie zu einem beliebigen früheren Zeitpunkt aussah.

## Dateiverlauf {#file-history}

So sehen Sie jeden Commit, der eine Datei geändert hat:

- Klicken Sie in der Arbeitskopie mit der rechten Maustaste auf die Datei und wählen Sie :ui[fileHistory.showHistoryOf]{1="units.ts"}.
- Oder bewegen Sie den Zeiger über den Dateinamen oben in der rechten Spalte und klicken Sie auf :ui[fileHistory.title].
- Klicken Sie in den [Commit-Details](/guide/history/commit-details/#changeset) mit der rechten Maustaste auf eine Datei im Änderungssatz oder im Dateibaum und wählen Sie denselben Eintrag.

In der Arbeitskopie können Sie auch einen Ordner auswählen und oben in der rechten Spalte auf :ui[fileHistory.title] klicken. Der Verlauf umfasst dann jede Datei darin.

Die linke Spalte listet die Commits auf, den neuesten zuerst, nach Monat gruppiert. Oben stehen der Dateiname und die Anzahl der Commits. Klicken Sie auf den Dateinamen, um zu einer anderen Datei zu wechseln.

Wählen Sie einen Commit aus, um rechts zu sehen, was er in der Datei geändert hat. Wechseln Sie zu :ui[showFile.raw], um die ganze Datei im Zustand dieses Commits zu sehen, oder zurück zu :ui[fileHistory.diff]. Bewegen Sie den Zeiger oben über den Kurz-Hash, um mehr zu sehen:

- :ui[blame.title] zeigt, wer bei diesem Commit jede Zeile geschrieben hat. Siehe [Blame](#blame).
- :ui[fileHistory.showCommit] öffnet den Commit in den [Details als ganze Seite](/guide/history/commit-details/#full-page).
- :ui[externalTool.action.diffTool] öffnet die Änderung in Ihrem Vergleichswerkzeug.

::screenshot[Der Dateiverlauf von src/units.ts. Die linke Spalte zeigt den Dateinamen und die Anzahl der Commits, darunter die Commits, die die Datei geändert haben, nach Monat gruppiert. Rechts steht, was der ausgewählte Commit in der Datei geändert hat. Der Zeiger ruht auf dem Kurz-Hash. Oben rechts erscheinen die Tasten für Blame, zum Anzeigen des Commits und für das Vergleichswerkzeug, neben dem Umschalter zwischen Diff und Rohansicht.]{name="history-file-history" frame="window" markers="28.5,9 94.6,13.25 86,13.25"}

1. Der Dateiname und die Anzahl der Commits
2. Der Umschalter zwischen :ui[fileHistory.diff] und :ui[showFile.raw]
3. Die Tasten, die erscheinen, solange der Zeiger auf dem Kurz-Hash liegt

Doppelklicken Sie auf einen Commit oder drücken Sie den <kbd>Zeilenschalter</kbd>, um ihn ebenfalls in den Details als ganze Seite zu öffnen. Klicken Sie mit der rechten Maustaste auf einen Commit, um dieselben Aktionen zu erhalten, dazu das Wiederherstellen und Exportieren der Datei im Zustand dieses Commits.

### Den Dateiverlauf durchsuchen {#file-history-search}

Tippen Sie in das Suchfeld in der Symbolleiste, um die Liste einzugrenzen. Klicken Sie auf die Lupe im Feld, um zu wählen, wonach gesucht wird: :ui[fileHistory.scope.message], :ui[fileHistory.scope.hash], :ui[fileHistory.scope.author] oder :ui[fileHistory.scope.committer].

- Nachrichten, Autoren und Committer werden mit dem eingegebenen Text verglichen, ohne Rücksicht auf Groß- und Kleinschreibung. Autoren und Committer passen nach Name oder E-Mail-Adresse.
- Ein Commit-Hash, Branch oder Tag zeigt den letzten Commit bis zu diesem Punkt, der die Datei geändert hat.

## Blame {#blame}

Blame zeigt die ganze Datei, mit einer Spalte rechts, die angibt, welcher Commit jeden Block von Zeilen zuletzt geändert hat. Jeder Block zeigt den Avatar des Autors, die erste Zeile der Commit-Nachricht, den Autor und wie lange es her ist.

- Klicken Sie in der Arbeitskopie mit der rechten Maustaste auf eine Datei und wählen Sie :ui[blame.show]{1="units.ts"}. Oder bewegen Sie den Zeiger über den Dateinamen oben in der rechten Spalte und klicken Sie auf :ui[blame.title].
- Wählen Sie im Änderungssatz oder Dateibaum eines Commits :ui[fileHistory.blameAt]{1="units.ts" 2="e2dda2bc"}, um die Datei im damaligen Zustand zu sehen.

::screenshot[Blame für src/units.ts. Die Datei steht links. Die Spalte rechts zeigt Avatar, Nachricht, Autor und Alter des Commits, der jeden Block zuletzt geändert hat. Die Blöcke aus Drop trailing zeros from temperatures sind hervorgehoben.]{name="history-blame" frame="window" markers="84,22 84,82.5"}

1. Die Spalte, die zeigt, welcher Commit jeden Block zuletzt geändert hat
2. Die hervorgehobenen Blöcke des angeklickten Commits

Klicken Sie auf einen Block, um eine Zusammenfassung seines Commits zu sehen. Jeder Block aus diesem Commit leuchtet auf. Doppelklicken Sie auf einen Block, um seinen Commit in den Details als ganze Seite zu öffnen. Um die Spalte breiter oder schmaler zu machen, ziehen Sie ihren linken Rand. Spooky merkt sich die Breite.

Blame braucht eine Datei, die bereits committet ist. Neue oder nicht verfolgte Dateien, Binärdateien und Submodule lassen sich nicht anzeigen.

## Eine Datei im Zustand einer Revision ansehen {#show-file}

So lesen Sie eine Datei im Zustand eines beliebigen Commits, ohne Ihre Arbeitskopie zu ändern:

- Klicken Sie in der Arbeitskopie mit der rechten Maustaste auf eine Datei und wählen Sie :ui[showFile.show]{1="units.ts"}. Das zeigt die Version in HEAD.
- Wählen Sie im Änderungssatz oder Dateibaum eines Commits :ui[fileHistory.showAt]{1="units.ts" 2="e2dda2bc"}.

Der Kopf liest sich wie ein Pfad: Revision › Datei.

- Klicken Sie auf die Revision, um einen anderen Commit zu wählen. Doppelklicken Sie in der Liste auf einen Commit, um zu ihm zu wechseln.
- Klicken Sie auf den Dateinamen, um eine andere Datei aus demselben Commit zu wählen.
- :ui[showFile.raw] und :ui[blame.title] wechseln zwischen der reinen Datei und [Blame](#blame).
- Bewegen Sie den Zeiger über den Kopf, um :ui[fileHistory.title] und :ui[fileHistory.showCommit] zu erhalten.

Unter dem Kopf zählt Spooky die Personen, die die Datei geändert haben, mit ihren Avataren. Der Text verwendet Ihr Thema und die Einstellungen unter :ui[app.name > settings.title] › :ui[settings.text]. Siehe [Text](/guide/settings/appearance/#text).

Wie Blame kann diese Ansicht keine neuen oder nicht verfolgten Dateien, Binärdateien oder Submodule anzeigen.

## Eine Datei aus einer Revision wiederherstellen {#restore}

So versetzen Sie eine Datei in den Zustand eines älteren Commits:

1. Klicken Sie im Dateiverlauf mit der rechten Maustaste auf den Commit und wählen Sie :ui[fileHistory.restoreAt]{1="units.ts" 2="e2dda2bc"} im Menü. In den [Commit-Details](/guide/history/commit-details/#changeset) heißt der Eintrag stattdessen :ui[fileHistory.restoreInWorkingCopy]{1="units.ts" 2="e2dda2bc"}.
2. Spooky fragt vorher nach. Klicken Sie auf :ui[fileHistory.restore.submit].

Die gestagten und die nicht gestagten Änderungen in der Datei werden ersetzt. Gab es die Datei in diesem Commit nicht, wird sie gelöscht. Nichts wird committet: Die wiederhergestellte Datei erscheint in der Arbeitskopie als gestagte Änderung.

Um das zurückzunehmen, wählen Sie :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

Aus dem Änderungssatz oder dem Dateibaum können Sie mehrere Dateien oder Ordner auf einmal wiederherstellen.

:::note[Server-Repositorys]
Die Datei wird auf dem Server überschrieben. Aktivieren Sie :ui[dialog.doNotAskAgain], um die Frage beim nächsten Mal zu überspringen. Um wieder gefragt zu werden, aktivieren Sie :ui[settings.warnRestoringOnServer] unter :ui[app.name > settings.title] › :ui[settings.general]. Siehe [Bestätigungen](/guide/settings/general/#confirmations).
:::

## Siehe auch

- [Commit-Details](/guide/history/commit-details/)
- [Arbeitskopie](/guide/work/working-copy/)
- [Widerrufen und Wiederherstellen](/guide/work/undo/)
