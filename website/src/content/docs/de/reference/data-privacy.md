---
title: "Daten und Datenschutz"
description: "Erfahren Sie, was Spooky wo sichert, mit welchen Netzwerkadressen es sich verbindet und was Absturz- und Diagnoseberichte enthalten."
---

Es gibt keinen Spooky-Account, und Spooky erfasst keine Nutzungsdaten. Diese Seite führt auf, was es sichert, wo es das sichert und mit welchen Adressen es sich verbindet.

## Auf Ihrem Mac {#mac}

| Was | Wo |
|---|---|
| Einstellungen, die Liste der Repositorys, Benutzerprofile, die Liste der Hosting-Accounts und die Orte von Server-Repositorys auf diesem Mac | Einstellungen von Spooky, `com.rakuyo.spooky` |
| Themen, je eine `.spookytheme`-Datei | `~/Library/Application Support/Spooky/Themes/` |
| Kleine `.spookyrepo`-Ordner, durch die Server-Repositorys unter den zuletzt benutzten Dokumenten erscheinen | `~/Library/Application Support/Spooky/Locations/` |
| Einträge zu Remote-Vorgängen in :ui[activity.title], etwa Abrufen, Pullen und Pushen, 7 Tage lang aufbewahrt | `~/Library/Application Support/Spooky/Activity/` |
| Womit :ui[activity.title] vergleicht, um Änderungen zu zählen, eine Datei pro Repository | `~/Library/Application Support/Spooky/Baselines/` |
| Benutzernamen und Passwörter, die Sie für Git auf einem Server gesichert haben | Schlüsselbund, Einträge mit dem Namen `com.rakuyo.spooky.remote.<host alias>` |
| Token von Hosting-Accounts | Schlüsselbund, Einträge mit dem Namen `com.rakuyo.spooky.hosting.<address>` |
| Caches und Cookies, die macOS für die Netzwerkanfragen von Spooky aufbewahrt | `~/Library/Caches/com.rakuyo.spooky/` und die Einträge in `~/Library/HTTPStorages/`, deren Namen mit `com.rakuyo.spooky` beginnen |
| Verbindungsdateien für Server-Repositorys | Ordner `/tmp/spooky-*`, die beim Schließen der Verbindung entfernt werden |
| Kopien von Dateien, die Sie in der Übersicht oder in anderen Apps öffnen | Temporäre Ordner `spooky-files-*`, die beim Schließen des Repositorys entfernt werden |

Wenn Sie sich bei einem selbst betriebenen GitLab mit Benutzername und Passwort anmelden, behält Spooky die Token, die es dafür erhält. Das Passwort behält es nicht.

Wie Sie all das entfernen, lesen Sie unter [Deinstallieren](/guide/start/install/#uninstall).

Host-Aliasse, die Sie unter :ui[app.name > settings.title] › :ui[settings.sshHosts] hinzufügen, stehen in `~/.ssh/config`, der Datei, die SSH selbst liest. Diese Datei gehört nicht zu Spooky, und beim Deinstallieren von Spooky bleibt sie, wie sie ist. Siehe [Einen Host-Alias hinzufügen](/guide/server/prepare-ssh/#alias).

## Auf Servern {#servers}

Außer in das Repository selbst schreibt Spooky auf einem Server an zwei Orte:

- `~/.spooky/bin/` in Ihrem Benutzerordner: ein kleines Skript, das Spooky über SSH ausführt, sowie Links darauf für Abfragen und das Signieren. Es bleibt für die nächste Verbindung dort. Löschen Sie den Ordner, um es zu entfernen.
- `/tmp/spooky-*`: Dateien für die aktuelle Verbindung. Sie werden beim Schließen der Verbindung entfernt.

Wenn Spooky nach dem [Ort eines Repositorys auf diesem Mac](/guide/server/local-location/#automatic) sucht, legt es kurz eine leere Datei in den Git-Ordner des Repositorys. Gleich nach der Prüfung löscht es die Datei.

Wenn Git auf einem Server nach einem Passwort fragt, sendet Spooky die Antwort von Ihrem Mac über die SSH-Verbindung, und zwar nur an den Git-Befehl, der gefragt hat. Git auf dem Server sichert sie nicht, weil Spooky die Credential Helper von Git für seine Befehle deaktiviert.

## In Repositorys {#repositories}

Spooky sichert einige Dinge in der Git-Konfiguration des Repositorys selbst, als Einträge der Form `branch.<name>.spooky-*`:

- Welche Branches angeheftet oder archiviert sind
- Der Eltern-Branch jedes Branches
- Markierungen für das automatische Archivieren

Diese Einträge wandern mit, wenn Sie einen Branch umbenennen, und verschwinden, wenn Sie ihn löschen. Git-Einstellungen, die Sie unter :ui[repositorySettings.title] des Repositorys ändern, etwa zum Signieren, kommen in dieselbe Konfiguration. Siehe [Repository-Einstellungen](/guide/settings/identity/#repository).

Die Git-Konfiguration wird nicht gepusht, nichts davon erreicht also Ihre Remotes. Bei einem Server-Repository liegt sie auf dem Server.

## Netzwerkverbindungen {#network}

| Spooky verbindet sich mit | Wann |
|---|---|
| Ihren Servern, über SSH | Solange ein Server-Repository geöffnet ist. Spooky verwendet den Host-Alias in `~/.ssh/config`. Eine SMB-Einbindung verbindet sich außerdem mit der Dateifreigabe des Servers. |
| Ihren Git-Remotes | Wenn Sie abrufen, pullen, pushen oder klonen, und beim automatischen Abrufen. Bei einem Server-Repository verbindet sich Git vom Server aus, nicht von Ihrem Mac. |
| `github.com` und `api.github.com` oder der Adresse Ihres GitLab | Wenn Sie einen Hosting-Account hinzufügen oder erneut authentifizieren und wenn Sie eine Funktion nutzen, die einen braucht: Pull Requests und Merge Requests, die Vervollständigung von Issue-Nummern, den Status in der Branch-Übersicht und das Veröffentlichen eines Repositorys. Diese Anfragen kommen von Ihrem Mac. Siehe [Wohin Anfragen gehen](/guide/hosting/accounts/#network). |
| `gravatar.com` | Um Bilder von Commit-Autoren zu zeigen |
| `github.com`, für die Releases von Spooky | Um nach Updates zu suchen |

Das automatische Abrufen läuft standardmäßig alle 30 Minuten. Um das zu ändern, öffnen Sie :ui[app.name > settings.title], klicken Sie auf :ui[settings.general] und wählen Sie neben :ui[settings.autoFetch] eine Option. Wählen Sie :ui[settings.autoFetch.never], um nur auf Ihre Anforderung abzurufen. Siehe [Vorgänge](/guide/settings/general/#operations).

Für das Bild eines Commit-Autors erhält Gravatar einen Hash der E-Mail-Adresse des Autors, nicht die Adresse selbst. Geladene Bilder bleiben nur im Arbeitsspeicher und sind weg, wenn Sie Spooky beenden. Bilder von GitHub- und GitLab-Benutzern kommen von diesen Diensten. Es gibt keine Einstellung, um Bilder auszuschalten.

Spooky sucht standardmäßig einmal am Tag nach Updates. Um das zu beenden, deaktivieren Sie :ui[updates.automaticChecks] unter :ui[app.name > settings.title] › :ui[settings.updates]. Siehe [Spooky aktuell halten](/guide/start/install/#updates).

Einträge im Menü :ui[menu.help], etwa :ui[help.help] und :ui[help.support], öffnen Webseiten in Ihrem Browser.

## Absturzberichte {#crash-reports}

Wenn Spooky beim letzten Mal unerwartet beendet wurde, liest es den Absturzbericht, den macOS auf Ihrem Mac gesichert hat. Beim nächsten Start fragt es: :ui[crash.title].

- Klicken Sie auf :ui[crash.report], um in Ihrem Browser eine Seite für ein neues Issue auf GitHub zu öffnen, ausgefüllt mit einer Zusammenfassung des Absturzes.
- Klicken Sie auf :ui[crash.dontReport], um das zu überspringen. Spooky fragt zu diesem Absturz nicht noch einmal.

Die Zusammenfassung enthält Version und Build von Spooky, die macOS-Version, die Art des Absturzes und bis zu 30 Zeilen des Aufrufstapels des abgestürzten Threads. Bevor sie Ihren Mac verlässt, ersetzt Spooky Ihren Benutzerordner, Ihren Benutzernamen, E-Mail-Adressen, IP-Adressen, Token und Passwörter in Webadressen durch Platzhalter.

Die Zusammenfassung ist Teil der Webadresse der Seite. GitHub erhält sie, sobald sich die Seite öffnet. Das Issue wird erst erstellt, wenn Sie es im Browser absenden. Sie können den Text vorher bearbeiten oder die Seite schließen.

Um die Frage beim nächsten Mal zu überspringen, aktivieren Sie im Dialogfenster :ui[settings.crashReports.always]. Spooky öffnet die Issue-Seite dann sofort. Dieselbe Option finden Sie unter :ui[app.name > settings.title] › :ui[settings.integration].

## Diagnoseberichte {#diagnostic-reports}

Wenn Sie ein Problem melden, hilft ein Diagnosebericht zu zeigen, was passiert ist. Wählen Sie :ui[menu.help > help.diagnosticReport] und wählen Sie, wo er gesichert wird. Spooky sichert eine Textdatei und zeigt sie im Finder. Es sendet den Bericht nirgendwohin.

Der Bericht enthält:

- Version und Build von Spooky, die macOS-Version und Ihre ersten drei bevorzugten Sprachen
- Das Git-Programm auf diesem Mac und seine Version
- Einstellungen, die beeinflussen, wie Spooky läuft, etwa Erscheinungsbild, Update-Kanal, Terminal-App, Vergleichs- und Zusammenführungswerkzeuge, SSH-Agent, Git-Programm und ob Umgebungsvariablen aus der Login-Shell gelesen werden
- Wie viele lokale und Server-Repositorys Sie haben
- Namen, Zeiten und Ergebnisse der letzten 20 Vorgänge
- Das Protokoll von Spooky aus der letzten Stunde der aktuellen Sitzung, bis zu 500 Zeilen

Er enthält keine Repository-Pfade, Host-Aliasse, Passwörter oder Werte von Umgebungsvariablen. Spooky ersetzt Ihren Benutzerordner, Ihren Benutzernamen, E-Mail-Adressen, IP-Adressen und Token durch Platzhalter, genauso wie in Absturzberichten. Öffnen Sie die Datei und lesen Sie sie, bevor Sie sie weitergeben.

Das Protokoll von Spooky vermerkt Verbindungsänderungen und wann Vorgänge beginnen, enden oder fehlschlagen. Es hält keine Befehlsargumente oder -ausgaben, Commit-Nachrichten, Passwörter oder Token fest.

## Siehe auch

- [Spooky installieren](/guide/start/install/)
- [So funktionieren Server-Repositorys](/guide/server/overview/)
- [Hosting-Accounts](/guide/hosting/accounts/)
- [Systemanforderungen](/reference/requirements/)
