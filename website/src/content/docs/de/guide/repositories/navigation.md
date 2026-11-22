---
title: "Fenster und Navigation"
description: "Mit Fenstern und Tabs arbeiten, vor und zurück gehen, Schnellaktionen verwenden, Fenster wiederherstellen, das Dock-Menü nutzen und spooky://-Links öffnen."
---

Auf dieser Seite geht es darum, wie Sie sich zurechtfinden. Sie sehen, wie Sie mehrere Repositorys geöffnet halten, zwischen Ansichten wechseln, mit den Schnellaktionen überallhin springen und dorthin zurückkehren, wo Sie aufgehört haben.

## Fenster und Tabs {#windows}

Jedes Fenster und jeder Tab zeigt entweder die Ansicht „Repositorys“ oder ein Repository.

- :ui[menu.file > menu.newTab] (<kbd>⌘T</kbd>) öffnet einen neuen Tab mit der Ansicht „Repositorys“. Die Hinzufügen-Taste am Ende der Tableiste tut dasselbe.
- :ui[menu.file > menu.newWindow] (<kbd>⌘N</kbd>) öffnet ein neues Fenster mit der Ansicht „Repositorys“.
- :ui[menu.view > menu.showRepositories] (<kbd>⌃⌘R</kbd>) zeigt die Ansicht „Repositorys“ im aktuellen Fenster.

Wenn ein Repository bereits geöffnet ist, wechselt erneutes Öffnen zu dem Fenster, das es zeigt. Um es trotzdem in einem zweiten Fenster zu öffnen, klicken Sie in der Repository-Liste mit der rechten Maustaste darauf und wählen Sie :ui[bookmarks.openNewWindow]{1="driftwood"}.

### Ansichten wechseln {#views}

Das Menü :ui[menu.view] wechselt zwischen den Ansichten des Repositorys:

| Kurzbefehl | Menüeintrag |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[stash.show] |
| <kbd>⌘4</kbd> | :ui[pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[review.show] |
| <kbd>⌘6</kbd> | :ui[reflog.show] |
| <kbd>⌘0</kbd> | :ui[history.showHead] |

:ui[menu.window > activity.title] (<kbd>⌃⌘0</kbd>) öffnet das Fenster „Aktivität“. Es führt auf, was Spooky ausgeführt hat und gerade ausführt. Siehe [Warteschlange und Aktivität](/guide/advanced/queue-activity/).

## Vor und zurück gehen {#back-forward}

Jedes Fenster merkt sich die Ansichten und Repositorys, die Sie besucht haben, einschließlich der Ansicht „Repositorys“. So gehen Sie Ihre Schritte zurück:

- :ui[menu.view > navigation.back] (<kbd>⌘[</kbd>) oder :ui[toolbar.previous] in der Symbolleiste
- :ui[menu.view > navigation.forward] (<kbd>⌘]</kbd>) oder :ui[toolbar.next] in der Symbolleiste

Wenn Sie zurückgehen und dann etwas Neues öffnen, entfallen die Orte, zu denen Sie hätten vorgehen können.

## Schnellaktionen {#quick-actions}

Mit den Schnellaktionen finden Sie etwas durch Tippen und bearbeiten es, ohne die Tastatur zu verlassen. Sie sind verfügbar, solange ein Repository angezeigt wird. Wählen Sie :ui[menu.file > quickActions.menu] (<kbd>⇧⌘A</kbd>) oder klicken Sie in der Symbolleiste auf :ui[toolbar.quickActions].

::screenshot[Die Schnellaktionen über einem Repository-Fenster, eingegeben ist „dark“. Das erste Ergebnis, der Branch feature/dark-mode, ist ausgewählt und zeigt seine Standardaktion und den Hinweis auf weitere Aktionen. Darunter stehen der Remote-Branch origin/feature/dark-mode, das dunkle Erscheinungsbild, das Thema Default (Dark) und zwei Commits, deren Nachrichten dark erwähnen.]{name="quick-actions" frame="window"}

Ohne Eingabe führt das Panel die Ansichten des Repositorys auf, dann Branches (den aktuellen zuerst), Worktrees, Remotes, Submodule, Remote-Branches, Tags, Stashes, Benutzerprofile sowie Erscheinungsbilder und Themen. Beim Tippen wird die Liste kürzer. Spooky sucht außerdem nach:

- Dateien im aktuellen Branch, deren Namen passen
- einem Commit, wenn Sie 5 bis 64 hexadezimale Zeichen seines Hashs eingeben
- Commits im aktuellen Branch, deren Nachrichten den Text enthalten, höchstens 100

Dateien und Commits erscheinen am Ende der Liste, kurz nachdem Sie aufgehört haben zu tippen.

Verwenden Sie im Panel diese Tasten:

| Taste | Wirkung |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Die Auswahl bewegen |
| <kbd>↩</kbd> | Die Standardaktion des ausgewählten Objekts ausführen |
| <kbd>Tab</kbd> oder <kbd>→</kbd> am Ende des Texts | Alle Aktionen für das ausgewählte Objekt auflisten |
| <kbd>←</kbd> ohne Text oder <kbd>⇧Tab</kbd> | Aus der Liste der Aktionen zurückgehen |
| <kbd>Esc</kbd> | Den Text löschen; ohne Text aus der Liste der Aktionen zurückgehen oder das Panel schließen |

Es werden nur Aktionen aufgeführt, die Sie gerade ausführen können.

## Dort weitermachen, wo Sie aufgehört haben {#restore}

:ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.windowRestoration] legt fest, was Spooky beim Start zeigt:

| Auswahl | Beim Start von Spooky |
|---|---|
| :ui[settings.windowRestoration.always] | Öffnet Ihre Fenster und Tabs wieder, jeweils mit dem Repository und der Ansicht, die beim Beenden gezeigt wurden |
| :ui[settings.windowRestoration.never] | Zeigt nur das Fenster „Repositorys“ |
| :ui[settings.windowRestoration.system] | Folgt der macOS-Einstellung zum Beibehalten von Fenstern beim Beenden einer App. Das ist der Standard. |

Wenn ein wiederhergestelltes Repository nicht mehr zu finden ist, zeigt sein Fenster, dass es fehlt. Siehe [Fehlende Repositorys](/guide/repositories/manager/#missing).

Schalten Sie :ui[settings.showLaunchWindow] ein, um beim Start ein Fenster mit Ihren zuletzt verwendeten Repositorys zu erhalten. Doppelklicken Sie auf eines oder wählen Sie es aus und drücken Sie <kbd>↩</kbd>, um es zu öffnen. Das Fenster schließt sich von selbst, sobald ein Repository-Fenster nach vorne kommt. Beide Einstellungen sind unter [Fenster und die Repository-Liste](/guide/settings/general/#windows) beschrieben.

:::note[Server-Repositorys]
Wiederhergestellte Server-Repositorys verbinden sich beim Start von Spooky wieder mit ihren Servern.
:::

## Zuletzt verwendete Repositorys und das Dock {#recent}

:ui[menu.file > menu.openRecent] führt die Repositorys auf, die Sie zuletzt geöffnet haben, auf Ihrem Mac und auf Servern. :ui[menu.clearRecent] ganz unten leert die Liste. Ihre Lesezeichen im Fenster „Repositorys“ bleiben.

Klicken Sie im **Dock** mit der rechten Maustaste auf das Symbol von Spooky, um ein Menü mit :ui[menu.newWindow] und Ihren zuletzt verwendeten Repositorys zu erhalten. Wählen Sie ein Repository, um es zu öffnen. Das funktioniert auch, wenn Spooky noch nicht läuft.

Sie können auch einen Ordner auf das Symbol von Spooky im Dock ziehen, um das Repository zu öffnen, in dem er liegt. Wenn der Ordner in keinem Git-Repository liegt, bietet Spooky an, eines zu erstellen.

## Spooky über einen Link öffnen {#links}

Ein Link, der mit `spooky://` beginnt, öffnet ein Repository oder einen Klon. Sie können solche Links in anderen Apps, Skripten oder Notizen ablegen.

### Ein Repository öffnen {#link-open}

```
spooky://open?repository=<repository>&view=<view>
```

- `repository` ist erforderlich. Es ist der absolute Pfad des Repositorys auf Ihrem Mac oder `alias:path` für ein Server-Repository, URL-codiert.
- `view` ist optional. Ohne diese Angabe öffnet sich das Repository in der Ansicht, die es zuletzt gezeigt hat.
- Zwei Kurzformen ersetzen `view`: `branch=<name>` öffnet den Verlauf dieses Branches, und `commit=<hash>` öffnet diesen Commit.

| `view` | Öffnet | Zusätzliche Parameter |
|---|---|---|
| `workingCopy` | Die Arbeitskopie | |
| `history` | Den Verlauf | `ref=<reference>`, ein vollständiger Referenzname wie `refs/heads/main`; kann wiederholt werden |
| `commit` | Einen Commit | `commit=<hash>` |
| `stashes` | Die Stashes | |
| `reflog` | Das Reflog | |
| `pullRequests` | Pull Requests oder Merge Requests | |
| `branchesReview` | Die Branch-Übersicht | |
| `settings` | Die Repository-Einstellungen | |
| `remote` | Ein Remote | `remote=<name>` |
| `submodule` | Ein Submodul | `path=<path>` |
| `worktree` | Einen Worktree | `path=<path>` |
| `fileHistory` | Den Verlauf einer Datei | `path=<path>` |
| `file` | Eine Datei | `path=<path>` und optional `revision=<revision>` sowie `mode=blame` oder `mode=raw` |

Dieser Link öffnet zum Beispiel den Verlauf des Branches `main` im Repository unter `/Volumes/Projects/driftwood`:

```
spooky://open?repository=%2FVolumes%2FProjects%2Fdriftwood&branch=main
```

### Ein Repository klonen {#link-clone}

```
spooky://clone?url=<address>
```

Das öffnet das Dialogfenster zum Klonen mit eingetragener Adresse. Geklont wird erst, wenn Sie den Zielort wählen und auf :ui[clone.submit] klicken. Siehe [Ein Repository klonen](/guide/repositories/manager/#clone).

Stellen Sie :ui[app.name > settings.title] › :ui[settings.integration] › :ui[settings.github] auf Spooky, und die Links auf github.com, die ein Repository in einer Desktop-App öffnen, öffnen ebenfalls dieses Dialogfenster zum Klonen. Siehe [Links von github.com](/guide/settings/integration/#github-links).

Manche Links lassen sich nicht verwenden, etwa einer, der eine unbekannte Ansicht nennt oder einen relativen Pfad angibt. Bei ihnen zeigt Spooky :ui[link.invalid.title] und tut sonst nichts.

## Siehe auch

- [Spooky im Überblick](/guide/start/tour/)
- [Das Fenster „Repositorys“](/guide/repositories/manager/)
- [Tastaturkurzbefehle](/reference/shortcuts/)
