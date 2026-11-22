---
title: "Benutzerhandbuch"
description: "Erfahren Sie, wie dieses Handbuch aufgebaut ist und wo Sie am besten anfangen."
---

Dieses Handbuch zeigt, wie Sie die tägliche Arbeit mit Git in Spooky erledigen. Es behandelt Repositorys auf Ihrem Mac und Repositorys, die auf einem anderen Rechner bleiben und die Sie per SSH erreichen. Jede Seite behandelt einen Aufgabenbereich und beginnt damit, wobei sie Ihnen hilft.

Wenn Spooky neu für Sie ist, lesen Sie die Seiten unter „Erste Schritte“ der Reihe nach. Wenn Ihre Repositorys auf einem Server liegen, lesen Sie danach „Server-Repositorys“.

In Spooky öffnet :ui[menu.help > help.help] (<kbd>⌘?</kbd>) diese Website. Viele Dialogfenster haben außerdem eine Hilfetaste. Sie öffnet den Teil dieses Handbuchs, der das Dialogfenster beschreibt.

## Aufbau des Handbuchs {#organization}

| Gruppe | Inhalt |
|---|---|
| [Erste Schritte](/guide/start/install/) | Spooky installieren und aktualisieren, die Teile seiner Fenster, ein erster Commit und Push |
| [Repositorys](/guide/repositories/manager/) | Repositorys verwalten, Fenster und Tabs, vor und zurück navigieren, Schnellaktionen |
| [Server-Repositorys](/guide/server/overview/) | Wie Spooky mit Repositorys auf einem Server arbeitet, SSH vorbereiten, ein Server-Repository hinzufügen, die Verbindung, der Ort auf diesem Mac |
| [Tägliche Arbeit](/guide/work/working-copy/) | Die Arbeitskopie, Änderungen prüfen und stagen, committen, Stashes, Konflikte, Widerrufen |
| [Verlauf](/guide/history/browse/) | Den Verlauf durchsuchen, Commit-Details, Dateiverlauf und Blame, den Verlauf umschreiben |
| [Branches und Synchronisation](/guide/branches/branches/) | Branches, Tags und Remotes, Abrufen, Pullen und Pushen, Zusammenführen und Rebase, Branches aufräumen |
| [Zusammenarbeit](/guide/hosting/accounts/) | Hosting-Accounts, Pull Requests und Merge Requests |
| [Weitere Git-Funktionen](/guide/advanced/submodules/) | Submodule, Worktrees, Git LFS und die Warteschlange der Vorgänge |
| [Einstellungen und Integration](/guide/settings/general/) | Einstellungen, Erscheinungsbild und Themen, Benutzerprofile und Git-Konfiguration, Zusammenspiel mit anderen Apps |
| [Referenz](/reference/shortcuts/) | Tastaturkurzbefehle, Systemanforderungen, Daten und Datenschutz, Fehlerbehebung |

## Schreibweisen {#conventions}

### Namen auf dem Bildschirm {#names}

Namen von Tasten, Menüs, Optionen und Fenstern sind fett gesetzt, zum Beispiel :ui[working.commit]. Sie stammen direkt aus Spooky. Wenn Spooky in der Sprache dieser Seite läuft, sehen Sie dieselben Namen auf dem Bildschirm.

Ein Menüpfad wie :ui[menu.file > action.openLocal] bedeutet: Klicken Sie in der Menüleiste auf den ersten Namen und wählen Sie dann den nächsten aus diesem Menü.

Einige Seiten nennen auch Teile von macOS, zum Beispiel **Systemeinstellungen**. Sie sind so geschrieben, wie macOS sie anzeigt.

### Tastaturkurzbefehle {#shortcuts}

Kurzbefehle sehen wie Tasten aus, zum Beispiel <kbd>⇧⌘A</kbd>. Halten Sie die Sondertasten gedrückt und drücken Sie dann die letzte Taste. Die Symbole sind dieselben, die macOS in seinen Menüs zeigt.

| Symbol | Taste |
|---|---|
| <kbd>⌘</kbd> | Befehlstaste |
| <kbd>⇧</kbd> | Umschalttaste |
| <kbd>⌥</kbd> | Wahltaste |
| <kbd>⌃</kbd> | Control-Taste |
| <kbd>↩</kbd> | Zeilenschalter |
| <kbd>⌫</kbd> | Rückschritttaste |

Alle Kurzbefehle sind unter [Tastaturkurzbefehle](/reference/shortcuts/) aufgeführt.

### Hinweise zu Server-Repositorys {#server-notes}

Ein Server-Repository bleibt auf einem anderen Rechner, und Spooky öffnet es per SSH. Die meisten Aufgaben funktionieren dort genauso. Wenn etwas anders ist, steht es auf der Seite in einem Hinweis wie diesem:

:::note[Server-Repositorys]
Ein Hinweis mit diesem Titel sagt Ihnen, was in einem Server-Repository anders ist. Wenn Sie nur Repositorys auf Ihrem Mac verwenden, können Sie diese Hinweise überspringen.
:::

## Siehe auch

- [Spooky installieren](/guide/start/install/)
- [Spooky im Überblick](/guide/start/tour/)
- [So funktionieren Server-Repositorys](/guide/server/overview/)
