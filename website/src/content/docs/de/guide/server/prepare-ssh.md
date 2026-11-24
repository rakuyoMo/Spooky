---
title: "SSH vorbereiten"
description: "Richten Sie einen SSH-Schlüssel und einen Host-Alias in ~/.ssh/config ein und stellen Sie sicher, dass die Verbindung im Terminal klappt, bevor Sie ein Server-Repository hinzufügen."
---

Spooky meldet sich per SSH an einem Server an, genauso wie das Terminal. Es kann kein Passwort für Sie eingeben und braucht deshalb einen SSH-Schlüssel. Diese Seite richtet einen Schlüssel und einen kurzen Namen für den Server ein und prüft dann, ob sich das Terminal ohne Rückfragen verbindet. Sobald das klappt, kann sich auch Spooky verbinden.

Wenn `ssh` Sie bereits ohne Passwort am Server anmeldet, springen Sie zu [Testen, wie Spooky sich verbindet](#test).

## Was Sie brauchen {#before}

- Einen Account auf dem Server, an dem Sie sich per SSH anmelden können. Fragen Sie den Betreiber des Servers, wenn Sie unsicher sind.
- Git 2.41.0 oder neuer auf dem Server.
- Die App **Terminal** auf Ihrem Mac.

Die Befehle auf dieser Seite gehören ins Terminal. Tippen Sie jeden ein oder setzen Sie ihn ein und drücken Sie dann den Zeilenschalter.

## Nach einem Schlüssel suchen {#key-check}

Ein SSH-Schlüssel ist ein Paar von Dateien. Der private Schlüssel bleibt auf Ihrem Mac. Der öffentliche Schlüssel endet auf `.pub` und kommt auf den Server.

```sh
ls ~/.ssh
```

Wenn die Liste `id_ed25519` und `id_ed25519.pub` enthält, haben Sie bereits einen Schlüssel. Springen Sie zu [Einen Host-Alias hinzufügen](#alias). Ein anderes Paar, etwa `id_rsa` und `id_rsa.pub`, funktioniert auch. Verwenden Sie in den Schritten unten dessen Namen anstelle von `id_ed25519`.

Wenn Sie „No such file or directory“ sehen oder kein Schlüsselpaar in der Liste steht, erstellen Sie eines.

## Einen Schlüssel erstellen {#create-key}

```sh
ssh-keygen -t ed25519 -C "alex@example.com"
```

Setzen Sie Ihre eigene E-Mail-Adresse in die Anführungszeichen. Sie ist nur eine Bezeichnung, an der Sie den Schlüssel wiedererkennen.

1. Wenn Sie gefragt werden, wo der Schlüssel gesichert werden soll, drücken Sie den Zeilenschalter, um den vorgeschlagenen Ort zu übernehmen.
2. Geben Sie eine Passphrase ein und wiederholen Sie sie. Beim Tippen wird nichts angezeigt. Die Passphrase schützt den Schlüssel, falls jemand die Datei kopiert.

Danach enthält `~/.ssh` die Dateien `id_ed25519` und `id_ed25519.pub`.

## Einen Host-Alias hinzufügen {#alias}

Ein Host-Alias ist ein kurzer Name für einen Server. Sie geben ihn im Terminal und in Spooky ein, anstelle der Adresse des Servers und Ihres Benutzernamens. Aliasse werden in der Datei `~/.ssh/config` gesichert. Sie fügen sie in den Einstellungen von Spooky hinzu.

1. Wählen Sie :ui[app.name > settings.title] › :ui[settings.sshHosts].
2. Klicken Sie auf die Hinzufügen-Taste unter der Liste.
3. Füllen Sie die Felder mit Ihren eigenen Angaben aus.
4. Klicken Sie auf :ui[sshHosts.create.submit].

::screenshot[Das Dialogfenster zum Hinzufügen eines Host-Alias. Der Alias ist driftwood-server, die Serveradresse 203.0.113.10, der Benutzername alex, der Port ist leer, und der private Schlüssel ist ~/.ssh/id_ed25519. Die Tasten dienen zum Abbrechen und zum Hinzufügen.]{name="settings-ssh-hosts-add" frame="dialog"}

| Feld | Was dort stehen soll |
|---|---|
| :ui[sshHosts.alias] | Der Alias. Verwenden Sie ein Wort ohne Leerzeichen, `@`, `:`, `/`, `*` oder `?` und beginnen Sie es nicht mit `-` oder `!`. |
| :ui[sshHosts.hostName] | Die Adresse oder der Name des Servers, etwa `203.0.113.10` oder `server.example.com` |
| :ui[sshHosts.user] | Ihr Benutzername auf dem Server |
| :ui[sshHosts.port] | Der Port, falls SSH auf dem Server einen anderen als 22 verwendet |
| :ui[sshHosts.identityFile] | Der private Schlüssel, den Sie oben erstellt oder gefunden haben, etwa `~/.ssh/id_ed25519` |

Nur :ui[sshHosts.alias] ist erforderlich. Spooky schreibt den Alias und die ausgefüllten Felder in `~/.ssh/config`:

```
Host driftwood-server
    HostName 203.0.113.10
    User alex
    IdentityFile ~/.ssh/id_ed25519
```

Enthält die Datei einen Eintrag mit einem Muster, etwa `Host *`, oder einen `Match`-Eintrag, kommen die neuen Zeilen über den ersten davon. So kann dieser Eintrag sie nicht überschreiben. Andernfalls kommen sie ans Ende der Datei.

### Einen Alias ändern oder löschen {#manage-aliases}

Die Seite :ui[settings.sshHosts] listet die Aliasse in `~/.ssh/config` auf, auch solche, die Sie in einem Texteditor hinzugefügt haben.

::screenshot[Die Seite „SSH-Hosts“ des Einstellungsfensters. Die Liste hat die Spalten Alias, Serveradresse, Benutzername, Port und Privater Schlüssel. Sie zeigt drei Aliasse: staging, backup-nas und driftwood-server, der ausgewählt ist. Unter der Liste befinden sich die Tasten zum Hinzufügen und Entfernen, rechts eine Taste zum Bearbeiten.]{name="settings-ssh-hosts" frame="window"}

- Um einen Alias zu ändern, doppelklicken Sie darauf, oder wählen Sie ihn aus und klicken Sie auf :ui[sshHosts.edit] oder drücken Sie den <kbd>Zeilenschalter</kbd>. Spooky ändert nur die Zeilen der Felder, die Sie bearbeiten. Die anderen SSH-Optionen des Servers, andere Server und Kommentare bleiben, wie sie sind.
- Um einen Alias zu löschen, wählen Sie ihn aus, klicken Sie auf die Entfernen-Taste unter der Liste und bestätigen Sie. Spooky löscht seine `Host`-Zeile und die Optionen darunter.

Ein Eintrag mit mehreren Namen oder mit einem Muster, etwa `Host *`, steht nicht in der Liste, und Spooky ändert ihn nicht. Bearbeiten Sie solche Einträge in einem Texteditor.

Spooky liest die Datei jedes Mal neu, wenn Sie zur App zurückkehren. Wenn eine andere App die Datei ändert, während ein Dialogfenster geöffnet ist, sichert Spooky Ihre Änderung nicht. Die Liste zeigt den aktuellen Inhalt der Datei, und Sie nehmen die Änderung erneut vor.

## Ihren Mac den Schlüssel entsperren lassen {#keychain}

Spooky fragt beim Anmelden nie nach der Passphrase Ihres Schlüssels, also muss Ihr Mac den Schlüssel dafür entsperren. Zwei Zeilen in `~/.ssh/config` richten das für alle Server ein. Überspringen Sie diesen Schritt, wenn Ihr Schlüssel keine Passphrase hat.

1. Öffnen Sie die Datei in TextEdit:

   ```sh
   open -e ~/.ssh/config
   ```

2. Fügen Sie am Ende diese Zeilen hinzu:

   ```
   Host *
       AddKeysToAgent yes
       UseKeychain yes
   ```

3. Sichern Sie die Datei und schließen Sie TextEdit.

Wenn Sie die Passphrase zum ersten Mal eingeben, sichert Ihr Mac sie im Schlüsselbund. Danach entsperrt SSH den Schlüssel ohne Rückfrage.

## Einmal verbinden {#fingerprint}

Wenn Sie sich zum ersten Mal mit einem Server verbinden, bittet SSH Sie, den Fingerabdruck des Servers zu bestätigen. Spooky akzeptiert nie einen Fingerabdruck für Sie, erledigen Sie das also zuerst im Terminal.

```sh
ssh driftwood-server
```

1. SSH zeigt den Fingerabdruck des Servers, eine Zeile, die mit `SHA256:` beginnt, und fragt, ob es fortfahren soll.
2. Vergleichen Sie ihn mit dem Fingerabdruck, den Ihnen der Betreiber des Servers nennt. Auf dem Server gibt dieser Befehl ihn aus:

   ```sh
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```

3. Wenn beide übereinstimmen, tippen Sie `yes` und drücken Sie den Zeilenschalter. Ihr Mac merkt sich den Server und fragt nicht noch einmal.

Was dann geschieht, hängt vom Server ab:

- Wenn SSH nach der Passphrase Ihres Schlüssels fragt, geben Sie sie ein. Ihr Mac sichert sie im Schlüsselbund.
- Wenn Sie angemeldet sind, liegt Ihr Schlüssel bereits auf dem Server. Tippen Sie `exit` und springen Sie zu [Testen, wie Spooky sich verbindet](#test).
- Wenn SSH nach Ihrem Passwort auf dem Server fragt, drücken Sie vorerst <kbd>⌃C</kbd>. Der nächste Schritt bringt Ihren Schlüssel auf den Server.

:::caution
Wenn SSH warnt, dass sich die Identifikation des entfernten Hosts geändert hat, fahren Sie nicht fort. Fragen Sie den Betreiber des Servers, ob der Server neu installiert oder ersetzt wurde.
:::

## Den öffentlichen Schlüssel auf den Server bringen {#copy-key}

Wenn Sie sich mit einem Passwort am Server anmelden können, kopiert dieser Befehl Ihren öffentlichen Schlüssel dorthin. Geben Sie Ihr Passwort auf dem Server ein, wenn Sie danach gefragt werden.

```sh
ssh-copy-id -i ~/.ssh/id_ed25519.pub driftwood-server
```

Wenn der Server keine Passwörter annimmt, senden Sie Ihren öffentlichen Schlüssel stattdessen an den Betreiber des Servers. Dieser Befehl kopiert ihn in die Zwischenablage:

```sh
pbcopy < ~/.ssh/id_ed25519.pub
```

Bitten Sie ihn, den Schlüssel zu `~/.ssh/authorized_keys` in Ihrem Benutzerordner auf dem Server hinzuzufügen. Den öffentlichen Schlüssel können Sie gefahrlos weitergeben. Senden Sie niemals die Datei ohne `.pub`.

## Testen, wie Spooky sich verbindet {#test}

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

Das meldet Sie genauso an, wie Spooky es tut, ohne nach etwas zu fragen. Es klappt, wenn sofort eine Version 2.41.0 oder neuer ausgegeben wird, etwa `git version 2.47.1`. Sie können jetzt [das Server-Repository hinzufügen](/guide/server/add/).

Wenn etwas anderes ausgegeben wird:

| Was Sie sehen | Was zu tun ist |
|---|---|
| `Permission denied` | Der Server akzeptiert Ihren Schlüssel noch nicht, oder Ihr Mac kann ihn nicht entsperren. Prüfen Sie [Ihren Mac den Schlüssel entsperren lassen](#keychain), [Den öffentlichen Schlüssel auf den Server bringen](#copy-key) und [Nach einem Neustart Ihres Mac](#after-restart). |
| `Host key verification failed` | Ihr Mac kennt den Server noch nicht. Siehe [Einmal verbinden](#fingerprint). |
| `Could not resolve hostname`, `Connection refused` oder `Operation timed out` | Prüfen Sie :ui[sshHosts.hostName] und :ui[sshHosts.port] des Alias unter :ui[app.name > settings.title] › :ui[settings.sshHosts] und stellen Sie sicher, dass der Server eingeschaltet und erreichbar ist. |
| Eine Meldung mit `command not found` | Git ist auf dem Server nicht installiert, oder SSH-Anmeldungen finden es nicht. Fragen Sie den Betreiber des Servers. |
| Eine ältere Version als 2.41.0 | Bitten Sie den Betreiber des Servers, Git zu aktualisieren. |

## Nach einem Neustart Ihres Mac {#after-restart}

Wenn der Test vorher geklappt hat, nach einem Neustart aber mit `Permission denied` fehlschlägt, laden Sie Ihren Schlüssel neu. Schlüssel, deren Passphrase im Schlüsselbund gesichert ist, laden Sie mit:

```sh
ssh-add --apple-load-keychain
```

## Einen anderen SSH-Agent verwenden {#agent}

Ein SSH-Agent hält entsperrte Schlüssel für SSH bereit. Spooky verwendet den Agent des Systems, den macOS für Sie startet. Wenn Ihre Schlüssel in einem anderen Agent liegen, etwa in dem eines Passwortmanagers, setzen Sie `SSH_AUTH_SOCK` auf den Socket dieses Agents. Fügen Sie die Variable als eigene Variable unter :ui[app.name > settings.title] › :ui[settings.environment] hinzu oder setzen Sie sie in Ihrer Login-Shell. Spooky verwendet dann diesen Agent, um sich an Servern anzumelden. Siehe [SSH-Agent](/guide/settings/integration/#ssh-agent).

## Einen Mac als Server verwenden {#mac-server}

Auch ein anderer Mac kann der Server sein. Auf diesem Mac:

1. Wählen Sie **Apple-Menü › Systemeinstellungen**, klicken Sie auf **Allgemein** und dann auf **Teilen**.
2. Schalten Sie **Entfernte Anmeldung** ein.
3. Wenn das Repository in einem geschützten Ordner liegt, etwa in „Dokumente“ oder „Schreibtisch“, klicken Sie auf die Infotaste neben **Entfernte Anmeldung** und schalten Sie **Festplattenvollzugriff für entfernte Benutzer:innen erlauben** ein.

Gehen Sie diese Seite dann von Ihrem eigenen Mac aus durch, mit der Adresse jenes Mac unter :ui[sshHosts.hostName].

## Siehe auch

- [So funktionieren Server-Repositorys](/guide/server/overview/)
- [Server-Repository hinzufügen](/guide/server/add/)
- [Systemanforderungen](/reference/requirements/#servers)
