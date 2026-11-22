---
title: "Konflikte lösen"
description: "Konflikte aus einem Merge, Rebase oder einem anderen laufenden Vorgang mit dem Konfliktassistenten oder einem externen Zusammenführungswerkzeug lösen, dann fortfahren oder abbrechen."
---

Ein Konflikt entsteht, wenn beide Seiten dieselbe Stelle einer Datei geändert haben und Git nicht entscheiden kann, welche Änderung bleiben soll. Ein Merge, Rebase, Cherry-Pick oder Revert hält an dieser Stelle an, ebenso das Anwenden eines Stashes. Sie entscheiden, was in jede Datei kommt, und schließen dann den Vorgang ab.

::screenshot[Die Arbeitskopie während eines Merges von „feature/units-toggle“ in „main“. Ein gelbes Banner oben in der mittleren Spalte meldet 1 nicht aufgelösten Konflikt, 0 aufgelöst, und hat eine Taste zum Abbrechen. In der Dateiliste ist src/units.ts als Konflikt markiert. Rechts zeigen zwei Karten die Version von units.ts aus jedem Branch, mit Pfeilen nach unten zu einem leeren Ergebnisfeld und einer Taste zur Auswahl des Zusammenführungswerkzeugs.]{name="conflict" frame="window" markers="24,18 47,60.1 76,37 76,73 88.8,86"}

1. Das Banner zeigt, was gerade läuft und wie viele Konflikte noch offen sind.
2. Eine Datei mit Konflikt. Wählen Sie sie aus, um den Konfliktassistenten zu öffnen.
3. Die beiden Versionen der Datei, eine von jeder Seite.
4. Das Ergebnis: wie die Datei aussehen wird.
5. Die Taste, die die Datei auflöst oder ein Zusammenführungswerkzeug öffnet.

## Laufende Vorgänge {#banner}

Während ein Merge, Rebase, Cherry-Pick oder Revert läuft, steht oben in der Arbeitskopie ein Banner:

- Der Titel sagt, was gerade passiert, zum Beispiel :ui[conflict.title.merge]{1="feature/units-toggle" 2="main"}.
- Darunter steht die Anzahl der nicht aufgelösten Konflikte. Hat der Vorgang an einem Konflikt angehalten, folgt in Klammern die Anzahl der aufgelösten Dateien.
- Ein kurzer Hinweis sagt, was als Nächstes zu tun ist. Bei einem Rebase oder einer Reihe von Commits zeigt ein Fortschrittsbalken, bei welchem Schritt Sie sind.
- :ui[working.onlyConflicts] beschränkt die Dateiliste auf die Dateien dieses Konflikts. Dateien, die Sie aufgelöst haben, bleiben in der Liste. Spooky merkt sich die Wahl für alle Repositorys.
- :ui[working.abort] bricht den Vorgang ab. Siehe [Fortfahren oder abbrechen](#continue).

Der Commit-Bereich bleibt ausgeblendet, bis jeder Konflikt aufgelöst ist.

## Den Konfliktassistenten verwenden {#wizard}

Wählen Sie in der Arbeitskopie eine Datei mit Konflikt aus. Rechts öffnet sich der Konfliktassistent, mit einer Karte für jede Seite, etwa :ui[conflict.version]{1="main"}. Jede Karte zeigt die Datei, was diese Seite damit gemacht hat (zum Beispiel :ui[conflict.change.modified]), und den Commit, aus dem sie stammt.

So behalten Sie eine Seite:

1. Klicken Sie auf ihre Karte. Das Ergebnisfeld zeigt diese Version.
2. Klicken Sie auf :ui[conflict.resolveUsing]{1="main"}.

Spooky schreibt diese Version in die Datei und stagt sie. Die Datei gilt als aufgelöst. Hat diese Seite die Datei gelöscht, wird die Datei gelöscht.

Um beide Seiten zu kombinieren, klicken Sie auf beide Karten und dann auf die Taste unter dem Ergebnisfeld. Sie öffnet ein Zusammenführungswerkzeug, wie in [In einer anderen App zusammenführen](#merge-tool) beschrieben.

Haben Sie die Datei bereits selbst bearbeitet, zum Beispiel in einem Texteditor, zeigt das Ergebnisfeld :ui[conflict.result]. Klicken Sie auf :ui[conflict.resolveCurrent], um die Datei so zu stagen, wie sie ist. Der Assistent liest die Datei neu ein, wenn Sie zu Spooky zurückkehren.

Die Taste „…“ auf einer Karte öffnet ein Menü für diese Version:

- :ui[conflict.open]{1="main"} oder mit einer anderen App öffnen
- :ui[conflict.export]{1="main"}
- :ui[conflict.compareOther]{1="feature/units-toggle"}
- :ui[conflict.compareBase]

## In einer anderen App zusammenführen {#merge-tool}

Ein Zusammenführungswerkzeug zeigt beide Versionen nebeneinander und lässt Sie Änderungen Zeile für Zeile auswählen. Es bearbeitet jeweils eine Datei, wenn beide Seiten die Datei haben.

1. Klicken Sie im Konfliktassistenten auf :ui[externalTool.chooseMergeTool] und wählen Sie eine App. Nach dem ersten Mal heißt die Taste :ui[externalTool.mergeIn]{1="FileMerge"}.
2. Führen Sie die Datei in dieser App zusammen, sichern Sie das Ergebnis und beenden Sie die App.

Spooky schreibt das Ergebnis in die Datei und markiert sie als aufgelöst. Hat die App kein Ergebnis gesichert, meldet Spooky :ui[externalTool.noResult], und der Konflikt bleibt.

FileMerge funktioniert etwas anders. Spooky zeigt :ui[externalTool.finishMerge]{1="FileMerge"}, solange es geöffnet ist. Sichern Sie das Ergebnis in FileMerge und klicken Sie dann auf :ui[externalTool.done].

Spooky unterstützt Araxis Merge, Beyond Compare, DeltaWalker, FileMerge, Kaleidoscope, P4Merge und Visual Studio Code. Um die App zu wechseln, ändern Sie :ui[externalTool.mergeTool] unter :ui[app.name > settings.title] › :ui[settings.gitConfig]. Aktivieren Sie dort :ui[externalTool.keepBackups], um die Datei im Zustand vor dem Zusammenführen zu behalten, zum Beispiel als `src/units.ts.orig`. Siehe [Vergleichs- und Zusammenführungswerkzeuge](/guide/settings/integration/#diff-merge-tools).

Wurde die Datei anderswo geändert, während Sie sie zusammengeführt haben, fragt Spooky nach, bevor es sie überschreibt.

:::note[Server-Repositorys]
Das Zusammenführungswerkzeug erhält Kopien der Versionen in einem temporären Ordner auf diesem Mac. Spooky schreibt das Ergebnis auf den Server zurück und markiert die Datei dann als aufgelöst. Der Ordner wird gelöscht, wenn Sie das Repository schließen.
:::

## Andere Wege zum Auflösen {#other-ways}

Klicken Sie mit der rechten Maustaste auf eine oder mehrere Dateien mit Konflikt:

- :ui[conflict.menu.resolve]
  - :ui[conflict.markResolved.one]{1="src/units.ts"} stagt die Datei so, wie sie jetzt ist. Das Aktivieren ihres Markierungsfelds bewirkt dasselbe.
  - :ui[conflict.resolveUsingVersion]{1="main"} behält eine Seite, wie der Assistent.
- :ui[conflict.menu.restore]
  - :ui[conflict.restoreUnmerged.one]{1="src/units.ts"} holt den Konflikt zurück, auch bei einer Datei, die Sie bereits aufgelöst haben.
  - :ui[conflict.restoreVersion]{1="main"} und :ui[conflict.restoreAncestor] schreiben eine Version in die Datei. Die Datei bleibt nicht aufgelöst.

:::caution
Das Wiederherstellen überschreibt die Datei in der Arbeitskopie ohne Nachfrage. Alle Änderungen, die Sie daran vorgenommen haben, gehen verloren.
:::

Hält das Anwenden eines Stashes oder Patches an Konflikten an, gibt es keinen Vorgang zum Fortfahren oder Abbrechen und kein Banner. Der Assistent nennt die eingehende Seite :ui[conflict.version.applied]. Sind die Dateien aufgelöst, liegen die Änderungen wie alle anderen in der Arbeitskopie.

## Fortfahren oder abbrechen {#continue}

Ist jeder Konflikt aufgelöst, kommt der Commit-Bereich zurück, mit der Nachricht, die Git für den Vorgang vorbereitet hat.

- **Merge, oder Cherry-Pick oder Revert eines einzelnen Commits**: Prüfen Sie die Nachricht und klicken Sie dann auf :ui[working.commit].
- **Rebase, oder Cherry-Pick oder Revert mehrerer Commits**: Prüfen Sie die Nachricht und klicken Sie dann auf :ui[working.continue]. Spooky committet diesen Schritt und geht zum nächsten über, der wieder an einem Konflikt anhalten kann.
- **Ein Rebase-Schritt, der zum Bearbeiten eines Commits anhält**: Erstellen Sie Ihre Commits und klicken Sie dann im Banner auf :ui[working.endEditing].

Manchmal bleibt nichts zu committen, zum Beispiel wenn Sie die Version behalten haben, die schon da war. Klicken Sie in diesem Fall auf :ui[working.commit] oder :ui[working.continue], fragt Spooky :ui[commit.empty.title] Klicken Sie auf :ui[commit.empty.use], um einen leeren Commit zu erstellen. Die andere Taste bricht den Merge ab oder überspringt den Schritt in einem Rebase oder einer Reihe. In einem Rebase oder einer Reihe können Sie auch im Banner auf :ui[working.skip] klicken.

Um aufzugeben, klicken Sie im Banner auf :ui[working.abort]. Das Repository kehrt in den Zustand vor Beginn des Vorgangs zurück.

:::caution
Das Abbrechen wird sofort ausgeführt, ohne Nachfrage, und lässt sich nicht widerrufen. Die Konflikte, die Sie aufgelöst haben, gehen verloren.
:::

## Siehe auch

- [Änderungen prüfen und stagen](/guide/work/diff/)
- [Stashes](/guide/work/stash/)
- [Widerrufen und Wiederherstellen](/guide/work/undo/)
