---
title: "Submodule"
description: "Submodule öffnen, aktualisieren, abrufen, initialisieren, synchronisieren, verschieben, umbenennen und löschen."
---

Ein Submodul ist ein weiteres Git-Repository in einem Ordner Ihres Repositorys. Ihr Repository hält fest, welcher Commit davon verwendet wird. Spooky nennt diesen Eintrag den Submodul-Zeiger.

## In der Seitenleiste {#sidebar}

Submodule stehen in der Seitenleiste unter :ui[submodule.group], sortiert nach Pfad. Bewegen Sie den Zeiger über eines, um Name und URL zu sehen.

- Eine abgeblendete Zeile ist ein Submodul, das noch nicht ausgecheckt ist.
- Ein Warnsymbol bedeutet, dass seine Konfiguration unvollständig ist oder seine URL synchronisiert werden muss.
- Eine Zahl gibt an, wie viele Dateien sich darin geändert haben.
- ↑ und ↓ zeigen, wie weit der ausgecheckte Commit dem Submodul-Zeiger voraus ist oder hinter ihm liegt.

Klicken Sie auf ein Submodul, um seine Details zu sehen. Doppelklicken Sie auf ein ausgechecktes Submodul, um es als Repository im selben Fenster zu öffnen. Solange es geöffnet ist, bringt Sie :ui[toolbar.parentRepository] in der Symbolleiste zurück.

Ein Doppelklick auf ein ausgechecktes Submodul in der Dateiliste der Arbeitskopie öffnet es auf dieselbe Weise. Damit dieser Doppelklick es stattdessen wie andere Dateien öffnet, deaktivieren Sie :ui[files.openSubmodules] unter :ui[app.name > settings.title] › :ui[settings.general]. Siehe [Dateiliste](/guide/settings/general/#file-list).

## Details {#details}

Die Details haben drei Seiten, die Sie oben wählen:

- :ui[submodule.page.general]: Name, Pfad, Status, lokale Änderungen, der ausgecheckte Commit, der Submodul-Zeiger und die wirksamen Einstellungen. Ist das Submodul nicht initialisiert oder hat sich seine URL in `.gitmodules` geändert, hat ein Hinweis oben eine Taste, um das zu beheben.
- :ui[submodule.page.shared]: die Einstellungen in `.gitmodules`. Alle, die das Repository klonen, erhalten sie. Änderungen hier erscheinen in der Arbeitskopie. Sie committen sie wie andere Änderungen.
- :ui[submodule.page.local]: die Einstellungen in der eigenen Konfiguration dieses Repositorys. Sie gelten nur hier. Sie haben Vorrang vor `.gitmodules`.

Auf den beiden Konfigurationsseiten können Sie das Submodul umbenennen und verschieben, seine URL ändern und drei Optionen festlegen. :ui[submodule.useDefault] entfernt eine Option. Dann gilt der Standard von Git.

- :ui[submodule.field.fetchMode]: ob das Abrufen des übergeordneten Repositorys auch dieses Submodul abruft. Wählen Sie :ui[submodule.fetchMode.always], :ui[submodule.fetchMode.onDemand] (nur wenn abgerufene Commits seinen Zeiger ändern, der Standard) oder :ui[submodule.fetchMode.never].
- :ui[submodule.field.ignoreMode]: welche Änderungen im Submodul die Arbeitskopie des übergeordneten Repositorys ignoriert. Wählen Sie :ui[submodule.ignoreMode.none] (der Standard), :ui[submodule.ignoreMode.untracked], :ui[submodule.ignoreMode.dirty] (nur ein anderer ausgecheckter Commit zählt) oder :ui[submodule.ignoreMode.all].
- :ui[submodule.field.updateStrategy]: wie das Aktualisieren das Submodul auf seinen Zeiger bringt. Wählen Sie :ui[submodule.updateStrategy.checkout] (der Standard), :ui[submodule.updateStrategy.rebase] oder :ui[submodule.updateStrategy.merge] auf seinen aktuellen Branch, oder :ui[submodule.updateStrategy.none].

## Ein Submodul hinzufügen {#add}

1. Wählen Sie :ui[menu.repository > menu.addSubmodule] in der Menüleiste. Sie können auch unten in der Seitenleiste auf die Hinzufügen-Taste klicken oder mit der rechten Maustaste auf :ui[submodule.group] klicken und :ui[submodule.add.menu] aus dem Menü wählen.
2. Geben Sie die URL des Submodul-Repositorys ein.
3. Wählen Sie für :ui[submodule.path] den Eintrag :ui[submodule.path.select] und suchen Sie einen leeren Ordner in Ihrem Repository aus.
4. Klicken Sie auf :ui[submodule.add.submit].

Hat Ihr Repository bereits ein Git-Verzeichnis für ein Submodul dieses Namens, zum Beispiel von einem gelöschten, fragt Spooky, was zu tun ist. :ui[submodule.forceAdd.reuse] verwendet es erneut. :ui[submodule.forceAdd.overwrite] löscht es und klont neu.

## Abrufen und aktualisieren {#update}

- **Abrufen** lädt neue Commits vom Remote des Submoduls. Was ausgecheckt ist, ändert sich nicht.
- **Aktualisieren** checkt den Commit aus, den der Zeiger festhält. Ein nicht initialisiertes Submodul wird zuerst initialisiert.

Klicken Sie mit der rechten Maustaste auf ein Submodul und wählen Sie :ui[submodule.fetch.menu]{1="vendor/charts"} oder :ui[submodule.update.menu]{1="vendor/charts"} aus dem Menü. Das Menü :ui[menu.repository] enthält dasselbe, dazu Einträge für alle Submodule auf einmal.

Die Dialogfenster haben diese Optionen:

- :ui[sync.prune] beim Abrufen
- :ui[submodule.update.recursive] beim Aktualisieren. Die Option aktualisiert auch Submodule innerhalb des Submoduls. Deren Remotes müssen mit bereits eingerichteten Zugangsdaten funktionieren. Spooky kann Sie unterwegs nicht danach fragen.

Halten Sie im Kontextmenü <kbd>⌥</kbd> gedrückt, um :ui[submodule.quickFetch]{1="vendor/charts"} und :ui[submodule.quickUpdate]{1="vendor/charts"} zu erhalten. Sie überspringen das Dialogfenster und verwenden die Optionen vom letzten Mal. Dasselbe gilt für :ui[menu.fetchAllSubmodules] und :ui[menu.updateAllSubmodules] in der Menüleiste.

Aktualisieren ist nur verfügbar, wenn es etwas zu tun gibt: Das Submodul ist nicht ausgecheckt, oder ein anderer Commit ist ausgecheckt.

### Nach anderen Vorgängen aktualisieren {#auto-update}

Auschecken, Pullen, Zusammenführen und andere Vorgänge können den Zeiger eines ausgecheckten Submoduls ändern. Danach fragt Spooky, ob diese Submodule aktualisiert werden sollen. Aktivieren Sie :ui[submodule.autoUpdate.always], um sie von da an sofort zu aktualisieren. Sie können das mit :ui[settings.autoUpdateSubmodules] unter :ui[app.name > settings.title] › :ui[settings.general] wieder deaktivieren. Siehe [Vorgänge](/guide/settings/general/#operations).

### Initialisieren und synchronisieren {#initialize}

- **Initialisieren** kopiert die Einstellungen des Submoduls aus `.gitmodules` in die Konfiguration Ihres Repositorys. Aktualisieren Sie es danach, um es auszuchecken.
- **Synchronisieren** ist für den Fall gedacht, dass sich die URL in `.gitmodules` geändert hat. Es gleicht die URL in der Konfiguration Ihres Repositorys und im eigenen Repository des Submoduls an die neue an.

Beides steht im Kontextmenü und, wenn es nötig ist, in einem Hinweis auf der Seite :ui[submodule.page.general].

## Eine andere Revision auschecken {#checkout}

Klicken Sie mit der rechten Maustaste auf ein ausgechecktes Submodul und wählen Sie aus :ui[submodule.checkoutRevision] einen Branch oder ein Tag des Submoduls. Der aktuelle Eintrag hat ein Häkchen.

Sind Änderungen im Submodul im Weg, schlägt das Auschecken fehl. Spooky bietet nicht an, sie zu stashen. Stashes in Ihrem Repository erfassen das Submodul nicht.

Der Zeiger in Ihrem Repository bewegt sich erst, wenn Sie den neuen Commit des Submoduls committen.

## Verschieben, umbenennen und löschen {#manage}

Alle drei stehen im Kontextmenü:

- **Verschieben** ändert den Pfad des Submoduls. Aktivieren Sie :ui[submodule.move.rename], um es zugleich in den neuen Pfad umzubenennen.
- **Umbenennen** ändert seinen Namen. `.gitmodules` und Ihre Konfiguration verweisen unter diesem Namen auf das Submodul. Der Ordner bleibt, wo er ist.
- **Löschen** entfernt das Submodul aus Ihrem Repository. Aktivieren Sie :ui[submodule.delete.keepWorkingTree], um nur seine Konfiguration zu entfernen und seine Dateien zu behalten. Hat es Änderungen, fragt Spooky nach, bevor es mit :ui[submodule.forceDelete.submit] trotzdem gelöscht wird.

Diese Vorgänge ändern `.gitmodules` und den Index Ihres Repositorys. Committen Sie sie, damit auch andere sie erhalten.

Nach dem Löschen bleibt das Git-Verzeichnis des Submoduls im Ordner `.git` Ihres Repositorys. Beim erneuten Hinzufügen kann es wiederverwendet werden.

### Ein Submodul reparieren {#repair}

Ist die Konfiguration eines Submoduls unvollständig, steht in seinen Details :ui[submodule.invalid], mit zwei Tasten. :ui[submodule.repair.submit] stellt wieder her, was fehlt: den Eintrag in `.gitmodules`, den Zeiger oder das ausgecheckte Repository. Findet Spooky die URL des Submoduls nirgends, löschen Sie es und fügen Sie es erneut hinzu.

## Widerrufen {#undo}

Sie können das Hinzufügen, Verschieben, Umbenennen und Löschen eines Submoduls, das Auschecken einer anderen Revision darin und das Ändern seiner URL oder Optionen widerrufen. Siehe [Widerrufen und Wiederherstellen](/guide/work/undo/).

Initialisieren, Synchronisieren und Reparieren lassen sich nicht widerrufen. Auch Vorgänge davor lassen sich danach nicht mehr widerrufen.

Abrufen und Aktualisieren werden nicht aufgezeichnet, genau wie Abrufen und Pullen im Repository. Vorgänge davor lassen sich weiterhin widerrufen.

:::note[Server-Repositorys]
All das läuft auf dem Server. Wenn Sie ein Submodul hinzufügen, wählen Sie seinen Ordner auf dem Server.
:::

## Siehe auch

- [Abrufen, Pullen und Pushen](/guide/branches/sync/)
- [Worktrees](/guide/advanced/worktrees/)
- [Widerrufen und Wiederherstellen](/guide/work/undo/)
