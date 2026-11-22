---
title: "Worktrees"
description: "Branches in zusätzlichen Worktrees auschecken und Worktrees öffnen, verschieben, reparieren und entfernen."
---

Ein Worktree ist ein weiterer Ordner, der aus demselben Repository ausgecheckt ist. Jeder Worktree hat seinen eigenen ausgecheckten Branch und seine eigene Arbeitskopie. Alle teilen die Commits und Branches des Repositorys. So können Sie an einem zweiten Branch arbeiten, ohne im ersten Ordner zu stashen oder zu wechseln.

Ein Branch kann immer nur in einem Worktree ausgecheckt sein.

## In der Seitenleiste {#sidebar}

Worktrees stehen in der Seitenleiste unter :ui[worktree.group], sortiert nach Name. Der Name ist der letzte Teil des Worktree-Pfads. Der im Fenster geöffnete Worktree wird nicht aufgelistet. Bewegen Sie den Zeiger über einen, um zu sehen, wo er ausgecheckt ist.

Klicken Sie auf einen Worktree, um Name, Pfad, aktuelle Revision und Branch zu sehen. Doppelklicken Sie darauf, um ihn im selben Fenster zu öffnen.

Ein Branch, der in einem anderen Worktree ausgecheckt ist, hat eine kleine Plakette auf seinem Symbol. Wenn Sie mit der rechten Maustaste darauf klicken, sagt das Menü, in welchem Worktree er liegt. Es hat auch Einträge, um diesen Worktree zu öffnen oder zu entfernen. Siehe [Einen Branch auschecken](/guide/branches/branches/#checkout).

Wie Sie Worktrees auch im Fenster „Repositorys“ auflisten, steht unter [Die Liste ordnen](/guide/repositories/manager/#organize).

## Einen Worktree hinzufügen {#add}

Beginnen Sie auf eine dieser Arten:

- Wählen Sie :ui[menu.repository > menu.addWorktree] in der Menüleiste.
- Klicken Sie unten in der Seitenleiste auf die Hinzufügen-Taste oder klicken Sie mit der rechten Maustaste auf :ui[worktree.group], und wählen Sie :ui[worktree.add.menu] aus dem Menü.
- Klicken Sie mit der rechten Maustaste auf einen lokalen Branch und wählen Sie :ui[worktree.checkoutBranch]{1="feature/units-toggle"} aus dem Menü.
- Ziehen Sie einen lokalen Branch auf :ui[worktree.group].

Im Dialogfenster:

1. Wählen oder tippen Sie neben :ui[worktree.revision] den Branch oder die Revision zum Auschecken. Haben Sie von einem Branch aus begonnen, ist er bereits eingetragen.
2. Geben Sie neben :ui[worktree.destination] den vollständigen Pfad des neuen Ordners ein. Die Taste :ui[submodule.path.select] beginnt neben dem Ordner des Repositorys. Sie schlägt einen Namen aus dem Namen des Repositorys und der Revision vor. Der Ordner darf noch nicht existieren oder muss leer sein.
3. Aktivieren Sie :ui[worktree.detach], um an dieser Revision einen losgelösten HEAD auszuchecken. Dann belegt der Worktree keinen Branch.
4. Klicken Sie auf :ui[worktree.add.submit].

Ist der Branch bereits in einem Worktree ausgecheckt, sagt das Dialogfenster das. Aktivieren Sie :ui[worktree.detach] oder unter :ui[dialog.options] die Option :ui[worktree.force], um den Worktree trotzdem zu erstellen.

Das Repository braucht mindestens einen Commit. Nach dem Erstellen des Worktrees bleibt das Fenster bei dem Repository, das Sie geöffnet hatten. Der neue Worktree erscheint in der Seitenleiste.

## Einen Worktree öffnen {#open}

Sie öffnen einen Worktree wie jedes andere Repository. Klicken Sie in der Seitenleiste mit der rechten Maustaste darauf und wählen Sie aus dem Menü:

- :ui[worktree.open.current], :ui[worktree.open.newTab] oder :ui[worktree.open.newWindow]
- :ui[worktree.reveal], :ui[action.copyPath] oder :ui[action.openTerminal]

## Einen Worktree verschieben {#move}

Klicken Sie mit der rechten Maustaste auf einen Worktree und wählen Sie :ui[worktree.move.menu] aus dem Menü. Geben Sie den neuen Pfad ein oder klicken Sie auf die Taste :ui[submodule.path.select]. Änderungen im Worktree ziehen mit um.

## Einen Worktree entfernen {#remove}

Klicken Sie mit der rechten Maustaste auf einen Worktree und wählen Sie :ui[worktree.remove.menu] aus dem Menü. Das löscht den Ordner des Worktrees. Der Branch, den er ausgecheckt hatte, bleibt im Repository.

Hat der Worktree Änderungen oder nicht verfolgte Dateien, weigert sich Git, ihn zu entfernen. Aktivieren Sie :ui[worktree.remove.force], um ihn zusammen mit ihnen zu löschen.

Der Haupt-Worktree des Repositorys, also der Ordner mit dem Verzeichnis `.git`, lässt sich weder verschieben noch entfernen. Er steht in der Liste, wenn Sie einen anderen Worktree geöffnet haben.

## Einen Worktree reparieren {#repair}

Wird der Ordner eines Worktrees außerhalb von Spooky verschoben oder gelöscht, funktioniert der Worktree nicht mehr. Er erhält in der Seitenleiste ein Warnsymbol. Sie können ihn nicht öffnen. In seinen Details steht :ui[worktree.invalid], mit dem Grund von Git, und zwei Tasten:

- :ui[worktree.invalid.repair]: Haben Sie den Ordner verschoben, wählen Sie :ui[submodule.path.select] im Menü :ui[worktree.location] und suchen Sie, wo der Ordner jetzt liegt. Spooky prüft, ob der Ordner dieser Worktree dieses Repositorys ist. Klicken Sie dann auf :ui[worktree.relocate.submit].
- :ui[worktree.invalid.remove]: Ist der Ordner weg, entfernt dies die Reste des Worktrees aus dem Repository.

Beide finden Sie auch im Kontextmenü des Worktrees.

## Widerrufen {#undo}

Das Hinzufügen, Verschieben, Entfernen und Reparieren von Worktrees lässt sich nicht mit <kbd>⌘Z</kbd> widerrufen. Auch Vorgänge davor lassen sich danach nicht mehr widerrufen. Siehe [Widerrufen und Wiederherstellen](/guide/work/undo/).

:::note[Server-Repositorys]
Worktrees werden auf dem Server erstellt. Ihre Pfade sind Pfade auf dem Server. :ui[submodule.path.select] durchsucht die Ordner des Servers.

:ui[worktree.reveal] ist verfügbar, wenn Spooky den Ordner des Worktrees auf Ihrem Mac finden kann. Liegt der Worktree im Ordner des Repositorys, findet Spooky ihn über den Ort des Repositorys. Andernfalls sucht es unter den Volumes, die auf Ihrem Mac eingebunden sind. Siehe [Ort auf diesem Mac](/guide/server/local-location/).
:::

## Siehe auch

- [Branches](/guide/branches/branches/)
- [Submodule](/guide/advanced/submodules/)
- [Das Fenster „Repositorys“](/guide/repositories/manager/)
