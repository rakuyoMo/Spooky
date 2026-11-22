---
title: "Verbindungsstatus und erneutes Verbinden"
description: "Verstehen Sie den Verbindungsstatus, die Abfragen von Passwort und Passphrase, Verbindungsabbrüche und erneutes Verbinden sowie das, was Sie ohne Verbindung noch sehen."
---

Ein Server-Repository hängt von seiner SSH-Verbindung ab. Diese Seite erklärt, woran Sie erkennen, ob es verbunden ist, was die Fragen vom Server bedeuten und was geschieht, wenn die Verbindung abbricht.

## Verbindungsstatus {#status}

In einem Server-Repository zeigt ein Streifen oben in jeder Liste den Host-Alias und den Verbindungsstatus. Sie finden ihn in der Arbeitskopie, im Verlauf, in den Stashes, im Reflog, im Dateiverlauf und in der Dateiliste eines Commits.

| Status | Bedeutung |
|---|---|
| :ui[connection.connecting] | Spooky baut die Verbindung auf. |
| :ui[connection.connected] | Die Verbindung funktioniert. |
| :ui[connection.reconnecting] | Die Verbindung ist abgebrochen, und Spooky versucht es erneut. |
| :ui[connection.unavailable] | Der letzte Versuch ist fehlgeschlagen. Spooky versucht es 5 Sekunden später erneut. |

Solange das Repository nicht verbunden ist, wird der Streifen gelb und zeigt mehr:

- Einen Hinweis, dass Spooky die letzte erfolgreiche Momentaufnahme zeigt und Schreibvorgänge deaktiviert sind, bis die Verbindung wiederhergestellt ist.
- Den Grund, etwa :ui[remoteError.unavailable]. Klicken Sie darauf, um die Originalausgabe von SSH zu sehen.
- Die Taste :ui[action.reconnect], solange der Status :ui[connection.unavailable] lautet.

::screenshot[Der obere Teil der Arbeitskopie eines Server-Repositorys, das seine Verbindung verloren hat. Ein Streifen meldet, dass spooky-test nicht verfügbar ist, mit einer Taste zum erneuten Verbinden. Darunter sagt ein Hinweis, dass Spooky die letzte erfolgreiche Momentaufnahme zeigt und Schreibvorgänge deaktiviert sind, bis die Verbindung wiederhergestellt ist. Eine eingeklappte Zeile meldet, dass die Serververbindung nicht verfügbar ist.]{name="server-unavailable" frame="closeup"}

## Abfragen von Passwort und Passphrase {#prompts}

Spooky meldet sich am Server an, ohne etwas zu fragen. Git auf dem Server braucht aber manchmal eine Antwort, zum Beispiel ein Passwort, wenn Sie per HTTPS zu einem Remote pushen. Spooky gibt die Frage an Ihren Mac weiter und zeigt sie in einem Dialogfenster:

| Dialogfenster | Wann es erscheint |
|---|---|
| :ui[callback.username.title], :ui[callback.password.title] | Ein Remote fragt, wer Sie sind. Das geschieht meist bei Remotes, die per HTTPS erreicht werden. |
| :ui[callback.privateKey.title] | Der SSH-Schlüssel, den der Server für ein Remote verwendet, ist mit einer Passphrase geschützt. |
| :ui[signing.unlock] | Git braucht die Passphrase des Signaturschlüssels auf dem Server, um einen Commit oder Tag zu signieren. |
| :ui[callback.editor] | Git möchte, dass Sie einen Text bearbeiten, etwa eine Nachricht. |

Die erste Zeile des Dialogfensters nennt den Server. Ein Dialogfenster für einen privaten Schlüssel zeigt außerdem den Pfad des Schlüssels auf dem Server.

Bei einem Benutzernamen oder Passwort aktivieren Sie :ui[callback.saveKeychain], um die Antwort zu behalten. Wenn Git auf diesem Server das nächste Mal fragt, antwortet Spooky aus dem Schlüsselbund. Wenn Sie einen GitHub- oder GitLab-Account hinzugefügt haben, antwortet Spooky zuerst mit diesem Account. Siehe [Hosting-Accounts](/guide/hosting/accounts/).

Einige Dinge, die Sie wissen sollten:

- Jedes Dialogfenster wartet 2 Minuten. Wenn Sie nicht rechtzeitig antworten, erhält Git keine Antwort, und der Befehl schlägt fehl.
- Das automatische Abrufen fragt nie. Es verwendet nur Accounts und Antworten, die im Schlüsselbund gesichert sind. Wenn diese nicht reichen, wird es abgebrochen.
- Dialogfenster für Passphrasen von Git auf dem Server erfordern OpenSSH 8.4 oder neuer auf dem Server.

## Verbindungsabbrüche und erneutes Verbinden {#reconnect}

Wenn die Verbindung abbricht, verbindet sich Spooky von selbst erneut. Nach jedem fehlgeschlagenen Versuch lautet der Status :ui[connection.unavailable]. Spooky versucht es 5 Sekunden später erneut. Um es sofort zu versuchen, klicken Sie auf :ui[action.reconnect]. Sobald die Verbindung wieder steht, lädt Spooky das Repository neu.

Änderungen, die Sie vorgenommen haben, werden nach einem Abbruch nicht wiederholt:

- Vorgänge, die in der Warteschlange des Repositorys warten, werden abgebrochen. Sie laufen nach dem erneuten Verbinden nicht. Starten Sie sie neu, wenn Sie sie noch brauchen.
- Ein Vorgang, der beim Abbruch der Verbindung lief, wird nicht wiederholt. Nach dem erneuten Verbinden prüft Spooky den Branch, die Anzahl der Änderungen, die Index-Sperre und ob ein Merge oder Rebase läuft.

Diese Prüfung erscheint im Dialogfenster :ui[recovery.title]. Es sagt Ihnen, ob der Vorgang überhaupt begonnen hat und ob sich der aktuelle Commit bewegt hat. Sehen Sie sich das Ergebnis an, bevor Sie den Vorgang erneut versuchen.

## Ohne Verbindung {#offline}

Sie können weiter ansehen, was Spooky zuletzt gelesen hat: die Listen, die ausgewählte Datei und ihre Änderungen. Alles, was das Repository ändert, ist nicht verfügbar, bis die Verbindung wieder steht.

Wenn der Server beim Öffnen eines Repositorys nicht erreichbar ist, zeigt das Fenster :ui[missing.unreachable.title]{1="driftwood-server"} mit der Ausgabe von SSH. Klicken Sie auf :ui[action.refresh], um es erneut zu versuchen, oder auf :ui[action.close], um zum Fenster „Repositorys“ zurückzukehren.

:::tip
Führen Sie `ssh -o BatchMode=yes driftwood-server git --version` im Terminal aus, mit Ihrem eigenen Host-Alias. Wenn das fehlschlägt, liegt das Problem zwischen Ihrem Mac und dem Server, nicht in Spooky. Siehe [Testen, wie Spooky sich verbindet](/guide/server/prepare-ssh/#test).
:::

## Siehe auch

- [SSH vorbereiten](/guide/server/prepare-ssh/)
- [Server-Repository hinzufügen](/guide/server/add/)
- [So funktionieren Server-Repositorys](/guide/server/overview/)
