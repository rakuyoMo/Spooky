---
title: "Änderungen prüfen und stagen"
description: "Die Änderungen in einer Datei lesen, die Darstellung von Diffs anpassen und Änderungen nach Datei, Block oder Zeile stagen oder verwerfen."
---

Wählen Sie in der Arbeitskopie eine Datei aus, und die rechte Spalte zeigt ihren Diff: was sich geändert hat, Zeile für Zeile. Von dort können Sie nur die Teile stagen, die in den nächsten Commit gehören, und den Rest verwerfen.

## Einen Diff lesen {#read}

Ein Diff ist in Blöcke unterteilt. Ein Block ist eine Gruppe geänderter Zeilen mit einigen unveränderten Zeilen darum herum. Seine Kopfzeile gibt an, wo der Block in der Datei liegt.

- Hinzugefügte Zeilen sind grün, entfernte Zeilen rot. Die beiden Spalten mit Zeilennummern gehören zur alten und zur neuen Version der Datei.
- Hat eine Datei gestagte und nicht gestagte Änderungen, wechseln Sie oben in der Spalte mit :ui[working.unstaged] und :ui[working.staged] zwischen ihnen. Eine Seite ohne Änderungen ist abgeblendet.
- Die Leiste unter dem Diff zeigt die Anzahl der Blöcke und wie viele Zeilen hinzugefügt und entfernt wurden.
- Bei einem Bild zeigt der Diff das alte und das neue Bild. :ui[diff.twoUp] stellt sie nebeneinander. :ui[diff.oneUp] zeigt jeweils eines, und Sie wechseln zwischen :ui[diff.old] und :ui[diff.new].

Ein sehr großer Diff kann das Fenster langsam machen, deshalb fragt Spooky vorher: :ui[working.largeDiff] Klicken Sie auf :ui[working.showDiff], um ihn zu sehen. Die Größengrenze ist :ui[working.diffThreshold] unter :ui[app.name > settings.title] › :ui[settings.general]. Standardmäßig sind es 20.000 kB. Siehe [Verlauf und Diffs](/guide/settings/general/#history).

## Diff-Optionen {#options}

Die Leiste unter dem Diff enthält die Optionen, die Sie am häufigsten ändern:

- Am linken Ende liegen zwei Tasten. Bewegen Sie den Zeiger darüber, um ihre Namen zu sehen.
  - :ui[diff.ignoreWhitespace] lässt Änderungen aus, die nur Leerzeichen und Tabulatoren betreffen. Hat sich in der Datei sonst nichts geändert, steht im Diff :ui[diff.onlyWhitespace]
  - :ui[diff.showEntireFile] zeigt die ganze Datei mit den Änderungen an Ort und Stelle. Das gilt nur für den Diff, den Sie gerade ansehen.
- Am rechten Ende legt :ui[diff.context] fest, wie viele unveränderte Zeilen um jede Änderung herum erscheinen. Der Standard ist 3. Sie können den Wert auch unter :ui[menu.view > diff.contextMenu] wählen.

Die Einstellungen für Leerraum und Kontext gelten überall: in allen Repositorys, in der Arbeitskopie und im Verlauf.

Weitere Optionen finden Sie unter :ui[app.name > settings.title] › :ui[settings.text]:

| Einstellung | Wirkung |
|---|---|
| :ui[text.enableSyntaxColoring] | Färbt Code nach seiner Sprache ein. Standardmäßig aktiviert. |
| :ui[text.syntaxColoringInDiffs] | Verwendet die Syntaxfarben auch in Diffs. Standardmäßig deaktiviert. |
| :ui[text.showInvisibles] | Zeigt Leerzeichen, Tabulatoren und Zeilenenden als Symbole |
| :ui[text.tabWidth] | Wie breit ein Tabulator ist, in Leerzeichen |

Mehr zu diesen Einstellungen steht unter [Text](/guide/settings/appearance/#text). Die Farben stammen aus dem Thema. Siehe [Themen](/guide/settings/appearance/#themes).

## Ganze Dateien stagen {#stage-file}

Mit dem Stagen wählen Sie die Änderungen aus, die in den nächsten Commit kommen. Um ganze Dateien zu stagen, führen Sie einen der folgenden Schritte aus:

- Aktivieren Sie das Markierungsfeld vor der Datei. Ist die Datei ausgewählt, werden alle ausgewählten Dateien gestagt.
- Wählen Sie Dateien aus und drücken Sie die <kbd>Leertaste</kbd>. Hat eine ausgewählte Datei nicht gestagte Änderungen, stagt die Leertaste sie. Andernfalls unstagt sie sie.
- Klicken Sie über der Liste auf :ui[working.stageAll] oder wählen Sie :ui[workspace.title > working.stageAllMenu] (<kbd>⇧⌘E</kbd>).

Zum Unstagen deaktivieren Sie das Markierungsfeld, drücken Sie erneut die <kbd>Leertaste</kbd> oder wählen Sie :ui[workspace.title > working.unstageAllMenu] (<kbd>⌥⇧⌘E</kbd>). Ist alles gestagt, wird die Taste :ui[working.stageAll] zu :ui[working.unstageAll]. Solange nur einige Änderungen gestagt sind, halten Sie <kbd>⌥</kbd> gedrückt, um sie umzuschalten.

## Blöcke stagen {#chunks}

Jeder Block hat Tasten am rechten Ende seiner Kopfzeile:

- Auf der Seite :ui[working.unstaged]: :ui[working.discardChunk] und :ui[working.stageChunk]
- Auf der Seite :ui[working.staged]: :ui[working.unstageChunk]

Der Block wechselt sofort auf die andere Seite. Der Rest der Datei bleibt, wo er war.

## Zeilen stagen {#lines}

Wenn ein Block Änderungen für verschiedene Commits mischt, stagen Sie nur einige seiner Zeilen.

1. Klicken Sie auf die Zeilennummer einer geänderten Zeile, um sie auszuwählen. Ein weiterer Klick hebt die Auswahl auf.
2. Um weitere Zeilen auszuwählen, klicken Sie auch auf deren Nummern. Ziehen Sie über Zeilennummern, um mehrere aufeinanderfolgende Zeilen auszuwählen, oder klicken Sie bei gedrückter <kbd>⇧</kbd>-Taste, um alle Zeilen dazwischen auszuwählen.
3. Klicken Sie in der Kopfzeile des Blocks auf :ui[working.stageLines].

::screenshot[Ein Block im Diff von src/readings.ts. Fünf Zeilen sind über ihre Zeilennummern ausgewählt, und die Kopfzeile des Blocks zeigt die Tasten zum Verwerfen und Stagen der Zeilen.]{name="staging" frame="closeup"}

Nur geänderte Zeilen lassen sich auswählen. Jeder Block hat seine eigene Auswahl, und seine Tasten wirken auf die darin ausgewählten Zeilen. Auf der Seite :ui[working.staged] heißt die Taste :ui[working.unstageLines].

## Änderungen verwerfen {#discard}

Beim Verwerfen entfernen Sie Änderungen, die Sie nicht behalten möchten.

- **Eine Datei**: Klicken Sie mit der rechten Maustaste darauf und wählen Sie :ui[working.discard.menu] aus dem Menü, oder wählen Sie :ui[workspace.title > working.discardMenu] (<kbd>⇧⌘⌫</kbd>).
- **Alles**: Wählen Sie :ui[workspace.title > working.discardAllMenu] in der Menüleiste.
- **Ein Block oder einige Zeilen**: Klicken Sie in der Kopfzeile des Blocks auf :ui[working.discardChunk] oder :ui[working.discardLines].

Bei Dateien fragt Spooky vorher nach. Verfolgte Dateien kehren zum Stand des letzten Commits zurück, einschließlich aller gestagten Änderungen. Neue Dateien kommen in den Papierkorb. Klicken Sie auf :ui[working.discard] oder :ui[working.discardAll.submit], um fortzufahren.

Bei Blöcken und Zeilen fragt Spooky :ui[working.discardContent.title] Aktivieren Sie :ui[dialog.doNotAskAgain], um die Frage beim nächsten Mal zu überspringen. Um sie zurückzuholen, aktivieren Sie :ui[settings.warnDiscardingChunks] unter :ui[app.name > settings.title] › :ui[settings.general]. Siehe [Bestätigungen](/guide/settings/general/#confirmations).

:::caution
Verworfene Änderungen stehen in keinem Commit. Der einzige Weg zurück ist :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>), und nur, bis sich das Repository wieder ändert. Neue Dateien lassen sich aus dem Papierkorb zurückholen, solange sie noch dort liegen.
:::

:::note[Server-Repositorys]
Das Verwerfen überschreibt die Dateien auf dem Server. Neue Dateien kommen in den Papierkorb des Servers. Hat der Server keinen Papierkorb, werden sie endgültig gelöscht. Die Frage enthält :ui[dialog.doNotAskAgain]. Um sie zurückzuholen, aktivieren Sie :ui[settings.warnDiscardingOnServer] unter :ui[settings.general].
:::

## In einer anderen App vergleichen {#external}

So sehen Sie eine Änderung in einem Vergleichswerkzeug wie FileMerge oder Kaleidoscope an:

- Bewegen Sie den Zeiger über den Dateinamen oben in der rechten Spalte und klicken Sie auf :ui[externalTool.action.diffTool]. Verglichen wird die Seite, die Sie gerade ansehen.
- Oder klicken Sie mit der rechten Maustaste auf die Datei und wählen Sie aus dem Untermenü :ui[externalTool.compare]: :ui[externalTool.compare.workingTreeToBase], :ui[externalTool.compare.workingTreeToIndex] oder :ui[externalTool.compare.indexToBase].

Beim ersten Mal fragt Spooky, welche App verwendet werden soll. Später ändern Sie das mit :ui[externalTool.diffTool] unter :ui[app.name > settings.title] › :ui[settings.gitConfig]. Spooky arbeitet mit Araxis Merge, BBEdit, Beyond Compare, DeltaWalker, FileMerge, Kaleidoscope, P4Merge, TextMate und Visual Studio Code. Siehe [Vergleichs- und Zusammenführungswerkzeuge](/guide/settings/integration/#diff-merge-tools).

:::note[Server-Repositorys]
Das Vergleichswerkzeug erhält Kopien der Dateien in einem temporären Ordner auf Ihrem Mac. Der Ordner wird entfernt, wenn Sie das Repository schließen.
:::

## Siehe auch

- [Arbeitskopie](/guide/work/working-copy/)
- [Änderungen committen](/guide/work/commit/)
- [Widerrufen und Wiederherstellen](/guide/work/undo/)
