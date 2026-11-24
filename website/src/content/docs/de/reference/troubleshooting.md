---
title: "Fehlerbehebung"
description: "Häufige Probleme beheben, etwa fehlgeschlagene Verbindungen, ein veraltetes Git, Zugriffsrechte und PATH auf dem Server, und erfahren, wie Sie ein Problem melden."
---

Jedes Problem unten beginnt mit dem, was Sie sehen, und erklärt dann, warum es auftritt und was zu tun ist. Viele Fehler in Spooky zeigen auch die Originalausgabe von Git oder SSH, die oft die genaue Ursache nennt.

## Keine Verbindung zu einem Server {#connect}

Ein Verbindungsproblem zeigt sich an einer dieser Stellen:

- Das Dialogfenster :ui[remote.form.title] bleibt geöffnet und sagt, was zu korrigieren ist. Die einzelnen Fälle finden Sie unter [Wenn die Prüfung fehlschlägt](/guide/server/add/#results).
- Beim Öffnen eines Server-Repositorys erscheint :ui[missing.unreachable.title]{1="driftwood-server"}. Siehe [Ohne Verbindung](/guide/server/connection/#offline).
- In einem geöffneten Server-Repository wird der Streifen oben in der Liste gelb und nennt den Grund. Siehe [Verbindungsstatus](/guide/server/connection/#status).

Versuchen Sie zuerst dieselbe Anmeldung außerhalb von Spooky. Führen Sie Folgendes im Terminal aus, mit Ihrem eigenen Host-Alias:

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

Wenn das fehlschlägt, liegt das Problem zwischen Ihrem Mac und dem Server. Was die einzelnen Ausgaben bedeuten, lesen Sie unter [Testen, wie Spooky sich verbindet](/guide/server/prepare-ssh/#test). Wenn es im Terminal funktioniert, Spooky sich aber trotzdem nicht anmelden kann, verwendet Spooky möglicherweise einen anderen SSH-Agenten. Siehe [SSH-Agent](/guide/settings/integration/#ssh-agent).

Der Grund, den Spooky anzeigt, sagt Ihnen, wo Sie suchen müssen:

| Grund | Was zu tun ist |
|---|---|
| :ui[remoteError.authentication] | Der Server akzeptiert Ihren Schlüssel nicht, oder Ihr Mac kann ihn nicht entsperren. Laden Sie den Schlüssel nach einem Neustart erneut, wie unter [Nach einem Neustart Ihres Mac](/guide/server/prepare-ssh/#after-restart). Ein Account, der sich nur mit einem Passwort anmelden kann, funktioniert nicht. |
| :ui[remoteError.unknownHostKey] | Ihr Mac kennt den Server noch nicht. Verbinden Sie sich einmal im Terminal und prüfen Sie den Fingerabdruck, wie unter [Einmal verbinden](/guide/server/prepare-ssh/#fingerprint). Spooky akzeptiert nie einen Fingerabdruck für Sie. |
| :ui[remoteError.changedHostKey] | Verbinden Sie sich noch nicht. Klären Sie die Änderung zuerst mit dem Eigentümer des Servers. |
| :ui[remoteError.unavailable] | Prüfen Sie den Host-Alias und Ihr Netzwerk. Spooky versucht es 5 Sekunden nach jedem fehlgeschlagenen Versuch erneut. Um es sofort zu versuchen, klicken Sie im Streifen auf :ui[action.reconnect]. Siehe [Verbindungsabbrüche und erneutes Verbinden](/guide/server/connection/#reconnect). |
| :ui[remoteError.deployment] | Dem Server fehlt etwas, das Spooky braucht: die Weiterleitung von Unix-Sockets, `/usr/bin/perl` oder Schreibzugriff auf `~/.spooky/bin` und `/tmp`. Siehe [Server](/reference/requirements/#servers). |

Wenn Git auf dem Server fehlt oder zu alt ist, lesen Sie weiter.

## Git ist zu alt {#git-version}

Spooky braucht Git 2.41.0 oder neuer, auf Ihrem Mac und auf Servern.

### Auf Ihrem Mac {#mac-git}

Wenn Sie ein lokales Repository öffnen, zeigt Spooky möglicherweise eine dieser Meldungen:

- :ui[error.version], darunter die Ausgabe von Git. Das Git-Programm, das Spooky verwendet, ist älter als 2.41.0. Wählen Sie unter :ui[app.name > settings.title] › :ui[settings.gitConfig] neben :ui[settings.gitProgram] ein neueres, oder aktualisieren Sie Xcode oder die Command Line Tools.
- :ui[error.gitProgram], darunter der Pfad. Das gewählte Git-Programm ist nicht mehr vorhanden, etwa weil Sie es deinstalliert haben. Wählen Sie an derselben Stelle ein anderes.

Das Menü führt nur Git-Programme auf, die neu genug sind. Siehe [Git-Programm](/guide/settings/identity/#git-program).

### Auf einem Server {#server-git}

Die Verbindung schlägt mit :ui[remoteError.gitVersion] fehl. Aktualisieren Sie Git auf dem Server auf 2.41.0 oder neuer.

Wenn dort bereits ein neueres Git installiert ist, finden SSH-Anmeldungen zuerst ein älteres. Setzen Sie den Ordner des neueren Git im `PATH` vor die anderen, wie unter [Git wird auf dem Server nicht gefunden](#server-path).

## Git wird auf dem Server nicht gefunden {#server-path}

Die Verbindung schlägt mit :ui[remoteError.gitUnavailable] fehl. Oder der Server zeigt :ui[settings.environment.server.noGit], wenn Sie ihn unter :ui[app.name > settings.title] › :ui[settings.environment] prüfen.

Wenn Git auf dem Server nicht installiert ist, installieren Sie Git 2.41.0 oder neuer. Wenn doch, liegt es meist am `PATH`. Spooky führt Befehle auf dem Server über SSH aus, ohne interaktive Shell. Diese Shell liest weniger Startdateien. Ein `PATH`, den Sie in `~/.zshrc` oder `~/.bash_profile` gesetzt haben, gilt dann möglicherweise nicht.

So beheben Sie das:

1. Melden Sie sich im Terminal am Server an und führen Sie `command -v git` aus. Der Befehl gibt aus, wo Git liegt, etwa `/opt/homebrew/bin/git`.
2. Vergleichen Sie das mit dem `PATH`, den Spooky erhält. Die Ausgabe des Fehlers führt ihn auf, ebenso die Prüfung unter [Einen Server prüfen](/guide/settings/general/#server-check).
3. Fügen Sie den Ordner von Git in einer Startdatei zum `PATH` hinzu, die nicht interaktive Shells lesen. Führen Sie auf dem Server `echo $SHELL` aus, um zu sehen, welche Shell Sie verwenden.
   - zsh: `~/.zshenv`
   - bash: `~/.bashrc`, oberhalb jeder Zeile, die vorzeitig abbricht, wenn die Shell nicht interaktiv ist

   Zum Beispiel:

   ```sh
   export PATH="/opt/homebrew/bin:$PATH"
   ```

4. Klicken Sie erneut auf :ui[settings.environment.server.check] oder führen Sie den Test aus [Keine Verbindung zu einem Server](#connect) aus. Verbinden Sie sich dann erneut.

Git LFS und die Programme, die Ihre Hooks ausführen, werden über denselben `PATH` gefunden. Wenn sie im Terminal funktionieren, aber nicht aus Spooky, etwa wenn ein Befehl mit :ui[hostError.lfsUnavailable] fehlschlägt, fügen Sie ihre Ordner auf dieselbe Weise hinzu.

## Probleme mit Zugriffsrechten {#permissions}

| Was Sie sehen | Warum, und was zu tun ist |
|---|---|
| :ui[remoteError.pathPermission] | Ihr Benutzer auf dem Server kann den Repository-Ordner nicht öffnen oder lesen. Bitten Sie den Eigentümer des Servers um Zugriff oder wählen Sie einen Ordner, der Ihnen gehört. |
| :ui[remoteError.diskAccess] | Der Server ist ein Mac, und das Repository liegt in einem Ordner, den macOS schützt, etwa „Dokumente“. Aktivieren Sie den Festplattenvollzugriff für entfernte Benutzer, wie unter [Einen Mac als Server verwenden](/guide/server/prepare-ssh/#mac-server), oder verschieben Sie das Repository. |
| :ui[error.ownership] | Der Repository-Ordner auf diesem Mac gehört einem anderen Benutzer. Git weigert sich, darin zu arbeiten. Machen Sie sich selbst zum Eigentümer des Ordners. Wenn Sie seinem Eigentümer vertrauen, können Sie stattdessen den Befehl `git config --global --add safe.directory` ausführen, den die Ausgabe von Git vorschlägt. |
| :ui[error.terminal] | Die Details unter dem Titel sagen, was schiefgegangen ist. Oft ist die neben :ui[settings.terminal] gewählte Terminal-App nicht mehr installiert, oder Sie haben Spooky nicht erlaubt, Terminal oder iTerm zu steuern. Siehe [Terminal](/guide/settings/integration/#terminal). |
| :ui[appIcon.writeFailed] | Spooky sichert das Symbol in `Spooky.app`. Ihr Benutzer muss dort schreiben können. Wählen Sie Spooky im Finder aus, wählen Sie **Ablage › Informationen** und prüfen Sie, ob Sie unter **Freigabe & Zugriffsrechte** die Berechtigung **Lesen & Schreiben** haben. |

:::note[Server-Repositorys]
Auf einem Server schlägt ein Ordner, der einem anderen Benutzer gehört, mit :ui[remoteError.notWorkingTree] fehl, und die Ausgabe von Git erwähnt die Eigentümerschaft. Fragen Sie den Eigentümer des Servers oder führen Sie den Befehl `safe.directory` auf dem Server aus.
:::

## Ein Problem melden {#report}

Wählen Sie :ui[menu.help > help.support], um die Issues von Spooky auf GitHub zu öffnen. Suchen Sie dort nach Ihrem Problem oder eröffnen Sie ein neues Issue. Beschreiben Sie, was Sie getan haben, was Sie erwartet haben und was passiert ist. Wenn Spooky einen Fehler gezeigt hat, geben Sie dessen Titel und die Originalausgabe an.

Ein Diagnosebericht hilft zu zeigen, was passiert ist. Wählen Sie :ui[menu.help > help.diagnosticReport] und wählen Sie, wo er gesichert wird. Spooky sichert eine Textdatei und zeigt sie im Finder. Es sendet den Bericht nirgendwohin. Öffnen Sie die Datei und lesen Sie sie, bevor Sie sie weitergeben. Was er enthält, lesen Sie unter [Diagnoseberichte](/reference/data-privacy/#diagnostic-reports).

Wenn Spooky beim letzten Mal unerwartet beendet wurde, fragt es beim nächsten Start: :ui[crash.title]. Wenn Sie auf :ui[crash.report] klicken, öffnet sich in Ihrem Browser eine Seite für ein neues Issue auf GitHub, mit einer Zusammenfassung des Absturzes ausgefüllt. Das Issue wird erst erstellt, wenn Sie es im Browser absenden. Siehe [Absturzberichte](/reference/data-privacy/#crash-reports).

## Siehe auch

- [SSH vorbereiten](/guide/server/prepare-ssh/)
- [Verbindungsstatus und erneutes Verbinden](/guide/server/connection/)
- [Systemanforderungen](/reference/requirements/)
- [Daten und Datenschutz](/reference/data-privacy/)
