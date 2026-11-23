---
title: "Verlauf umschreiben"
description: "Commits per Revert rückgängig machen, per Cherry-Pick übernehmen und zurücksetzen, interaktiv rebasen und ältere Commits ergänzen."
---

Die meisten Befehle hier gehen von der Liste im [Verlauf](/guide/history/browse/) aus: Klicken Sie mit der rechten Maustaste auf einen Commit oder wählen Sie zuerst mehrere aus. Revert und Cherry-Pick fügen neue Commits hinzu. Die übrigen schreiben Commits um, die es bereits gibt.

:::caution
Umgeschriebene Commits erhalten neue Hashes. Haben Sie sie bereits gepusht, laufen Ihr Branch und sein Upstream auseinander, und für das erneute Pushen ist ein Force-Push nötig. Wer die alten Commits bereits hat, muss seinen Verlauf abgleichen. Siehe [Force-Push](/guide/branches/sync/#force-push).
:::

Abgesehen von Cherry-Pick und Zurücksetzen erscheinen diese Befehle im Menü eines Commits nur, solange die Liste allein den Branch zeigt, auf dem Sie sich befinden. Dorthin gelangen Sie mit :ui[menu.view > history.showHead] (<kbd>⌘0</kbd>) oder per Klick auf den Branch in der Seitenleiste.

::screenshot[Das Kontextmenü für den Commit 2daa6982, während die Liste den Branch zeigt, auf dem Sie sich befinden. Es enthält unter anderem Einträge für Zurücksetzen, Revert und Rebase auf eine andere Basis, gefolgt von Ergänzen, Bearbeiten, Commit-Nachricht bearbeiten und Löschen für diesen Commit.]{name="history-commit-menu" frame="closeup"}

## Einen Commit rückgängig machen {#revert}

Ein Revert fügt einen Commit hinzu, der die Änderungen eines früheren aufhebt. Der frühere Commit bleibt im Verlauf, deshalb ist das der sichere Weg, etwas bereits Gepushtes zurückzunehmen.

1. Klicken Sie mit der rechten Maustaste auf den Commit und wählen Sie :ui[rewrite.menu.revert]{1="e2dda2bc"} im Menü. Sind mehrere Commits ausgewählt, heißt der Eintrag stattdessen :ui[rewrite.menu.revertMany]{1="3"}.
2. :ui[rewrite.revert.commit] ist standardmäßig aktiviert, sodass jeder rückgängig gemachte Commit einen eigenen Commit erhält. Deaktivieren Sie die Option, um die Änderungen in der Arbeitskopie zu lassen. Spooky merkt sich diese Wahl.
3. Klicken Sie auf :ui[rewrite.revert.button].

Mehrere Commits werden vom neuesten zum ältesten rückgängig gemacht. Um einen Merge-Commit rückgängig zu machen, wählen Sie seine :ui[rewrite.mainline]: der Eltern-Commit, dessen Seite als Hauptlinie gilt. Ein Merge-Commit lässt sich nur einzeln rückgängig machen.

Auch die Commit-Details und die [Mehrfachauswahl](/guide/history/commit-details/#multiple) haben eine Taste :ui[rewrite.revert.button].

## Einen Commit per Cherry-Pick übernehmen {#cherry-pick}

Ein Cherry-Pick kopiert die Änderungen von Commits aus einem anderen Branch als neue Commits auf den Branch, auf dem Sie sich befinden.

1. Klicken Sie in der Seitenleiste auf den anderen Branch, um seinen Verlauf zu sehen.
2. Klicken Sie mit der rechten Maustaste auf den Commit und wählen Sie :ui[rewrite.menu.cherryPick]{1="e2dda2bc"} im Menü. Sind mehrere Commits ausgewählt, heißt der Eintrag :ui[rewrite.menu.cherryPickMany]{1="3"}, und Sie können auch rechts auf :ui[rewrite.cherryPick.button] klicken.
3. Wählen Sie die Optionen. Spooky merkt sie sich:
   - :ui[rewrite.cherryPick.commit] (standardmäßig aktiviert) committet jeden einzeln. Deaktivieren Sie die Option, um die Änderungen nur auf die Arbeitskopie anzuwenden.
   - :ui[rewrite.cherryPick.fastForward] verschiebt Ihren Branch auf den Commit, statt ihn zu kopieren, wenn Ihr Branch auf dem Eltern-Commit des Commits steht. Das gilt nur, solange die erste Option aktiviert ist.
4. Klicken Sie auf :ui[rewrite.cherryPick.button].

Die Commits werden vom ältesten zum neuesten angewendet. Ein Merge-Commit braucht eine :ui[rewrite.mainline], wie beim Revert.

Zeigt die Liste den Branch, auf dem Sie sich befinden, erscheint der Eintrag nur für Commits im Upstream, die Sie noch nicht gepullt haben.

Sie können Commits auch aus der Liste auf :ui[workspace.title] oder den Branch, auf dem Sie sich befinden, in der Seitenleiste ziehen. Halten Sie beim Loslassen <kbd>⌥</kbd> gedrückt, um sie stattdessen rückgängig zu machen.

## Auf einen älteren Commit zurücksetzen {#reset}

Das Zurücksetzen verschiebt den Branch, auf dem Sie sich befinden, auf einen anderen Commit. Die Commits danach verlassen den Branch.

1. Klicken Sie mit der rechten Maustaste auf den Commit und wählen Sie :ui[rewrite.menu.reset]{1="e2dda2bc"} im Menü. Sie können auch in den Commit-Details auf :ui[history.rollback] klicken oder :ui[workspace.title > rewrite.reset.menu] in der Menüleiste wählen.
2. Prüfen Sie :ui[rewrite.revision]. Sie können einen Branch, einen Remote-Branch oder ein Tag wählen oder einen Hash eingeben. Das Dialogfenster listet die Commits auf, die den Branch verlassen werden.
3. Wählen Sie unter :ui[rewrite.reset.mode] einen Modus:
   - :ui[rewrite.reset.soft] lässt Index und Arbeitskopie, wie sie sind. Die Änderungen aus den Commits, die den Branch verlassen, bleiben gestagt.
   - :ui[rewrite.reset.mixed] setzt den Index zurück und behält die Arbeitskopie. Diese Änderungen sind danach nicht gestagt.
   - :ui[rewrite.reset.hard] setzt beides zurück. Nicht committete Änderungen und die Änderungen aus den Commits, die den Branch verlassen, werden verworfen.
4. Klicken Sie auf :ui[rewrite.reset.button].

Das Dialogfenster beginnt jedes Mal mit :ui[rewrite.reset.soft]. Beim Zurücksetzen bietet Spooky nicht an, Ihre Änderungen zu stashen.

:::caution
:ui[rewrite.reset.hard] verwirft nicht committete Änderungen in versionierten Dateien. Das Dialogfenster warnt Sie, wenn es welche gibt. <kbd>⌘Z</kbd> holt sie zurück, aber nur, bis Sie Spooky beenden.
:::

## Commits auf eine andere Basis rebasen {#rebase-onto}

:ui[rewrite.rebaseOnto] verschiebt Commits so, dass sie auf einem anderen Commit aufsetzen.

- Um einen ganzen Abschnitt Ihres Branches zu verschieben, wählen Sie :ui[workspace.title > rewrite.rebaseOnto.menu] in der Menüleiste. Füllen Sie :ui[rewrite.rebaseOnto.current] und :ui[rewrite.rebaseOnto.new] aus. Die Commits nach der aktuellen Basis werden auf der neuen erneut angewendet.
- Um nur einige Commits zu verschieben, wählen Sie sie aus und klicken Sie mit der rechten Maustaste. Wählen Sie :ui[rewrite.menu.rebaseOntoMany]{1="3"} im Menü, oder :ui[rewrite.menu.rebaseOnto]{1="e2dda2bc"} für einen einzelnen Commit, und füllen Sie dann :ui[rewrite.rebaseOnto.new] aus. Commits im selben Abschnitt, die Sie nicht ausgewählt haben, werden aus dem Branch entfernt.

Keine der beiden Basen darf der Commit sein, den Sie ausgecheckt haben. Das Dialogfenster listet die Commits auf, die umgeschrieben werden, und warnt Sie, wenn einige bereits gepusht sind oder in anderen Branches liegen. :ui[sync.skipHooks] überspringt dieses Mal den pre-rebase-Hook des Repositorys. Klicken Sie auf :ui[rewrite.rebaseOnto.button], um zu beginnen.

Wie Sie einen Branch auf einen anderen Branch rebasen, steht unter [Rebase](/guide/branches/merge-rebase/#rebase).

## Zusammenfassen, Fixup, Löschen und Verschieben {#interactive}

Diese Befehle schreiben eine Folge von Commits auf dem Branch um, auf dem Sie sich befinden. Wählen Sie die Commits aus, klicken Sie mit der rechten Maustaste und wählen Sie:

- :ui[rewrite.menu.squashMany]{1="3"}, um sie in den ältesten einzufügen. Ihre Nachrichten werden kombiniert, und die Liste wählt danach den neuen Commit aus.
- :ui[rewrite.menu.fixupMany]{1="3"}, um sie in den ältesten einzufügen und nur dessen Nachricht zu behalten.
- :ui[rewrite.menu.deleteMany]{1="3"}, um sie aus dem Branch zu entfernen. Ist ein Commit ausgewählt, bewirkt :ui[rewrite.menu.delete]{1="e2dda2bc"} dasselbe.

Sie können Commits auch innerhalb der Liste ziehen:

- Legen Sie sie auf einem anderen Commit ab, um sie mit ihm zusammenzufassen. Halten Sie beim Loslassen <kbd>⌥</kbd> gedrückt, um sie stattdessen per Fixup einzufügen. Das Etikett an der Ablagestelle lautet :ui[rewrite.squash.button] oder :ui[rewrite.fixup.button].
- Legen Sie sie zwischen zwei Zeilen ab, um sie dorthin zu verschieben. Das Etikett lautet :ui[branch.moveHere].

Bei all dem fragt Spooky nach, bevor es etwas umschreibt. Das Dialogfenster listet jeden Commit auf, der umgeschrieben wird, mit dem, was mit ihm geschieht, etwa :ui[rewrite.note.squash] oder :ui[rewrite.note.drop]. Ein gelbes Warnzeichen markiert Commits, die bereits gepusht sind oder in anderen Branches liegen, und eine Warnung über der Liste erklärt das. Beim Löschen von Commits, die bereits im Upstream liegen, kommt vorher eine zusätzliche Frage.

::screenshot[Das Dialogfenster, das vor dem Zusammenfassen von zwei Commits in 10e44ab8 nachfragt. Zwei Warnungen oben sagen, dass einige der Commits bereits im Upstream-Branch oder in anderen Branches liegen. Die Liste darunter zeigt die vier Commits, die umgeschrieben werden, jeweils mit dem, was mit ihnen geschieht. Der gepushte Commit hat ein gelbes Warnzeichen am Ende seiner Zeile. Die Tasten dienen zum Abbrechen und zum Zusammenfassen der Revisionen.]{name="history-rewrite-confirm" frame="dialog"}

## Eine Commit-Nachricht bearbeiten {#reword}

1. Klicken Sie mit der rechten Maustaste auf den Commit und wählen Sie :ui[rewrite.menu.reword]{1="e2dda2bc"} im Menü.
2. Ändern Sie :ui[working.subject] und :ui[working.body]. Kommentarzeilen werden behandelt wie im [Commit-Bereich](/guide/work/commit/#comments).
3. Klicken Sie auf :ui[rewrite.reword.button].

Auch die Commits danach werden umgeschrieben, und die Liste wählt den Commit anschließend unter seinem neuen Hash aus. Liegt der Commit bereits im Upstream, fragt Spooky nach, bevor es das Dialogfenster öffnet.

## Einen Commit bearbeiten {#edit}

Das Bearbeiten hält an einem Commit an und legt seine Änderungen zurück in die Arbeitskopie, sodass Sie ihn aufteilen oder neu machen können.

1. Klicken Sie mit der rechten Maustaste auf den Commit und wählen Sie :ui[rewrite.menu.edit]{1="e2dda2bc"}. Bestätigen Sie mit :ui[rewrite.edit.button].
2. Im Banner steht :ui[conflict.title.edit]{1="e2dda2bc" 2="main"}. Die Änderungen des Commits liegen nicht gestagt in der Arbeitskopie.
3. Stagen und committen Sie sie wie gewohnt, in so vielen Commits, wie Sie möchten.
4. Klicken Sie im Banner auf :ui[working.endEditing]. Die Commits danach werden darauf erneut angewendet.

Um aufzugeben, klicken Sie im Banner auf :ui[working.abort]. Der erste Commit eines Repositorys lässt sich nicht bearbeiten.

## Einen älteren Commit ergänzen {#amend}

Das Ergänzen eines älteren Commits fügt ihm Änderungen hinzu, so wie das [Ändern des letzten Commits](/guide/work/commit/#amend).

1. Klicken Sie mit der rechten Maustaste auf den Commit und wählen Sie :ui[rewrite.menu.amend]{1="e2dda2bc"}. Spooky beginnt sofort, ohne Bestätigung.
2. Der Rebase hält an diesem Commit an. Nehmen Sie Ihre Änderungen vor und stagen Sie sie.
3. Aktivieren Sie :ui[working.amend] im Commit-Bereich und committen Sie.
4. Klicken Sie im Banner auf :ui[working.endEditing]. Die Commits danach werden darauf erneut angewendet.

Haben Sie zu Beginn lokale Änderungen, bietet Spooky an, sie zuerst zu stashen. Sie bleiben danach im Stash, sodass Sie sie anwenden können, während der Rebase angehalten ist, oder später.

## Autosquash {#autosquash}

Ein Commit kann sich selbst als Korrektur für einen früheren markieren: Beginnen Sie seinen Betreff mit `fixup!`, `squash!` oder `amend!`, gefolgt vom Betreff des früheren Commits. Der Commit-Bereich [vervollständigt den Betreff](/guide/work/commit/#autocomplete) für Sie.

Zeigt die Liste den Branch, auf dem Sie sich befinden, ohne Suche, und enthalten seine letzten 1.000 Commits solche Commits, erscheint unter dem Kopf ein Banner mit dem Titel :ui[rewrite.autosquash]. Klicken Sie im Banner auf :ui[rewrite.autosquash.button] und bestätigen Sie. Jeder markierte Commit wird in den Commit eingefügt, den er nennt:

- `fixup!` behält die Nachricht des früheren Commits.
- `squash!` kombiniert beide Nachrichten.
- `amend!` ersetzt die Nachricht des früheren Commits durch seine eigene.

Klicken Sie auf ×, um das Banner vorerst auszublenden.

## Wenn das Umschreiben nicht starten kann {#errors}

Spooky prüft die Commits, bevor es etwas umschreibt. Stimmt etwas nicht, erklärt es das, und nichts ändert sich:

| Meldung | Grund |
|---|---|
| :ui[rewrite.error.notInHead] | Die Commits müssen alle im Verlauf des Branches liegen, auf dem Sie sich befinden, auf einer Linie. |
| :ui[rewrite.error.merges] | Ein Merge-Commit ist im Weg, und das Umschreiben würde ihn auflösen. Wählen Sie Commits nach dem letzten Merge. |
| :ui[rewrite.error.root] | Der erste Commit eines Repositorys hat keinen Eltern-Commit, an den seine Änderungen zurückgehen könnten. |
| :ui[rewrite.error.selection] | Das Zusammenfassen braucht mindestens zwei Commits, und das Ziel darf keiner der Commits sein, die eingefügt werden. |
| :ui[rewrite.error.autosquash] | Kein neuerer Commit ist für einen früheren markiert. |
| :ui[rewrite.error.changed] | Der Branch hat sich geändert, nachdem Spooky ihn gelesen hat. Aktualisieren Sie den Verlauf und versuchen Sie es erneut. |

## Lokale Änderungen und Konflikte {#local-changes}

Revert, Cherry-Pick und Rebase brauchen eine Arbeitskopie, die nicht im Weg ist. Blockieren Ihre lokalen Änderungen einen dieser Vorgänge, bietet Spooky an, [sie zuerst zu stashen](/guide/work/stash/#auto-stash). Beim Ergänzen eines älteren Commits fragt es vor dem Start.

Hat ein Commit unterwegs einen Konflikt, hält Spooky an und zeigt das [Banner des Vorgangs](/guide/work/conflicts/#banner). Lösen Sie die Konflikte und fahren Sie dann dort fort oder brechen Sie ab.

## Ein Umschreiben widerrufen {#undo}

Wählen Sie :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>), um einen Revert, einen Cherry-Pick, ein Zurücksetzen oder ein Umschreiben zurückzunehmen. Ist ein Rebase angehalten, zum Beispiel zum Bearbeiten eines Commits, schließen Sie ihn zuerst ab oder brechen Sie ihn ab. Ein Rebase oder Cherry-Pick, der an einem Konflikt angehalten hat, lässt sich nicht widerrufen. Siehe [Widerrufen und Wiederherstellen](/guide/work/undo/).

Die alten Commits bleiben außerdem eine Zeit lang im [Reflog](/guide/work/undo/#reflog).

:::note[Server-Repositorys]
Die Commits werden auf dem Server umgeschrieben. Jedes Dialogfenster, das den Verlauf umschreibt, nennt den Server, auf dem es ausgeführt wird.
:::

## Siehe auch

- [Konflikte lösen](/guide/work/conflicts/)
- [Widerrufen und Wiederherstellen](/guide/work/undo/)
- [Zusammenführen und Rebase](/guide/branches/merge-rebase/)
