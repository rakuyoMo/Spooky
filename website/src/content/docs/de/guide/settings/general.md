---
title: "Allgemein, Updates und Umgebung"
description: "Finden Sie sich im Einstellungsfenster zurecht und legen Sie die Optionen auf den Seiten „Allgemein“, „Updates“ und „Umgebung“ fest."
---

Einstellungen gelten für Spooky als Ganzes. Die meisten wirken, sobald Sie sie ändern. Eine Sichern-Taste gibt es nicht.

## Das Einstellungsfenster {#window}

Wählen Sie :ui[app.name > settings.title] (<kbd>⌘,</kbd>). Die Seiten stehen oben im Fenster, und der Titel zeigt die Seite, auf der Sie sich befinden.

| Seite | Was sie festlegt | Beschrieben unter |
|---|---|---|
| :ui[settings.general] | Klonen, Vorgänge im Hintergrund, Bestätigungen, Verlauf, die Dateiliste und Fenster | [Allgemein](#general) |
| :ui[settings.appearance] | Hell oder dunkel und das App-Symbol | [Erscheinungsbild und Themen](/guide/settings/appearance/#appearance) |
| :ui[settings.gitConfig] | Das Git-Programm, Ihre globale Git-Identität, das Signieren sowie externe Vergleichs- und Zusammenführungswerkzeuge | [Benutzerprofile und Git-Konfiguration](/guide/settings/identity/#git-config) |
| :ui[settings.text] | Syntaxhervorhebung, unsichtbare Zeichen und Tabulatorbreite in Diffs und Dateien | [Erscheinungsbild und Themen](/guide/settings/appearance/#text) |
| :ui[settings.editor] | Wie die Commit-Nachricht geprüft und umbrochen wird | [Erscheinungsbild und Themen](/guide/settings/appearance/#editor) |
| :ui[settings.themes] | Farben und Schrift für Diffs und Dateien | [Erscheinungsbild und Themen](/guide/settings/appearance/#themes) |
| :ui[settings.profiles] | Identitäten, zwischen denen Sie beim Committen wechseln können | [Benutzerprofile und Git-Konfiguration](/guide/settings/identity/#profiles) |
| :ui[settings.accounts] | GitHub- und GitLab-Accounts | [Hosting-Accounts](/guide/hosting/accounts/) |
| :ui[settings.sshHosts] | Host-Aliasse für Ihre Server, gesichert in `~/.ssh/config` | [SSH vorbereiten](/guide/server/prepare-ssh/#alias) |
| :ui[settings.integration] | Links von github.com, der SSH-Agent und Absturzberichte | [Integration](/guide/settings/integration/#integration-page) |
| :ui[settings.environment] | Umgebungsvariablen für Git auf diesem Mac und eine Prüfung der Umgebung eines Servers | [Umgebung](#environment) |
| :ui[settings.updates] | Wie Spooky sich aktualisiert | [Updates](#updates) |

Einstellungen für ein einzelnes Repository, etwa dessen Identität und das Signieren, stehen stattdessen im Repository-Fenster. Siehe [Repository-Einstellungen](/guide/settings/identity/#repository).

## Allgemein {#general}

Die Seite :ui[settings.general] ist eine lange Liste. Die Abschnitte unten folgen ihr von oben nach unten.

::screenshot[Die Seite „Allgemein“ des Einstellungsfensters mit dem Ordner für Klone, der Terminal-App, den Optionen für Vorgänge und Bestätigungen, den Optionen für Verlauf und Diffs und den Optionen für die Dateiliste.]{name="settings-general" frame="window"}

### Klonen und Terminal {#cloning}

| Einstellung | Wirkung |
|---|---|
| :ui[settings.cloneDirectory] | Wo das Dialogfenster zum Klonen neue Repositorys vorschlägt. Anfangs ist es Ihr Benutzerordner. Das Menü führt auch `~/Development` auf, falls Sie einen solchen Ordner haben. Wählen Sie :ui[settings.cloneDirectory.select], um einen anderen Ordner zu wählen. |
| :ui[settings.terminal] | Die App, die :ui[action.openTerminal] verwendet. Siehe [Terminal](/guide/settings/integration/#terminal). |

### Vorgänge {#operations}

| Einstellung | Standard | Wirkung |
|---|---|---|
| :ui[settings.autoFetch] | Alle 30 Minuten | Wie oft Spooky im Hintergrund abruft. Siehe [Automatisch abrufen](/guide/branches/sync/#auto-fetch). |
| :ui[stash.offerAutoStash] | Ein | Fragt, wenn lokale Änderungen einen Vorgang blockieren, ob sie zuerst gestasht werden sollen. Siehe [Automatisches Stashen](/guide/work/stash/#auto-stash). |
| :ui[settings.autoUpdateSubmodules] | Aus | Aktualisiert ausgecheckte Submodule ohne Nachfrage nach Vorgängen, die ihre Zeiger bewegen. Siehe [Nach anderen Vorgängen aktualisieren](/guide/advanced/submodules/#auto-update). |
| :ui[branch.cleanNames] | Ein | Korrigiert die Namen von Branches, Tags und Remotes beim Tippen für Git. Siehe [Einen Branch erstellen](/guide/branches/branches/#create). |
| :ui[settings.autoArchive] | Aus | Archiviert Branches, die fertig aussehen. Siehe [Automatisch archivieren](/guide/branches/review/#auto-archive). |

### Bestätigungen {#confirmations}

Jede dieser Fragen hat die Option :ui[dialog.doNotAskAgain]. Wenn Sie sie dort aktivieren, wird die passende Einstellung hier ausgeschaltet. Schalten Sie die Einstellung wieder ein, um die Frage erneut zu erhalten. Alle vier sind anfangs eingeschaltet.

| Einstellung | Fragt vor |
|---|---|
| :ui[settings.warnDiscardingChunks] | Dem Verwerfen von Blöcken oder Zeilen, in jedem Repository. Siehe [Änderungen verwerfen](/guide/work/diff/#discard). |
| :ui[settings.warnDiscardingOnServer] | Dem Verwerfen ganzer Dateien in einem Server-Repository |
| :ui[settings.warnDeletingOnServer] | Dem endgültigen Löschen von Dateien auf einem Server ohne Papierkorb |
| :ui[settings.warnRestoringOnServer] | Dem Wiederherstellen von Dateien aus einer Revision in einem Server-Repository. Siehe [Eine Datei aus einer Revision wiederherstellen](/guide/history/file-views/#restore). |

In einem lokalen Repository wird vor dem Verwerfen ganzer Dateien immer gefragt.

### Verlauf und Diffs {#history}

| Einstellung | Standard | Wirkung |
|---|---|---|
| :ui[history.pageSize] | 100 | Wie viele Commits der Verlauf auf einmal lädt: 100, 200, 500 oder 1.000 |
| :ui[settings.dateFormat] | Absolut | Absolute Datumsangaben sind kurz, wie 26.10.26. Relative Angaben lauten für diese beiden Tage „Heute“ oder „Gestern“ und schreiben andere Daten aus. Das Menü zeigt für beide ein Beispiel. |
| :ui[history.mergeDiff] | :ui[history.mergeDiff.firstParent] | Was der Änderungssatz eines Merge-Commits zeigt. Siehe [Der Änderungssatz](/guide/history/commit-details/#changeset). |
| :ui[working.diffThreshold] | 20.000 | Bei Diffs, die größer als so viele Kilobyte sind, wird gefragt, bevor sie angezeigt werden. Wählen Sie einen Wert oder geben Sie einen ein. Siehe [Einen Diff lesen](/guide/work/diff/#read). |

Das Datumsformat gilt für den Verlauf, die Stashes, den Dateiverlauf und das Reflog.

### Dateiliste {#file-list}

| Einstellung | Standard | Wirkung |
|---|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] | Oder die Datei in Ihrem Vergleichswerkzeug öffnen |
| :ui[files.openSubmodules] | Ein | Ein Doppelklick auf ein Submodul öffnet es in Spooky statt in einer anderen App |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] | Oder die Datei in der Übersicht zeigen |
| :ui[files.fontSize] | :ui[files.fontSize.medium] | Oder :ui[files.fontSize.regular] |
| :ui[files.truncation] | :ui[files.truncation.beginning] | Oder lange Namen in der Mitte kürzen |

Wie diese in der Arbeitskopie wirken, lesen Sie unter [Einstellungen für die Dateiliste](/guide/work/working-copy/#settings).

### Fenster und die Repository-Liste {#windows}

| Einstellung | Standard | Wirkung |
|---|---|---|
| :ui[settings.windowRestoration] | :ui[settings.windowRestoration.system] | Was Spooky beim Start wieder öffnet. Siehe [Dort weitermachen, wo Sie aufgehört haben](/guide/repositories/navigation/#restore). |
| :ui[settings.showLaunchWindow] | Aus | Zeigt beim Start von Spooky ein Fenster mit Ihren zuletzt verwendeten Repositorys |
| :ui[settings.showWorktreesInRepositoryList] | Aus | Führt in der Repository-Liste die Worktrees jedes Repositorys auf |
| :ui[settings.showHostAliasesInRepositoryList] | Ein | Zeigt in der Repository-Liste den Host-Alias jedes Server-Repositorys |
| :ui[settings.showDeveloperMenu] | Aus | Fügt das Menü :ui[menu.developer] hinzu, mit Werkzeugen zum Testen von Spooky selbst |

## Updates {#updates}

Die Seite :ui[settings.updates] legt den Update-Kanal fest, ob Spooky von selbst nach Updates sucht und sie lädt und wie oft es sucht. [Spooky aktuell halten](/guide/start/install/#updates) erklärt jede Option.

## Umgebung {#environment}

Apps, die aus dem Finder oder dem Dock geöffnet werden, erhalten nicht die Umgebung, die Sie im Terminal haben. In `PATH` können zum Beispiel Ordner wie `/opt/homebrew/bin` fehlen. Git-Hooks, Credential-Helper und Git LFS werden dann möglicherweise nicht gefunden. Die Seite :ui[settings.environment] behebt das für Git auf diesem Mac.

### Variablen auf diesem Mac {#local-variables}

| Einstellung | Wirkung |
|---|---|
| :ui[settings.environment.loginShell] | Startet Ihre Login-Shell einmal, liest die Variablen, die ihre Startdateien setzen, und gibt sie an Git und die Skripte der Symbolleistentasten weiter. Die Tabelle darunter führt auf, was gelesen wurde. Anfangs eingeschaltet. |
| :ui[settings.environment.custom] | Variablen, die Sie selbst hinzufügen. Klicken Sie auf die Hinzufügen-Taste, um eine hinzuzufügen, und auf die Entfernen-Taste, um die ausgewählte zu entfernen. Sie haben Vorrang vor denen der Login-Shell. |

Einige Dinge, die Sie wissen sollten:

- Änderungen gelten ab dem nächsten Git-Befehl. Sie müssen Spooky nicht neu starten.
- Die Login-Shell wird bei jedem Start von Spooky neu gelesen. Wenn das Lesen fehlschlägt, steht es auf der Seite.
- Wenn zwei eigene Variablen denselben Namen haben, gewinnt die untere. Eine Variable mit einem ungültigen Namen bleibt in der Tabelle, wird aber nicht an Git weitergegeben.
- Um einen anderen SSH-Agent als den des Systems zu verwenden, setzen Sie `SSH_AUTH_SOCK` hier oder in Ihrer Login-Shell. Siehe [SSH-Agent](/guide/settings/integration/#ssh-agent).

:::note[Server-Repositorys]
Diese Variablen gelten nur für Git und die Skripte der Symbolleistentasten auf diesem Mac. Git auf einem Server verwendet die eigene Umgebung des Servers.
:::

### Einen Server prüfen {#server-check}

Unten auf der Seite sehen Sie die Umgebung, die Git auf einem Server erhält, ohne ein Repository hinzuzufügen:

1. Geben Sie einen Host-Alias in das Feld :ui[remote.host] ein. Sie können auch einen aus dem Menü :ui[settings.environment.server.hosts] wählen. Es führt die Server Ihrer Server-Repositorys auf.
2. Klicken Sie auf :ui[settings.environment.server.check].

::screenshot[Die Serverprüfung unten auf der Seite „Umgebung“ in den Einstellungen. Ein Host-Alias wurde geprüft, und das Ergebnis zeigt das auf dem Server gefundene Git mit seiner Version.]{name="settings-environment" frame="closeup"}

Das Ergebnis zeigt das Git, das SSH-Anmeldungen finden, und dessen Version oder :ui[settings.environment.server.noGit]. Darunter führt es jeden Ordner in `PATH` und die Namen aller Variablen auf, die mit `GIT_` beginnen. Wenn Git nicht gefunden wird, lesen Sie [Git wird auf dem Server nicht gefunden](/reference/troubleshooting/#server-path).

## Siehe auch

- [Erscheinungsbild und Themen](/guide/settings/appearance/)
- [Benutzerprofile und Git-Konfiguration](/guide/settings/identity/)
- [Integration](/guide/settings/integration/)
- [Spooky installieren](/guide/start/install/)
