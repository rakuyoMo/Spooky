---
title: "Integration"
description: "Wählen Sie externe Vergleichs- und Zusammenführungswerkzeuge, Editoren und Terminals und richten Sie die Finder-Integration ein."
---

Spooky arbeitet mit anderen Apps auf Ihrem Mac zusammen: Ihrem Browser, Vergleichs- und Zusammenführungswerkzeugen, Editoren, einem Terminal und dem Finder. Diese Seite zeigt, wo jede davon eingerichtet wird.

## Die Seite „Integration“ {#integration-page}

:ui[app.name > settings.title] › :ui[settings.integration] hat drei Einstellungen.

### Links von github.com {#github-links}

Auf github.com sendet die Taste, die ein Repository in einer Desktop-App öffnet, einen Link an Ihren Mac. :ui[settings.github] legt fest, welche App ihn erhält. Das Menü führt die Apps auf Ihrem Mac auf, die diese Links öffnen können.

Wählen Sie Spooky, und diese Links öffnen das Dialogfenster zum Klonen. Siehe [Ein Repository klonen](/guide/repositories/navigation/#link-clone).

### SSH-Agent {#ssh-agent}

Ein SSH-Agent hält entsperrte Schlüssel bereit. Spooky verwendet ihn, um sich per SSH an Servern und Remotes anzumelden und um Commits mit SSH-Schlüsseln zu signieren.

:ui[settings.sshAgent] hat eine Auswahl, :ui[settings.sshAgent.system]. Spooky sucht ihn in dieser Reihenfolge:

1. `SSH_AUTH_SOCK` unter Ihren eigenen Variablen auf der Seite :ui[settings.environment] (siehe [Variablen auf diesem Mac](/guide/settings/general/#local-variables))
2. `SSH_AUTH_SOCK` aus Ihrer Login-Shell, wenn das Lesen dort eingeschaltet ist
3. Der Agent, den macOS für Sie startet

Um einen anderen Agent zu verwenden, etwa den eines Passwortmanagers, setzen Sie `SSH_AUTH_SOCK` auf der Seite :ui[settings.environment] oder in Ihrer Login-Shell.

Wenn der Agent nicht läuft, erscheint neben dem Menü eine gelbe Warntaste. Klicken Sie darauf, um zu sehen, was zu tun ist.

:::note[Server-Repositorys]
Spooky leitet Ihren Agent niemals an einen Server weiter. Git auf dem Server verwendet den eigenen Agent und die eigenen Schlüssel jenes Rechners.
:::

### Absturzberichte {#crash-reports}

Wenn Spooky beim letzten Mal unerwartet beendet wurde, fragt es beim nächsten Start, ob der Absturz gemeldet werden soll. Aktivieren Sie :ui[settings.crashReports.always], um die Frage zu überspringen und die Issue-Seite sofort zu öffnen. Anfangs ist die Option ausgeschaltet.

Was der Bericht enthält, lesen Sie unter [Absturzberichte](/reference/data-privacy/#crash-reports).

## Vergleichs- und Zusammenführungswerkzeuge {#diff-merge-tools}

Die Werkzeuge werden auf der Seite :ui[settings.gitConfig] festgelegt.

| Einstellung | Wirkung |
|---|---|
| :ui[externalTool.diffTool] | Die App, die Dateien vergleicht. Anfangs :ui[externalTool.noneSelected]. |
| :ui[externalTool.directoryDiff] | Öffnet beim Vergleichen mehrerer Dateien diese als zwei Ordner in einem Fenster. Nur Kaleidoscope unterstützt das. Andere Apps öffnen eine Datei nach der anderen. Anfangs eingeschaltet. |
| :ui[externalTool.mergeTool] | Die App, die Konflikte löst. Anfangs :ui[externalTool.noneSelected]. |
| :ui[externalTool.keepBackups] | Behält die Datei, wie sie vor dem Zusammenführen war, daneben mit `.orig` am Ende. Anfangs ausgeschaltet. |

Spooky arbeitet mit diesen Apps:

| App | Vergleichen | Zusammenführen |
|---|---|---|
| Araxis Merge | Ja | Ja |
| BBEdit | Ja | Nein |
| Beyond Compare | Ja | Ja |
| DeltaWalker | Ja | Ja |
| FileMerge | Ja | Ja |
| Kaleidoscope | Ja | Ja |
| P4Merge | Ja | Ja |
| TextMate | Ja | Nein |
| Visual Studio Code | Ja | Ja |

Die Menüs führen auch Apps auf, die nicht installiert sind, aber Sie können sie nicht wählen. Wenn Sie ein Werkzeug verwenden, bevor Sie eines gewählt haben, fragt Spooky, welche App verwendet werden soll.

Wie Sie sie verwenden, lesen Sie unter [In einer anderen App vergleichen](/guide/work/diff/#external) und [In einer anderen App zusammenführen](/guide/work/conflicts/#merge-tool).

## Editoren {#editors}

Spooky hat keine eigene Editor-Einstellung. Um eine Datei in einer anderen App zu öffnen, klicken Sie in der Arbeitskopie mit der rechten Maustaste darauf und wählen Sie :ui[files.open] oder :ui[files.openWith]. Das Untermenü :ui[files.openWith] führt die Apps auf, die die Datei öffnen können, die Standard-App zuerst. Dasselbe Untermenü gibt es im Dateibaum eines Commits und im Konfliktassistenten.

In einem Server-Repository öffnen Visual Studio Code, Visual Studio Code Insiders und Cursor die Datei direkt auf dem Server, wenn ihre Remote-SSH-Erweiterung installiert ist. Andere Apps erhalten eine Kopie. Wenn Sie sichern, schreibt Spooky Ihre Änderungen auf den Server zurück. Siehe [Terminal und andere Apps](/guide/server/local-location/#terminal).

## Terminal {#terminal}

:ui[settings.terminal] auf der Seite :ui[settings.general] wählt die App für :ui[action.openTerminal]. Spooky arbeitet mit Terminal, iTerm, Warp, Ghostty, WezTerm und Otty. Das Menü führt die installierten auf. Anfangs wird Terminal verwendet.

Sie finden :ui[action.openTerminal] an diesen Stellen:

- Im Menü :ui[menu.file]
- Als :ui[toolbar.terminal] in der Symbolleiste
- Im Menü der Arbeitskopie in der Seitenleiste
- Im Menü einer Datei oder eines Ordners in der Dateiliste der Arbeitskopie. Das Terminal öffnet sich in diesem Ordner oder in dem Ordner, in dem die Datei liegt.
- In den Menüs der Repositorys im Fenster „Repositorys“ und der kürzlich geklonten Repositorys
- Im Menü eines Worktrees in der Seitenleiste
- In den [Schnellaktionen](/guide/repositories/navigation/#quick-actions)

Bei einem lokalen Repository öffnet sich das Terminal im Ordner auf diesem Mac. Bei einem Server-Repository meldet es sich per SSH an und wechselt in den Ordner auf dem Server. Siehe [Terminal und andere Apps](/guide/server/local-location/#terminal).

Wenn Spooky zum ersten Mal Terminal oder iTerm öffnet, fragt macOS, ob Spooky die App steuern darf. Wenn Sie es nicht erlauben, zeigt Spooky :ui[error.terminal]. Um es später zu erlauben, gehen Sie zu **Apple-Menü › Systemeinstellungen › Datenschutz & Sicherheit › Automation** und schalten Sie die App unter Spooky ein.

## Finder {#finder}

- **Einen Ordner zeigen**: :ui[action.revealFinder] zeigt den Repository-Ordner oder eine Datei im Finder. Bei einem Server-Repository braucht es einen Ort auf diesem Mac. Siehe [Im Finder zeigen](/guide/server/local-location/#show-in-finder).
- **Repositorys hinzufügen**: Ziehen Sie Repository-Ordner aus dem Finder in das Fenster „Repositorys“. Siehe [Repositorys hinzufügen](/guide/repositories/manager/#add).
- **Das Dock**: Ziehen Sie einen Ordner auf das Symbol von Spooky, um das Repository zu öffnen, in dem er liegt. Klicken Sie mit der rechten Maustaste auf das Symbol, um ein zuletzt verwendetes Repository zu wählen, auch ein Server-Repository. Siehe [Zuletzt verwendete Repositorys und das Dock](/guide/repositories/navigation/#recent).
- **Themen**: Öffnen Sie eine `.spookytheme`-Datei im Finder, um das Thema hinzuzufügen. Siehe [Themen weitergeben](/guide/settings/appearance/#share-themes).

## Siehe auch

- [Allgemein, Updates und Umgebung](/guide/settings/general/)
- [Benutzerprofile und Git-Konfiguration](/guide/settings/identity/)
- [Ort auf diesem Mac](/guide/server/local-location/)
- [SSH vorbereiten](/guide/server/prepare-ssh/)
