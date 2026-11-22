---
title: "Zusammenführen und Rebase"
description: "Branches zusammenführen und rebasen, Konflikte vorab prüfen, einen Branch von seinem Eltern-Branch aktualisieren und Branches in der Seitenleiste per Drag & Drop bewegen."
---

Zusammenführen und Rebase holen beide die Commits eines anderen Branches in den Branch, auf dem Sie sich befinden:

- Ein Merge verbindet die beiden Verläufe, meist mit einem Merge-Commit.
- Ein Rebase verschiebt Ihre Commits hinter die Commits des anderen Branches. Der Verlauf bleibt eine gerade Linie, aber Ihre Commits werden neu geschrieben.

In der Symbolleiste stehen :ui[sync.merge] und :ui[sync.rebaseHead] nebeneinander. Beide lassen sich auch über das Menü :ui[workspace.title] starten.

## Zusammenführen {#merge}

1. Klicken Sie in der Symbolleiste auf :ui[sync.merge] oder wählen Sie :ui[workspace.title > sync.mergeMenu] (<kbd>⇧⌘M</kbd>). In der Seitenleiste können Sie auch mit der rechten Maustaste auf den Branch klicken, auf dem Sie sich befinden, und :ui[workspace.mergeMenu] aus dem Menü wählen oder einen anderen Branch darauf ziehen.
2. Wählen Sie in :ui[branch.target], was zusammengeführt wird: einen lokalen Branch, einen Remote-Branch oder ein Tag. Anfangs ist das der Upstream des Branches, auf dem Sie sich befinden.
3. Wählen Sie, wie committet wird:
   - :ui[merge.squash] stagt alle Änderungen für einen einzigen eigenen Commit, ohne Merge-Commit.
   - :ui[merge.alwaysCommit] erstellt auch dann einen Merge-Commit, wenn Git Ihren Branch einfach vorspulen könnte.
   - :ui[merge.autoCommit] committet den Merge sofort. Sie können die Option nur deaktivieren, solange :ui[merge.alwaysCommit] aktiviert ist. Dann warten die zusammengeführten Änderungen in der Arbeitskopie darauf, dass Sie sie committen.
4. Wenn der Merge auf Konflikte stoßen würde, steht das in einer Zeile darunter. Siehe [Konflikte vorab prüfen](#preview).
5. Legen Sie die Optionen fest:
   - :ui[merge.verify] bricht den Merge ab, wenn der zusammengeführte Commit keine vertrauenswürdige Signatur hat.
   - :ui[sync.skipHooks] überspringt dieses Mal die Git-Hooks des Repositorys.
6. Klicken Sie auf :ui[sync.merge].

Spooky merkt sich :ui[merge.alwaysCommit], :ui[merge.autoCommit] und :ui[merge.verify].

Wenn der Merge bei Konflikten anhält, wechselt Spooky zur Arbeitskopie und zeigt ein Banner. Siehe [Konflikte lösen](/guide/work/conflicts/#banner).

<kbd>⌘Z</kbd> widerruft einen Merge. Wenn der Merge bei Konflikten angehalten hat, bricht das Widerrufen ihn ab.

## Rebase {#rebase}

1. Klicken Sie in der Symbolleiste auf :ui[sync.rebaseHead] oder wählen Sie :ui[workspace.title > sync.rebaseMenu] (<kbd>⇧⌘R</kbd>). Sie können auch mit der rechten Maustaste auf den Branch klicken, auf dem Sie sich befinden, und :ui[workspace.rebaseMenu] aus dem Menü wählen.
2. Wählen Sie in :ui[branch.target] den Branch, auf den rebast wird. Anfangs ist das der Upstream des Branches, auf dem Sie sich befinden.
3. Prüfen Sie die Vorschau und aktivieren Sie bei Bedarf :ui[sync.skipHooks].
4. Klicken Sie auf :ui[sync.rebaseHead].

<kbd>⌘Z</kbd> widerruft einen abgeschlossenen Rebase. Ein Rebase, der bei einem Konflikt anhält, lässt sich nicht widerrufen: Lösen Sie den Konflikt und fahren Sie fort, oder brechen Sie ihn über das Banner ab.

Wie Sie nur einige Ihrer Commits auf eine andere Basis verschieben, lesen Sie unter [Commits auf eine andere Basis rebasen](/guide/history/rewrite/#rebase-onto).

:::caution
Ein Rebase schreibt Ihre Commits neu. Wenn Sie sie bereits gepusht haben, muss der nächste Push ein [Force-Push](/guide/branches/sync/#force-push) sein.
:::

## Lokale Änderungen {#local-changes}

Für einen Merge müssen Ihre versionierten Dateien unverändert sein. Neue Dateien stören nur, wenn der Merge sie überschreiben würde.

Ein Rebase und das Aktualisieren eines Branches von seinem Eltern-Branch brauchen eine Arbeitskopie ganz ohne Änderungen, neue Dateien eingeschlossen.

Wenn lokale Änderungen einen dieser Vorgänge blockieren, bietet Spooky an, die Änderungen zuerst zu stashen. Siehe [Automatisches Stashen](/guide/work/stash/#auto-stash).

## Konflikte vorab prüfen {#preview}

Bevor Sie beginnen, prüfen die Dialogfenster zum Zusammenführen, Rebasen, Pullen und Synchronisieren, ob die Branches in Konflikt stehen, und zeigen das Ergebnis im Dialogfenster:

- :ui[merge.checking], während Spooky sie vergleicht.
- Wie viele Dateien Konflikte haben. Bewegen Sie den Zeiger auf die Zeile, um zu sehen, welche Dateien es sind.
- :ui[merge.clean] oder :ui[merge.unchanged].
- :ui[merge.unavailable], wenn die Prüfung nicht funktioniert hat. Bewegen Sie den Zeiger auf die Zeile, um den Grund zu sehen.

Das Dialogfenster zum Zusammenführen lässt :ui[merge.clean] und :ui[merge.unchanged] weg. Die anderen zeigen jedes Ergebnis.

## Schnellversionen {#quick}

Halten Sie <kbd>⌥</kbd> gedrückt, dann werden :ui[sync.merge] und :ui[sync.rebaseHead] in der Symbolleiste zu :ui[sync.quickMerge] und :ui[sync.quickRebase]. Sie laufen sofort, ohne Dialogfenster:

- :ui[sync.quickMerge] führt den Upstream des Branches zusammen, auf dem Sie sich befinden.
- :ui[sync.quickRebase] rebast den Branch, auf dem Sie sich befinden, auf seinen Upstream.

Der schnelle Merge verwendet die Commit- und Signaturoptionen, die Sie zuletzt im Dialogfenster zum Zusammenführen gewählt haben. Beide bieten wie die Dialogfenster an, lokale Änderungen zu stashen.

Die Einträge im Menü der Seitenleiste ändern sich genauso. Zum Beispiel wird :ui[workspace.mergeMenu] zu :ui[sync.quickMergeInto]{1="origin/main" 2="main"}.

## Einen Branch von seinem Eltern-Branch aktualisieren {#update}

Wenn ein Branch einen [Eltern-Branch](/guide/branches/branches/#parent) hat, holt das Aktualisieren dessen neue Commits herein.

1. Klicken Sie mit der rechten Maustaste auf den Branch und wählen Sie :ui[branch.updateNamed]{1="feature/units-toggle"} aus dem Menü. Wenn Sie den Verlauf des Branches ansehen und der Eltern-Branch neue Commits hat, enthält auch das Banner :ui[history.parentBanner.title] eine Taste :ui[review.updateBranch.menu].
2. Prüfen Sie :ui[review.update.branch]. Die Zeile darunter sagt, wie viele Commits vom Eltern-Branch hereinkommen.
3. Wählen Sie in :ui[review.update.strategy] entweder :ui[review.update.merge] oder :ui[review.update.rebase]. Bei :ui[review.update.merge] können Sie außerdem :ui[merge.alwaysCommit] aktivieren.
4. Prüfen Sie die Vorschau: :ui[review.update.conflicts], :ui[review.update.clean] oder :ui[review.update.noChanges].
5. Legen Sie die Optionen fest: :ui[merge.verify] (nur beim Zusammenführen) und :ui[sync.skipHooks].
6. Klicken Sie auf :ui[review.update.button].

Spooky checkt zuerst den Branch aus und führt dann zusammen oder rebast. Das Aktualisieren ist nur verfügbar, wenn der Eltern-Branch Commits hat, die dem Branch fehlen, und kein anderer Vorgang läuft.

Beim Branch, auf dem Sie sich befinden, öffnen :ui[branch.mergeWith]{1="main"} und :ui[branch.rebaseOn]{1="main"} im Menü der Seitenleiste die Dialogfenster zum Zusammenführen und für den Rebase, mit dem Eltern-Branch bereits ausgewählt.

:::tip
Halten Sie <kbd>⌥</kbd> gedrückt, während das Menü geöffnet ist, dann wird :ui[branch.updateNamed]{1="feature/units-toggle"} zu :ui[branch.quickUpdateNamed]{1="feature/units-toggle"}. Der Befehl führt den Eltern-Branch sofort zusammen, ohne Dialogfenster.
:::

## Drag & Drop {#drag-and-drop}

Viele Branch-Vorgänge beginnen damit, dass Sie etwas in der Seitenleiste ziehen. Während Sie ziehen, sagt die Beschriftung neben dem Zeiger, was passieren wird. Verweilen Sie einen Moment über einem reduzierten Ordner oder Remote, dann öffnet er sich.

| Ziehen | Auf | Was passiert |
|---|---|---|
| Einen lokalen Branch | :ui[workspace.title] oder den Branch, auf dem Sie sich befinden | Das Dialogfenster zum Zusammenführen. Mit <kbd>⌥</kbd> erscheint das Dialogfenster für den Rebase. |
| Einen Remote-Branch | :ui[workspace.title] oder den Branch, auf dem Sie sich befinden | Das Dialogfenster zum Pullen |
| Einen Remote-Branch, mit gedrückter <kbd>⌥</kbd> | Den Branch, auf dem Sie sich befinden | Er wird zum Upstream Ihres Branches. |
| Einen lokalen Branch, ein Tag oder einen Commit | :ui[branch.group] | Das Dialogfenster, um daraus einen Branch zu erstellen |
| Einen Remote-Branch | :ui[branch.group] | Das Dialogfenster, um ihn zu verfolgen |
| Einen lokalen Branch | Ein Remote | Das Dialogfenster zum Veröffentlichen |
| Einen lokalen Branch | Einen Remote-Branch | Das Dialogfenster :ui[sync.pushBranch] |
| Einen lokalen Branch oder einen Commit | :ui[sidebar.tags] oder einen Tag-Ordner | Das Dialogfenster zum Erstellen eines Tags |
| Ein Tag | Ein Remote | Das Dialogfenster zum Veröffentlichen des Tags |
| Einen lokalen Branch | :ui[sidebar.pinned] oder :ui[sidebar.archived] | Der Branch wird angeheftet oder archiviert. |
| Einen lokalen Branch | :ui[worktree.group] | Das Dialogfenster, um dafür einen Worktree zu erstellen |

Um einen Branch in einen Ordner zu verschieben, ziehen Sie ihn auf den Ordner. Der Branch wird ohne Dialogfenster umbenannt: in den Ordner plus den letzten Teil seines Namens. Ein Remote-Branch lässt sich nur in Ordner seines eigenen Remotes verschieben. Um einen Branch aus seinem Ordner zu holen, ziehen Sie ihn an den oberen oder unteren Rand der Liste. Die Umbenennung können Sie mit <kbd>⌘Z</kbd> widerrufen.

Sie können auch Commits aus dem Verlauf auf :ui[workspace.title] oder den Branch ziehen, auf dem Sie sich befinden, um sie per Cherry-Pick zu übernehmen. Mit gedrückter <kbd>⌥</kbd> werden sie stattdessen per Revert rückgängig gemacht. Siehe [Einen Commit per Cherry-Pick übernehmen](/guide/history/rewrite/#cherry-pick). Ziehen Sie eine einzelne Datei aus dem Änderungssatz eines Commits dorthin, dann werden nur die Änderungen dieser Datei auf die Arbeitskopie angewendet, ohne sie zu stagen.

## Siehe auch

- [Konflikte lösen](/guide/work/conflicts/)
- [Verlauf umschreiben](/guide/history/rewrite/)
- [Abrufen, Pullen und Pushen](/guide/branches/sync/)
- [Branches](/guide/branches/branches/)
