---
title: "So funktionieren Server-Repositorys"
description: "Erfahren Sie, was auf dem Server und was auf Ihrem Mac geschieht, was Spooky auf dem Server ablegt und worin sich Server-Repositorys von lokalen unterscheiden."
---

Ein Server-Repository ist ein Git-Repository auf einem anderen Rechner, das Spooky per SSH öffnet. Seine Dateien bleiben auf dem Server, und Git läuft dort. Sie klonen es nicht erst auf Ihren Mac. Diese Seite erklärt, was jede Seite tut, was Spooky auf dem Server hinterlässt und was anders funktioniert als bei einem Repository auf Ihrem Mac.

Um eines einzurichten, beginnen Sie mit [SSH vorbereiten](/guide/server/prepare-ssh/) und fahren Sie mit [Server-Repository hinzufügen](/guide/server/add/) fort.

## Was wo geschieht {#where}

Spooky verbindet sich mit dem SSH, das zu macOS gehört. Es verwendet einen Host-Alias aus Ihrer Datei `~/.ssh/config` und meldet sich deshalb genauso am Server an wie der Befehl `ssh` im Terminal.

Auf dem Server:

- Git führt jeden Befehl aus, mit dem eigenen Git und der eigenen Umgebung des Servers.
- Spooky liest und schreibt Dateien über die SSH-Verbindung. Große Dateien kommen per SFTP, dem Dateiübertragungsteil von SSH.
- Dateien, die Sie löschen, und neue Dateien, die Sie verwerfen, kommen in den Papierkorb des Servers, falls er einen hat.
- Abrufen, Pullen und Pushen erreichen Remotes wie GitHub vom Server aus. Sie verwenden das Netzwerk und die SSH-Schlüssel des Servers.

Auf Ihrem Mac:

- Die Fenster, Listen und Diffs, mit denen Sie arbeiten.
- Die SSH-Verbindung zum Server. Spooky hält für jedes geöffnete Repository eine Verbindung und sendet jeden Befehl darüber.
- Fragen von Git auf dem Server, etwa nach einem Passwort oder der Passphrase eines Schlüssels. Siehe [Abfragen von Passwort und Passphrase](/guide/server/connection/#prompts).
- Anfragen an GitHub und GitLab, etwa das Anmelden bei Ihrem Account oder das Laden von Pull Requests.
- Kopien von Dateien, die Sie in der Übersicht oder in einer anderen App öffnen.

:::note
Bei einem Remote, das per SSH erreicht wird, muss der Server dessen Host-Schlüssel bereits kennen. Wenn nicht, melden Sie sich am Server an und verbinden Sie sich von dort einmal mit dem Remote.
:::

## Was Spooky auf dem Server ablegt {#on-server}

Spooky braucht keinen Administratorzugriff und installiert keinen Dienst. Es hinterlässt zwei Dinge auf dem Server:

- **Ein Hilfsskript in `~/.spooky/bin/`** in Ihrem Benutzerordner auf dem Server. Es gibt Gits Fragen an Ihren Mac weiter. Spooky legt es beim Verbinden dort ab und behält es für spätere Verbindungen. Die anderen Namen in diesem Ordner, die auf `-askpass`, `-gpg` und so weiter enden, sind Links auf dieselbe Datei.
- **Temporäre Dateien in `/tmp/spooky-*`**, solange ein Repository geöffnet ist. Spooky entfernt sie, wenn Sie das Repository schließen.

Das Hilfsskript läuft mit `/usr/bin/perl`, das die meisten macOS- und Linux-Server bereits haben. Die vollständige Liste finden Sie unter [Systemanforderungen](/reference/requirements/#servers).

Sie können `~/.spooky` jederzeit löschen. Spooky installiert das Hilfsskript beim nächsten Verbinden neu.

## Worin sich Server-Repositorys unterscheiden {#differences}

Ein Server-Repository öffnet sich in der gleichen Art von Fenster wie ein Repository auf Ihrem Mac. Die meisten Ansichten und Befehle funktionieren genauso. An diesen sichtbaren Zeichen erkennen Sie, dass ein Repository auf einem Server liegt:

::screenshot[Das Fenster eines Server-Repositorys. Der Titel lautet spooky-test:driftwood, darunter stehen die aktuelle Ansicht und der Branch. Die Symbolleiste zeigt den Host-Alias spooky-test. Ein Streifen oben in der mittleren Spalte meldet, dass spooky-test verbunden ist. Darunter stehen der Commit-Bereich und die Liste geänderter Dateien. Die rechte Spalte zeigt die Änderungen in der ausgewählten Datei.]{name="hero" frame="window" markers="45.8,3.3 64.4,7.2 40,8.9"}

1. Der Fenstertitel beginnt mit dem Host-Alias, wie in `driftwood-server:driftwood`. Das Fenster „Repositorys“ zeigt Namen auf dieselbe Weise.
2. Das Objekt :ui[toolbar.host] in der Symbolleiste zeigt den Host-Alias.
3. Der Verbindungsstatus steht oben in der Arbeitskopie, im Verlauf und in anderen Listen. Siehe [Verbindungsstatus und erneutes Verbinden](/guide/server/connection/).

Einiges funktioniert anders:

| Was | In einem Server-Repository |
|---|---|
| Änderungen auf dem Server | Spooky prüft den Server alle 2 Sekunden auf Änderungen, solange das Fenster des Repositorys vorne ist, und sonst alle 10 Sekunden. Wenn der Server langsam antwortet, prüft es seltener. |
| Verlust der Verbindung | Sie können weiter ansehen, was Spooky zuletzt gelesen hat, aber nichts ändern, bis die Verbindung wieder steht. |
| :ui[action.revealFinder] | Der Finder braucht einen Ordner auf Ihrem Mac, der die Dateien des Servers zeigt. Siehe [Ort auf diesem Mac](/guide/server/local-location/). |
| :ui[action.openTerminal] | Das Terminal meldet sich mit `ssh` am Server an und wechselt in den Repository-Ordner. |
| :ui[action.copyPath] | Der kopierte Pfad beginnt mit dem Host-Alias, wie in `driftwood-server:/srv/git/driftwood`. |
| Eine Datei in einer anderen App öffnen | Die meisten Apps erhalten eine Kopie der Datei. Spooky schreibt Ihre Änderungen beim Sichern auf den Server zurück. Siehe [Terminal und andere Apps](/guide/server/local-location/#terminal). |
| Dateien verwerfen oder löschen | Spooky fragt nach, bevor es Änderungen verwirft, weil dabei Dateien auf dem Server überschrieben werden. Gelöschte Dateien und verworfene neue Dateien kommen in den Papierkorb des Servers. Hat der Server keinen Papierkorb, fragt Spooky zuerst und löscht sie dann endgültig. |
| Einstellungen unter :ui[settings.environment] | Sie gelten nur für Git auf Ihrem Mac. Git auf einem Server verwendet die eigene Umgebung des Servers. Siehe [Umgebung](/guide/settings/general/#environment). |

Die Bestätigungen für das Verwerfen von Änderungen, das endgültige Löschen von Dateien und das Wiederherstellen von Dateien können Sie unter :ui[app.name > settings.title] › :ui[settings.general] ausschalten. Siehe [Bestätigungen](/guide/settings/general/#confirmations).

## Siehe auch

- [SSH vorbereiten](/guide/server/prepare-ssh/)
- [Server-Repository hinzufügen](/guide/server/add/)
- [Systemanforderungen](/reference/requirements/)
