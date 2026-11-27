---
title: "Arbeitskopie"
description: "Den Status geänderter Dateien lesen, sie als Liste oder Baum anzeigen, sortieren und durchsuchen, mit nicht verfolgten und ignorierten Dateien umgehen sowie Dateiaktionen und die Übersicht nutzen."
---

Die Arbeitskopie zeigt, was Sie seit dem letzten Commit geändert haben. Hier wählen Sie die Änderungen für den nächsten Commit aus, sehen in Dateien hinein und halten Git von Dateien fern, die es nicht verfolgen soll.

Um sie zu öffnen, klicken Sie oben in der Seitenleiste auf :ui[workspace.title] oder wählen Sie :ui[menu.view > menu.showWorkingCopy] (<kbd>⌘1</kbd>). Der Commit-Bereich liegt oben in der mittleren Spalte, darunter stehen die geänderten Dateien. Den Commit-Bereich beschreibt [Änderungen committen](/guide/work/commit/).

## Den Status lesen {#status}

Jede geänderte Datei hat eine Zeile mit einem Markierungsfeld, zwei Statusplaketten und ihrem Namen.

- Das Markierungsfeld zeigt, ob die Änderung gestagt ist. Ein Strich bedeutet, dass nur ein Teil der Datei gestagt ist.
- Die linke Plakette steht für die gestagte Änderung, die rechte für die Änderung, die noch nicht gestagt ist.
- Die Buchstaben sind die Statuscodes von Git: M für geändert, A für hinzugefügt, D für gelöscht und R für umbenannt. Eine neue Datei, die Git noch nicht verfolgt, zeigt ?, eine ignorierte Datei zeigt !.
- Eine Datei mit einem Konflikt zeigt zwei Konfliktcodes, etwa U U. Siehe [Konflikte lösen](/guide/work/conflicts/).

Bewegen Sie den Zeiger über die Plaketten, um den Status in Worten zu sehen.

Die Zeile über der Liste zeigt den aktuellen Branch und dahinter den Remote-Branch, dem er folgt. Folgt er keinem, steht dort :ui[branch.noTracking].

Spooky aktualisiert die Liste von selbst, wenn sich Dateien ändern. Um alles neu einzulesen, klicken Sie auf :ui[action.refresh] oder drücken Sie <kbd>⌘R</kbd>.

:::note[Server-Repositorys]
Spooky fragt den Server alle 2 Sekunden nach Änderungen, solange das Fenster des Repositorys vorn ist, sonst alle 10 Sekunden. Antwortet der Server langsam, fragt Spooky seltener. So lange kann es dauern, bis eine Änderung auf dem Server erscheint. Siehe [Worin sich Server-Repositorys unterscheiden](/guide/server/overview/#differences).
:::

## Liste oder Baum anzeigen {#view}

Das Menü :ui[menu.view > files.statusMenu] legt fest, was die Liste zeigt. Die Taste am rechten Ende der Branch-Zeile enthält dieselben Einträge.

| Eintrag | Wirkung |
|---|---|
| :ui[working.list] (<kbd>⌃⌘L</kbd>) | Eine Zeile pro Datei, mit vollständigem Pfad |
| :ui[working.tree] (<kbd>⌃⌘T</kbd>) | Dateien nach Ordnern gruppiert. Doppelklicken Sie auf einen Ordner, um ihn ein- oder auszublenden. |
| :ui[files.showNonModified] (<kbd>⌃⌘M</kbd>) | Listet jede Datei im Repository auf, nicht nur die geänderten. Im Baum verfügbar. |
| :ui[files.showIgnored] (<kbd>⌃⌘I</kbd>) | Listet die Dateien auf, die Git ignoriert |
| :ui[files.showAssumeUnchanged] | Listet die als assume-unchanged markierten Dateien auf. Siehe [Nicht verfolgte und ignorierte Dateien](#untracked-ignored). |

Jedes Repository merkt sich, ob es eine Liste oder einen Baum zeigt. Am Anfang ist es eine Liste. Die übrigen Einträge gelten für alle Repositorys.

## Sortieren {#sort}

Klicken Sie auf den Spaltentitel :ui[status.filename] oder :ui[status.column], um danach zu sortieren. Ein weiterer Klick kehrt die Reihenfolge um. Die Reihenfolge ist in allen Repositorys und Fenstern gleich.

Der erste Klick auf :ui[status.column] stellt gestagte Dateien nach oben. Danach folgen die übrigen Änderungen, dann neue Dateien und zuletzt die unveränderten und ignorierten.

## Eine Datei finden {#search}

1. Drücken Sie <kbd>⌘F</kbd> oder klicken Sie in das Suchfeld in der Symbolleiste. Darin steht :ui[history.search.forFile].
2. Geben Sie einen Teil des Dateipfads ein. Spooky schlägt Dateien vor, die diese Buchstaben in derselben Reihenfolge enthalten.
3. Wählen Sie eine Datei, um nur diesen Pfad aufzulisten. Der letzte Vorschlag listet jede Datei auf, deren Pfad Ihre Eingabe enthält.

Drücken Sie <kbd>Esc</kbd>, um das Suchfeld zu verlassen. Die Liste bleibt gefiltert. Leeren Sie das Suchfeld, um wieder alle Dateien zu sehen.

## Nicht verfolgte und ignorierte Dateien {#untracked-ignored}

Eine neue Datei ist nicht verfolgt, bis Sie sie stagen und committen. Nicht verfolgte Dateien zeigen ? und stehen bei den anderen Änderungen. Um eine in den nächsten Commit aufzunehmen, stagen Sie sie wie jede andere Änderung.

Manche Dateien gehören nie in einen Commit, etwa Build-Ergebnisse oder lokale Notizen. Damit Git sie nicht auflistet, klicken Sie mit der rechten Maustaste auf die Datei und wählen Sie eine Regel:

- :ui[files.ignore] trägt die Regel in die Datei `.gitignore` im Wurzelverzeichnis des Repositorys ein. Committen Sie `.gitignore`, dann gilt die Regel für alle, die das Repository verwenden.
- :ui[files.exclude] trägt die Regel in `info/exclude` im Git-Ordner ein. Die Regel gilt nur für diese Kopie des Repositorys und wird nie committet.

In beiden Untermenüs können Sie nur dieses Objekt ignorieren, jedes Objekt mit demselben Namen, jedes Objekt mit derselben Erweiterung oder ein Muster, das Sie eingeben.

Ignorierregeln gelten nicht für Dateien, die Git bereits verfolgt. Wenn Sie eine verfolgte Datei ignorieren, fragt Spooky, ob sie auch nicht mehr verfolgt werden soll. Klicken Sie auf :ui[files.untrack], um das Verfolgen zu beenden, oder auf :ui[files.untrackIgnored.skip], um sie weiter zu verfolgen. Die Datei bleibt in beiden Fällen in Ihrem Ordner.

Um eine Datei ohne Ignorierregel nicht mehr zu verfolgen, klicken Sie mit der rechten Maustaste darauf und wählen Sie :ui[files.untrack]. Der nächste Commit entfernt sie aus dem Repository, und die Datei bleibt in Ihrem Ordner.

:ui[files.mark > files.assumeUnchanged.set] weist Git an, Ihre lokalen Änderungen an einer verfolgten Datei auszulassen, zum Beispiel an einer Konfigurationsdatei, die Sie nur auf Ihrem Mac bearbeiten. Die Datei verschwindet aus der Liste. Um sie wieder zu sehen, aktivieren Sie :ui[files.showAssumeUnchanged] und wählen Sie dann :ui[files.mark > files.assumeUnchanged.unset].

## Dateiaktionen {#file-actions}

Klicken Sie mit der rechten Maustaste auf eine Datei, um ihre Aktionen zu sehen. Liegt die angeklickte Zeile in der Auswahl, gilt die Aktion für jede ausgewählte Datei. Außerhalb der Auswahl gilt sie nur für die angeklickte Zeile.

::screenshot[Das Kontextmenü für src/readings.ts in der Arbeitskopie. Von oben nach unten enthält es Einträge zum Öffnen der Datei und Kopieren ihres Pfads, für die Übersicht, zum Stagen und Legen in den Papierkorb, für Konflikte, zum Verwerfen und Stashen, für Blame und Dateiverlauf, zum Ignorieren und zum Vergleichen.]{name="work-file-menu" frame="closeup"}

| Ziel | Auswahl |
|---|---|
| Die Datei öffnen | :ui[files.open] oder eine App aus :ui[files.openWith]. Sie können auch auf die Datei doppelklicken. |
| Ihren Pfad kopieren | :ui[workspace.copyPathMenu] oder :ui[working.copyRelative] |
| Im Finder oder Terminal anzeigen | :ui[action.revealFinder] oder :ui[action.openTerminal] |
| Bewegen oder umbenennen | :ui[files.move.menu] |
| In den Papierkorb legen | :ui[files.trash] oder <kbd>⌘⌫</kbd> drücken |
| Ihre Änderungen verwerfen | :ui[working.discard.menu] (siehe [Änderungen verwerfen](/guide/work/diff/#discard)) |
| In einen Stash legen | Siehe [Einzelne Dateien stashen](/guide/work/stash/#partial). |
| Eine ältere Version wiederherstellen | :ui[files.revert.menu] |
| Ihren Verlauf ansehen | :ui[quickActions.showFileHistory] oder :ui[quickActions.showBlame] (siehe [Dateiverlauf und Blame](/guide/history/file-views/)) |
| In einer anderen App vergleichen | :ui[externalTool.compare] (siehe [In einer anderen App vergleichen](/guide/work/diff/#external)) |

:ui[files.trash] fragt nicht nach. Eine versionierte Datei, die Sie in den Papierkorb legen, erscheint als gestagte Löschung. Um sie zurückzuholen, wählen Sie :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

:::note[Server-Repositorys]
:ui[files.trash] legt Dateien in den Papierkorb des Servers. Hat der Server keinen Papierkorb, heißt der Eintrag :ui[files.delete], und Spooky fragt nach, bevor es die Dateien endgültig löscht. Die meisten Apps erhalten eine Kopie der Datei, und Spooky schreibt Ihre Änderungen beim Sichern auf den Server zurück. Siehe [Terminal und andere Apps](/guide/server/local-location/#terminal).
:::

## Übersicht {#quick-look}

Um eine Datei in der Vorschau zu sehen, ohne eine App zu öffnen, klicken Sie mit der rechten Maustaste darauf und wählen Sie :ui[files.quickLook.single]{1="README.md"}.

Wenn Sie die Übersicht oft verwenden, lassen Sie sie von der Leertaste öffnen: Wählen Sie :ui[app.name > settings.title] › :ui[settings.general] und setzen Sie :ui[files.spacebar] auf :ui[files.spacebar.quickLook]. Standardmäßig stagt oder unstagt die Leertaste die ausgewählten Dateien. Siehe [Dateiliste](/guide/settings/general/#file-list).

:::note[Server-Repositorys]
Spooky lädt die Datei zuerst in einen temporären Ordner auf Ihrem Mac. Der Ordner wird entfernt, wenn Sie das Repository schließen.
:::

## Einstellungen für die Dateiliste {#settings}

Sie finden sie unter :ui[app.name > settings.title] › :ui[settings.general]:

| Einstellung | Optionen |
|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] (Standard) oder :ui[files.doubleClick.openDiff] |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] (Standard) oder :ui[files.spacebar.quickLook] |
| :ui[files.fontSize] | :ui[files.fontSize.regular] oder :ui[files.fontSize.medium] (Standard) |
| :ui[files.truncation] | :ui[files.truncation.beginning] (Standard) oder :ui[files.truncation.middle] |

Siehe [Dateiliste](/guide/settings/general/#file-list).

## Siehe auch

- [Änderungen prüfen und stagen](/guide/work/diff/)
- [Änderungen committen](/guide/work/commit/)
- [Dateiverlauf und Blame](/guide/history/file-views/)
