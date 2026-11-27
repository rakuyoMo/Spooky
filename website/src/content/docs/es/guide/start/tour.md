---
title: "Un recorrido por Spooky"
description: "Conoce la ventana Repositorios y la ventana de repositorio: la barra lateral, la barra de herramientas, las tres columnas y las acciones rápidas."
---

Las ventanas de Spooky muestran una de dos cosas. La vista Repositorios es la lista de tus repositorios. En una ventana de repositorio es donde haces el trabajo de verdad. Esta página pone nombre a las partes de ambas. El resto de la guía usa esos nombres.

## La ventana Repositorios {#repositories-window}

Al abrir Spooky por primera vez, aparece la vista Repositorios. La barra lateral muestra tus repositorios bajo :ui[repositories.title]. Puedes ordenarlos en grupos.

- Selecciona un repositorio para ver sus detalles a la derecha: dónde está, cuándo lo abriste por última vez, su último commit, su rama actual y sus cambios, y sus remotos.
- Selecciona un grupo, o nada, para ver un área que dice :ui[bookmarks.dropZone.title], con los botones :ui[bookmarks.dropZone.add], :ui[action.addRemote], :ui[bookmarks.dropZone.create] y :ui[bookmarks.dropZone.clone].
- El botón de añadir, en la parte inferior de la barra lateral, añade grupos y repositorios.

Haz doble clic en un repositorio para abrirlo. Se abre en la misma ventana, en lugar de la vista Repositorios. Para volver a la lista, haz clic en :ui[toolbar.bookmarks] en la parte superior de la barra lateral. [La ventana Repositorios](/guide/repositories/manager/) explica la lista con detalle.

## La ventana de repositorio {#repository-window}

Cuando hay un repositorio abierto, el título de la ventana muestra su nombre. Debajo del nombre está la vista actual con un breve resumen, como la rama y el número de archivos modificados.

::screenshot[Una ventana de repositorio. La barra lateral, a la izquierda, muestra las vistas, las ramas, las etiquetas y los remotos del repositorio. La barra de herramientas ocupa la parte superior. La columna central muestra el área de commit sobre una lista de archivos modificados, y la columna derecha muestra los cambios del archivo seleccionado.]{name="tour-window" frame="window" markers="16.5,47 50,3.25 36,72 85,31"}

1. La barra lateral
2. La barra de herramientas
3. La columna central: la lista de la vista actual
4. La columna derecha: los detalles de lo seleccionado en la columna central

:::note[Repositorios de servidor]
El título de la ventana empieza por el alias de host, como en `alias:name`. La barra de herramientas muestra además el alias de host en un ítem :ui[toolbar.host]. [Estado de la conexión y reconexión](/guide/server/connection/) explica qué muestra la ventana cuando se corta la conexión.
:::

### Barra lateral {#sidebar}

La sección :ui[workspace.group], arriba del todo, cambia entre las vistas del repositorio:

| Vista | Qué muestra |
|---|---|
| :ui[workspace.title] | Tus cambios sin commit. El número que tiene al lado cuenta los archivos modificados. |
| :ui[history.title] | Los commits |
| :ui[stash.title] | Los cambios que has apartado |
| :ui[pr.title] | Las pull requests o merge requests del servicio de alojamiento |
| :ui[review.title] | Tus ramas, para encontrar las que puedes limpiar |
| :ui[reflog.title] | Por dónde ha pasado HEAD. Aparece tras activar :ui[sidebar.showReflog] en :ui[sidebar.viewSettings]. |
| :ui[repositorySettings.title] | Los ajustes de este repositorio. Consulta [Ajustes del repositorio](/guide/settings/identity/#repository). |

Debajo vienen :ui[sidebar.pinned] (cuando fijas una rama), :ui[branch.group], :ui[sidebar.archived], :ui[sidebar.tags], :ui[remote.group], :ui[submodule.group] y :ui[worktree.group]. En :ui[branch.group], una insignia HEAD marca la rama en la que estás. Una flecha con un número, como ↑3, cuenta los commits de los que aún no has hecho push.

La barra de la parte inferior de la barra lateral tiene un campo :ui[sidebar.filter], un botón :ui[reference.addMenu] para crear ramas y otras referencias, y :ui[sidebar.viewSettings] para elegir qué muestra la barra lateral.

### Barra de herramientas {#toolbar}

De izquierda a derecha, la barra de herramientas tiene estos botones:

- :ui[toolbar.bookmarks]: vuelve a la vista Repositorios
- :ui[toolbar.previous] y :ui[toolbar.next]: van atrás y adelante por las vistas que has visitado
- :ui[toolbar.finder] y :ui[toolbar.terminal]: muestran la carpeta del repositorio en el Finder, o la abren en un terminal
- :ui[sync.fetch], :ui[sync.pull] y :ui[sync.push]: intercambian commits con los remotos
- :ui[toolbar.forcePush]: reemplaza una rama remota por la tuya después de reescribir commits
- :ui[toolbar.applyStash] y :ui[toolbar.saveStash]: recuperan los cambios que has apartado, o apartan tus cambios actuales
- :ui[toolbar.createBranch]: crea una rama
- :ui[action.refresh]: vuelve a leer el repositorio
- :ui[action.search]: filtra la lista de la vista actual

Mantén pulsada <kbd>⌥</kbd> y :ui[sync.fetch], :ui[sync.pull] y :ui[sync.push] pasan a su versión rápida, como :ui[sync.quickPush]. Una versión rápida trabaja directamente con la rama de seguimiento, sin abrir ningún diálogo.

:ui[toolbar.clone] aparece mientras tienes clones recientes. Consulta [La ventana Repositorios](/guide/repositories/manager/). Selecciona :ui[menu.view > menu.customizeToolbar] para añadir o quitar botones. Además de los botones anteriores, puedes añadir :ui[toolbar.quickActions], :ui[toolbar.synchronize], :ui[sync.merge] y :ui[sync.rebaseHead], y :ui[toolbar.pushTo].

### Las tres columnas {#columns}

La columna izquierda es la barra lateral. La columna central muestra la lista de la vista que has elegido. En :ui[workspace.title], son el área de commit y los archivos modificados. En :ui[history.title], son los commits.

La columna derecha muestra los detalles de lo que seleccionas en la central. En :ui[workspace.title], son los cambios del archivo seleccionado. Cuando un archivo tiene cambios en el stage y fuera de él, usa :ui[working.staged] y :ui[working.unstaged], arriba, para pasar de unos a otros. Sin nada seleccionado, la columna muestra :ui[detail.empty.title].

### Ventanas estrechas {#narrow-window}

Cuando la ventana es demasiado estrecha para tres columnas, cambia a un diseño para ventanas estrechas. Ensancha la ventana y vuelven las tres columnas, con la anchura que tenían.

::screenshot[Una ventana de repositorio estrecha. Una fila bajo la barra de herramientas cambia de vista. El área de commit y la lista de archivos modificados están encima de los cambios del archivo seleccionado.]{name="tour-narrow-window" frame="window" markers="75,9 75,40 75,84"}

1. La fila de vistas, en lugar de la barra lateral
2. La lista de la vista actual
3. Los detalles de lo que está seleccionado en la lista

- La fila de vistas tiene las vistas que están bajo :ui[workspace.group] en la barra lateral. Desplaza la fila hacia los lados para llegar a las que no caben. Para las ramas, las etiquetas, los remotos y las demás vistas, haz clic en :ui[sidebar.menu] al principio de la fila. La barra lateral se abre encima de la vista. Haz clic otra vez en :ui[sidebar.menu], o fuera de la barra lateral, para cerrarla.
- La lista está encima de los detalles. Arrastra la línea que los separa para dar más espacio a uno de los dos.
- :ui[toolbar.bookmarks], :ui[toolbar.previous] y :ui[toolbar.next] van delante del título de la ventana y se quedan siempre en la barra de herramientas, junto con el campo de búsqueda. Los demás botones que no caben pasan al menú » del final de la barra de herramientas. :ui[sync.fetch], :ui[sync.pull] y :ui[sync.push] son los últimos en pasar.

La vista en la que estás, tu selección y el mensaje de commit que estás escribiendo se mantienen cuando cambia el diseño.

La ventana Repositorios también cambia de diseño cuando se estrecha. La lista de repositorios queda encima de los detalles del repositorio seleccionado.

Para usar siempre el mismo diseño, selecciona :ui[menu.layout.narrow] o :ui[menu.layout.wide] en :ui[menu.view > menu.layout]. La ventana usa entonces ese diseño con cualquier anchura. Selecciona :ui[menu.layout.automatic] para que el diseño vuelva a seguir la anchura de la ventana. La selección se aplica a todas las ventanas.

### Acciones rápidas {#quick-actions}

Selecciona :ui[menu.file > quickActions.menu] o pulsa <kbd>⇧⌘A</kbd> para abrir un panel. Escribe para encontrar una vista, una rama, un archivo o un commit, y ejecuta una acción sobre él sin soltar el teclado. [Ventanas y navegación](/guide/repositories/navigation/) explica qué encuentra y qué teclas usa.

## Consulta también

- [Tu primer repositorio](/guide/start/first-repository/)
- [La ventana Repositorios](/guide/repositories/manager/)
- [Ventanas y navegación](/guide/repositories/navigation/)
