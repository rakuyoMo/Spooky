---
title: "Abrufen, Pullen und Pushen"
description: "Abrufen, pullen und pushen, einen Branch zum ersten Mal veröffentlichen, synchronisieren, per Force-Push überschreiben und automatisch abrufen."
---

Diese Vorgänge tauschen Commits mit [Remotes](/guide/branches/tags-remotes/#remotes) aus:

- Abrufen lädt neue Commits von einem Remote. Ihre Branches und die Arbeitskopie bleiben, wie sie sind.
- Pullen ruft einen Remote-Branch ab und holt dessen Commits in den Branch, auf dem Sie sich befinden.
- Pushen sendet Ihre Commits an einen Remote-Branch.

In der Symbolleiste stehen :ui[sync.fetch], :ui[sync.pull] und :ui[sync.push] nebeneinander, daneben :ui[sync.sync]. Dieselben Vorgänge finden Sie im Menü :ui[menu.repository].

Abrufen, Pullen, Pushen und Synchronisieren werden nicht im Widerrufen-Verlauf festgehalten und lassen sich daher nicht widerrufen. Das Veröffentlichen eines Branches lässt sich widerrufen.

:::note[Server-Repositorys]
Remotes werden vom Server aus erreicht, mit dem Netzwerk und den SSH-Schlüsseln des Servers. Wenn ein Remote ein Passwort verlangt, fragt Spooky Sie danach. Siehe [Abfragen von Passwort und Passphrase](/guide/server/connection/#prompts).
:::

## Abrufen {#fetch}

1. Klicken Sie in der Symbolleiste auf :ui[sync.fetch] oder wählen Sie :ui[menu.repository > sync.fetchMenu] (<kbd>⇧⌘F</kbd>). Um ein einzelnes Remote abzurufen, klicken Sie in der Seitenleiste mit der rechten Maustaste darauf und wählen Sie :ui[remote.fetchMenu]{1="origin"} aus dem Menü.
2. Wählen Sie das Remote in :ui[sync.remote] oder aktivieren Sie :ui[sync.allRemotes].
3. Legen Sie die Optionen fest:
   - :ui[sync.prune] entfernt Remote-Branches, die auf dem Remote gelöscht wurden. Die Option ist anfangs aktiviert.
   - :ui[sync.fetchSubmodules] ruft auch neue Commits in ausgecheckten Submodulen ab.
   - :ui[sync.allTags] ruft auch jedes Tag auf dem Remote ab.
4. Klicken Sie auf :ui[sync.fetch].

Spooky merkt sich alle Optionen außer :ui[sync.allTags].

Nach dem Abrufen sind die Remote-Branches in der Seitenleiste aktuell, und ↓ an einem lokalen Branch zählt die Commits, die Sie pullen können.

:ui[menu.repository > sync.fetchAll] ruft sofort jedes Remote ab, ohne Dialogfenster. Remotes, bei denen in den [Einstellungen](/guide/branches/tags-remotes/#remote-settings) :ui[remote.skipFetchAll] gesetzt ist, werden übersprungen.

## Pullen {#pull}

1. Klicken Sie in der Symbolleiste auf :ui[sync.pull] oder wählen Sie :ui[menu.repository > sync.pullMenu] (<kbd>⇧⌘P</kbd>). Um einen bestimmten Remote-Branch zu pullen, klicken Sie mit der rechten Maustaste darauf und wählen Sie :ui[branch.pullMenu]{1="origin/main"} aus dem Menü.
2. Wählen Sie den Branch in :ui[sync.remoteBranch]. Anfangs ist das der [Upstream](/guide/branches/branches/#track) des Branches, auf dem Sie sich befinden.
3. Aktivieren Sie :ui[sync.rebase], um Ihre Commits auf die gepullten zu setzen, statt beide mit einem Merge-Commit zu verbinden. Spooky merkt sich diese Auswahl.
4. Unter den Optionen sagt eine Vorschau, ob der Pull auf Konflikte stoßen wird. Siehe [Konflikte vorab prüfen](/guide/branches/merge-rebase/#preview).
5. Legen Sie die Optionen fest:
   - :ui[merge.verify] bricht den Pull ab, wenn der gepullte Commit keine vertrauenswürdige Signatur hat. Spooky merkt sich die Option.
   - :ui[sync.skipHooks] überspringt dieses Mal die Git-Hooks des Repositorys.
6. Klicken Sie auf :ui[sync.pull].

Für einen Pull müssen Ihre versionierten Dateien unverändert sein. Andernfalls bietet Spooky an, die Änderungen zuerst zu stashen. Siehe [Automatisches Stashen](/guide/work/stash/#auto-stash). Neue Dateien stören nur, wenn der Pull sie überschreiben würde.

Wenn der Pull auf Konflikte stößt, wechselt Spooky zur Arbeitskopie und zeigt ein Banner. Siehe [Konflikte lösen](/guide/work/conflicts/#banner).

## Pushen {#push}

1. Klicken Sie in der Symbolleiste auf :ui[sync.push] oder wählen Sie :ui[menu.repository > sync.pushMenu] (<kbd>⇧⌘U</kbd>).
2. Wählen Sie den Remote-Branch in :ui[sync.destination]. Anfangs ist das der Upstream des Branches, auf dem Sie sich befinden.
3. Legen Sie die Optionen fest:
   - :ui[sync.pushAllTags] pusht auch jedes lokale Tag.
   - :ui[sync.forcePush] überschreibt den Remote-Branch, wenn ein normaler Push nicht möglich ist. Siehe [Force-Push](#force-push).
   - :ui[sync.pushSubmodules] kümmert sich um Submodul-Commits, auf die dieser Push verweist. Wählen Sie zwischen :ui[sync.pushSubmodules.onDemand] und :ui[sync.pushSubmodules.check].
   - :ui[sync.skipHooks] überspringt dieses Mal die Git-Hooks des Repositorys.
4. Klicken Sie auf :ui[sync.pushHead].

Spooky merkt sich die Optionen für Tags und Submodule.

Wenn der Branch, auf dem Sie sich befinden, noch keinen Remote-Branch verfolgt, öffnet :ui[sync.push] stattdessen das Dialogfenster zum Veröffentlichen. Siehe [Einen Branch veröffentlichen](#publish). Wenn das Repository gar kein Remote hat, öffnet sich das Dialogfenster zum Veröffentlichen des Repositorys. Siehe [Ein Repository veröffentlichen](/guide/hosting/accounts/#publish).

Wenn jemand anderes zuerst zum Remote-Branch gepusht hat, lehnt das Remote Ihren Push ab. Pullen Sie dessen Commits und pushen Sie dann erneut.

Um einen Branch zu pushen, auf dem Sie sich nicht befinden, ziehen Sie ihn in der Seitenleiste auf einen Remote-Branch. Das Dialogfenster :ui[sync.pushBranch] pusht ihn dorthin. Es ist ein einfacher Push ohne Optionen, und er ändert nicht, was der Branch verfolgt.

## Einen Branch veröffentlichen {#publish}

Ein neuer Branch existiert nur in Ihrem Repository, bis Sie ihn veröffentlichen. Dabei wird er auf einem Remote erstellt.

1. Wählen Sie :ui[menu.repository > sync.publishMenu], oder klicken Sie mit der rechten Maustaste auf den Branch und wählen Sie :ui[branch.publishMenu]{1="feature/station-map"} aus dem Menü. Sie können den Branch auch in der Seitenleiste auf ein Remote ziehen.
2. Prüfen Sie :ui[branch.local] und :ui[sync.remote]. :ui[branch.name] ist der Name auf dem Remote, anfangs derselbe wie der lokale Name.
3. Mit :ui[sync.setUpstream] verfolgt Ihr Branch den neuen Remote-Branch, sodass spätere Pulls und Pushes dorthin gehen. Die Option ist anfangs aktiviert.
4. Aktivieren Sie :ui[sync.skipHooks], um die Git-Hooks des Repositorys zu überspringen.
5. Klicken Sie auf :ui[sync.publish].

Um das zurückzunehmen, wählen Sie :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

## Synchronisieren {#sync}

Synchronisieren ruft ab, pullt und pusht den Branch, auf dem Sie sich befinden, nacheinander.

1. Klicken Sie in der Symbolleiste auf :ui[sync.sync] oder wählen Sie :ui[menu.repository > sync.syncMenu] (<kbd>⇧⌘Y</kbd>).
2. Wählen Sie den Branch in :ui[sync.remoteBranch]. Anfangs ist das der Upstream des Branches, auf dem Sie sich befinden.
3. Aktivieren Sie bei Bedarf :ui[sync.rebase]. Die Vorschau darunter sagt, ob der Pull auf Konflikte stoßen wird.
4. Legen Sie die Optionen fest: :ui[merge.verify], :ui[sync.pushAllTags], :ui[sync.pushSubmodules] und :ui[sync.skipHooks] funktionieren wie beim Pullen und Pushen.
5. Klicken Sie auf :ui[sync.syncHead].

Wie beim Pullen bietet Spooky an, Änderungen an versionierten Dateien zuerst zu stashen.

Wenn ein Schritt fehlschlägt, hält Spooky dort an und sagt Ihnen, bei welchem Schritt es angehalten hat und welche Schritte erledigt sind. In :ui[activity.title] bekommen der Pull und der Push je einen Eintrag.

## An einen anderen Ort pushen {#push-to}

So pushen Sie einen Branch, ein Tag oder einen Commit zu einem beliebigen Branch oder einer beliebigen Referenz auf einem Remote:

1. Wählen Sie :ui[menu.repository > sync.pushToMenu], oder klicken Sie mit der rechten Maustaste auf einen Branch und wählen Sie :ui[branch.pushToMenu]{1="main"} aus dem Menü. Auch Tags haben :ui[tag.pushToMenu]{1="v0.4.0"} in ihrem Menü.
2. Wählen Sie in :ui[sync.revision], was gepusht wird, und in :ui[sync.remote] das Remote.
3. Geben Sie in :ui[sync.refSpec] ein, wohin es geht: einen neuen oder vorhandenen Branch-Namen oder eine vollständige Referenz wie `refs/tags/v0.4.0`.
4. Klicken Sie auf :ui[sync.pushRevision].

Bei einem Branch beginnt das Dialogfenster mit dem Remote-Branch, den er verfolgt. Bei einem Tag beginnt es mit `refs/tags/` und dem Namen des Tags.

## Force-Push {#force-push}

Nachdem Sie bereits gepushte Commits umgeschrieben haben, etwa durch Ändern des letzten Commits oder ein Rebase, wird ein normaler Push abgelehnt: Der Remote-Branch hat Commits, die Ihr Branch nicht mehr hat. Ein Force-Push ersetzt den Remote-Branch durch Ihren.

Spooky führt Force-Pushes nur mit Lease aus. Der Push geht nur durch, wenn der Remote-Branch noch dort steht, wo er bei Ihrem letzten Abrufen stand. Wenn inzwischen jemand gepusht hat, lehnt Git ab, und nichts wird überschrieben. Spooky weicht nie auf einen ungeschützten Force-Push aus.

1. Wählen Sie :ui[menu.repository > sync.forcePushMenu] (<kbd>⌃⌘U</kbd>), oder klicken Sie mit der rechten Maustaste auf einen lokalen Branch und wählen Sie den Befehl aus dem Menü.
2. Wählen Sie den lokalen Branch in :ui[branch.target] und den Remote-Branch in :ui[sync.destination].
3. Lesen Sie den Vergleich darunter. Er sagt, wie viele Commits der Push dem Remote-Branch hinzufügt und wie viele er überschreibt. Dabei gilt:
   - Eine grüne Zeile bedeutet, dass der Remote-Branch auf der Version steht, die Ihr Branch vor dem Umschreiben hatte. Das ist der Normalfall.
   - Eine gelbe Zeile bedeutet, dass der Remote-Branch woanders steht oder Commits hat, die Ihr Branch nie hatte. Prüfen Sie, ob Sie sie wirklich überschreiben möchten.
   - Wenn beide Branches auf demselben Commit stehen, gibt es nichts zu pushen.
4. Klicken Sie auf :ui[sync.forcePush].

::screenshot[Das Dialogfenster für den Force-Push mit Lease. Der lokale Branch ist feature/units-toggle, der Remote-Branch origin/feature/units-toggle. Darunter sagt eine Zeile mit grünem Häkchen, dass der Remote-Branch auf der Version steht, die dieser Branch vor dem Umschreiben hatte.]{name="branches-force-push" frame="dialog" markers="16.4,65.9"}

1. Der Vergleich

Die Option :ui[sync.forcePush] im Dialogfenster zum Pushen verwendet denselben Schutz.

:::tip
Wählen Sie :ui[menu.view > menu.customizeToolbar], um :ui[toolbar.forcePush] und :ui[toolbar.pushTo] zur Symbolleiste hinzuzufügen.
:::

## Schnellversionen {#quick}

Halten Sie <kbd>⌥</kbd> gedrückt, dann werden :ui[sync.fetch], :ui[sync.pull], :ui[sync.push] und :ui[sync.sync] in der Symbolleiste zu :ui[sync.quickFetch], :ui[sync.quickPull], :ui[sync.quickPush] und :ui[sync.quickSync]. Die Menüeinträge ändern sich genauso, zum Beispiel zu :ui[sync.quickPushMenu].

Eine Schnellversion läuft sofort, ohne Dialogfenster:

- Sie arbeitet mit dem Upstream des Branches, auf dem Sie sich befinden.
- Sie verwendet die Optionen, die Sie zuletzt im Dialogfenster gewählt haben. :ui[sync.skipHooks] wird nie übernommen.
- :ui[sync.quickFetch] ruft das Remote ab, das der aktuelle Branch verfolgt. Es ruft jedes Remote ab, wenn Sie zuletzt :ui[sync.allRemotes] gewählt haben oder der Branch nichts verfolgt.
- Wenn der Branch, auf dem Sie sich befinden, keinen Remote-Branch verfolgt, weisen :ui[sync.quickPush] und :ui[sync.quickSync] Sie darauf hin.

Auch Kontextmenüs haben Schnellversionen, etwa :ui[sync.quickFetchNamed]{1="origin"} für ein Remote und :ui[sync.quickPullNamed]{1="origin/main"} für einen Remote-Branch.

## Automatisch abrufen {#auto-fetch}

Spooky kann im Hintergrund abrufen, damit die Remote-Branches und die Zähler ↓ aktuell bleiben. Wie oft, wählen Sie unter :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.autoFetch]: :ui[settings.autoFetch.never], alle 5, 10 oder 30 Minuten oder :ui[settings.autoFetch.hour]. Anfangs sind es alle 30 Minuten. Siehe [Vorgänge](/guide/settings/general/#operations).

- Spooky sucht etwa 10 Sekunden nach dem Öffnen eines Repositorys nach fälligen Remotes und danach alle paar Minuten. Ein Remote ist fällig, wenn es noch nie abgerufen wurde oder seit dem letzten Abrufen das Intervall verstrichen ist.
- Es ruft nur ab, solange das Fenster das Repository zeigt und kein Dialogfenster geöffnet ist. Es läuft weiter, während Spooky im Hintergrund ist.
- Es beginnt nur, wenn im Repository nichts anderes läuft. Wenn Sie während des Abrufens etwas starten, hält es an und lässt Ihrem Vorgang den Vortritt. :ui[activity.title] vermerkt, für welchen Vorgang es angehalten hat.
- Es fragt nie nach Passwörtern. Wenn es fehlschlägt, erscheint der Fehler nur in :ui[activity.title].
- Es verwendet die Optionen zum Bereinigen und zu Submodulen, die Sie zuletzt im Dialogfenster zum Abrufen gewählt haben, und überspringt Remotes, bei denen :ui[remote.skipFetchAll] gesetzt ist.
- In einem lokalen Repository überspringt es Remotes, die Pfade auf Ihrem Mac sind, und ruft nicht ab, solange der Mac offline ist.

## Siehe auch

- [Zusammenführen und Rebase](/guide/branches/merge-rebase/)
- [Branches](/guide/branches/branches/)
- [Warteschlange und Aktivität](/guide/advanced/queue-activity/)
- [Stashes](/guide/work/stash/)
