---
title: "Ramas"
description: "Crea ramas, haz checkout de ellas, síguelas, renómbralas, elimínalas, fíjalas y archívalas, establece ramas padre, y filtra y agrupa las ramas en la barra lateral."
---

Tus ramas locales aparecen en la barra lateral, en :ui[branch.group]. Casi todo lo que haces con una rama empieza ahí: haz clic derecho en ella para ver su menú, o arrástrala a algún sitio.

::screenshot[La parte inferior de la barra lateral. En Ramas, main tiene una insignia HEAD con ↑3, y una carpeta feature contiene dark-mode, station-map y units-toggle. Ramas archivadas está vacío. Etiquetas muestra de v0.1.0 a v0.4.0. En Remotos, origin tiene main con un icono de casa y una carpeta feature contraída. La barra de abajo tiene el campo de filtro a la izquierda, y los botones de añadir y de ajustes de visualización a la derecha.]{name="branches" frame="closeup" markers="57,7 57,12.1 75,33.6 17,96.8 73,96.8"}

1. La rama en la que estás, con su insignia HEAD y los commits de los que aún no has hecho push
2. Una carpeta para las ramas cuyo nombre empieza por `feature/`
3. :ui[sidebar.archived]
4. :ui[sidebar.filter]
5. El botón de añadir y el botón de ajustes de visualización

## En la barra lateral {#sidebar}

Haz clic en una rama para ver sus commits en el historial. Haz doble clic en ella para hacer checkout.

Una rama que sigue a una rama remota muestra cuánto se han separado las dos. ↑ cuenta tus commits que aún no están en el remoto. ↓ cuenta los commits del remoto que tú no tienes. Deja el puntero sobre una rama para ver a cuál sigue.

Una rama que lleva un tiempo sin commits nuevos es obsoleta. Su nombre se atenúa, seguido de un reloj y del tiempo que lleva así. `main`, `master`, `trunk`, `dev`, `develop`, `next` y cualquier rama que sea la rama padre de otra nunca son obsoletas.

En :ui[remote.group], un icono de casa marca la rama predeterminada de cada remoto.

## Crear una rama {#create}

1. Selecciona :ui[menu.repository > branch.createMenu] (<kbd>⌘B</kbd>). También puedes hacer clic en el botón de añadir de la parte inferior de la barra lateral, o hacer clic derecho en :ui[branch.group], y seleccionarlo en el menú.
2. Escribe el nombre en :ui[reference.name].
3. Elige dónde empieza la rama en :ui[branch.start]. Al principio es la rama en la que estás, o aquello en lo que hiciste clic derecho para llegar aquí.
4. Ajusta las opciones:
   - :ui[branch.trackStart] hace que la nueva rama siga a su punto de partida. Solo está disponible cuando el punto de partida es una rama.
   - :ui[branch.pin] pone la nueva rama en :ui[sidebar.pinned].
   - :ui[branch.checkoutCreated] cambia a la nueva rama enseguida. Spooky recuerda esta elección.
   - :ui[branch.parentOption] establece el punto de partida como [rama padre](#parent) de la nueva rama.
5. Haz clic en :ui[branch.create].

Para empezar una rama desde una rama, etiqueta o commit concretos, haz clic derecho en ese elemento y selecciona :ui[branch.createFromMenu]{1="main"} en el menú. También puedes arrastrarlo a :ui[branch.group].

Mientras escribes, Spooky adapta el nombre para Git: los espacios y los caracteres que Git no admite se convierten en `-` o se eliminan. Para escribir los nombres tal cual, desactiva :ui[branch.cleanNames] en :ui[app.name > settings.title] › :ui[settings.general]. Consulta [Operaciones](/guide/settings/general/#operations).

Una `/` en el nombre pone la rama en una carpeta, como `feature/units-toggle` en `feature`. Haz clic derecho en una carpeta y selecciona :ui[branch.createMenu] en el menú, y el nombre empieza ya por la carpeta.

## Hacer checkout de una rama {#checkout}

Haz doble clic en una rama, o haz clic derecho en ella y selecciona :ui[branch.checkoutNamed]{1="feature/dark-mode"} en el menú.

El doble clic también funciona con una rama remota:

- Si una rama local ya la sigue, Spooky hace checkout de esa rama.
- Si hay una rama local con el mismo nombre que no la sigue, Spooky pregunta antes en :ui[branch.trackExisting.title]. Después hace checkout de esa rama y hace que siga a la rama remota.
- En los demás casos, Spooky crea una rama local con el mismo nombre que sigue a la rama remota. Después hace checkout de ella.

Cuando tienes cambios en archivos con seguimiento, Spooky pregunta si quieres guardarlos antes en un stash. Consulta [Stash automático](/guide/work/stash/#auto-stash).

De una rama que ya tiene checkout en otro worktree no se puede hacer checkout aquí. Haz doble clic en ella y Spooky abre ese worktree. Mantén pulsada <kbd>⌘</kbd> mientras haces doble clic para abrirlo en una pestaña nueva.

### Hacer checkout de una etiqueta o un commit {#checkout-revision}

Haz doble clic en una etiqueta para hacer checkout de su commit. Para hacer checkout de cualquier otra cosa, selecciona :ui[workspace.title > rewrite.checkout.menu] (<kbd>⇧⌘B</kbd>), elige una rama, etiqueta o commit, y haz clic en :ui[rewrite.checkout.button].

Cuando lo que eliges no es una rama local, el diálogo avisa de que HEAD quedará desacoplado. Un HEAD desacoplado significa que estás en un commit, no en una rama. Para conservar los commits que hagas ahí, crea una rama a partir de ellos.

## Seguir una rama remota {#track}

Una rama local puede seguir a una rama de un remoto, su upstream. Pull y push usan el upstream salvo que elijas otra cosa. Los contadores ↑ y ↓ se comparan con él.

Para tener una rama local de una rama remota:

1. Haz clic derecho en la rama remota y selecciona :ui[branch.trackMenu]{1="origin/feature/station-map"} en el menú, o arrástrala a :ui[branch.group].
2. :ui[branch.remoteField] muestra la rama remota. Cambia el nombre en :ui[reference.name] si quieres.
3. :ui[branch.track.checkout] está seleccionado cada vez. Desmárcalo para quedarte en la rama actual.
4. Haz clic en :ui[branch.track.submit].

Para cambiar a qué sigue una rama existente, haz clic derecho en ella y selecciona una rama en :ui[branch.tracking]. :ui[branch.tracking.remove] deja de seguirla. En la rama en la que estás, también puedes mantener pulsada <kbd>⌥</kbd> y arrastrar una rama remota sobre ella.

Cuando una rama en la que no estás va por detrás de su upstream y no tiene commits propios, su menú tiene :ui[branch.fastForward]{1="main"}. Lleva la rama hasta el upstream sin hacer checkout de ella.

## Renombrar una rama {#rename}

Haz clic derecho en la rama y selecciona :ui[reference.renameMenu]{1="feature/dark-mode"} en el menú. Escribe el nuevo nombre y haz clic en :ui[reference.rename].

Los ajustes de fijado, archivado y rama padre van con la rama. Renombrar una rama remota la renombra en el remoto.

Para mover una rama a una carpeta, arrástrala sobre la carpeta. Consulta [Arrastrar y soltar](/guide/branches/merge-rebase/#drag-and-drop).

## Eliminar una rama {#delete}

Haz clic derecho en la rama y selecciona :ui[reference.deleteMenu]{1="feature/dark-mode"} en el menú. También puedes seleccionar una o varias ramas y pulsar <kbd>⌘⌫</kbd> mientras la barra lateral tiene el foco.

Spooky siempre pregunta antes. El diálogo tiene dos opciones:

- :ui[branch.forceDelete] elimina la rama aunque no esté fusionada del todo. Sin ella, Spooky muestra las ramas que no están fusionadas del todo y vuelve a preguntar.
- :ui[branch.deleteUpstream] elimina también la rama remota a la que sigue. Aparece cuando eliminas una sola rama cuya rama remota todavía existe.

No puedes eliminar la rama en la que estás. Haz antes checkout de otra rama.

Eliminar una rama remota la elimina en el remoto.

Para recuperar una rama local eliminada, selecciona :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>). Funciona incluso con :ui[branch.deleteUpstream] seleccionado. Eliminar solo una rama remota no se puede deshacer. Consulta [Deshacer y recuperar](/guide/work/undo/).

## Fijar una rama {#pin}

Las ramas fijadas pasan de :ui[branch.group] a :ui[sidebar.pinned], al principio de la lista. Úsalo para las ramas a las que vuelves a menudo.

Haz clic derecho en una rama y selecciona :ui[branch.pinNamed]{1="feature/station-map"} en el menú, o arrástrala a :ui[sidebar.pinned]. Con varias ramas seleccionadas, el ítem es :ui[branch.pinMultiple]{1="2"}. Para devolver una rama a su sitio, selecciona :ui[branch.unpinNamed]{1="feature/station-map"}.

## Archivar una rama {#archive}

Archivar una rama la aparta sin eliminarla. Pasa de :ui[branch.group] a :ui[sidebar.archived]. Puedes seguir usándola como antes.

Haz clic derecho en una rama y selecciona :ui[branch.archiveNamed]{1="feature/dark-mode"} en el menú, o arrástrala a :ui[sidebar.archived]. Para traerla de vuelta, selecciona :ui[branch.unarchiveNamed]{1="feature/dark-mode"}.

Spooky también puede buscar ramas que conviene archivar, y archivarlas por ti. Consulta [Revisión de ramas](/guide/branches/review/#archive-suggestions).

:::note[Repositorios de servidor]
El fijado, el archivado y las ramas padre se guardan en la configuración de Git del repositorio. En un repositorio de servidor, se guardan en el servidor.
:::

## Rama padre {#parent}

Una rama padre es la rama en la que se basa la tuya y con la que debe mantenerse al día, como `main` para `feature/units-toggle`.

Para establecerla, haz clic derecho en la rama y selecciona una de las ramas sugeridas en :ui[branch.parent]. Para cualquier otra rama, selecciona :ui[branch.parent.setMenu], elígela en :ui[branch.parent.field] y haz clic en :ui[branch.parent.set]. También puedes establecerla al crear la rama. :ui[branch.parent.remove] la quita.

Cuando una rama tiene rama padre:

- La comparación de ramas en el historial empieza por la rama padre. Consulta [Comparar con otra rama](/guide/history/browse/#compare-branches).
- Cuando la rama padre tiene commits que tu rama no tiene, el historial de tu rama muestra :ui[history.parentBanner.title]. El menú de la rama tiene :ui[branch.updateNamed]{1="feature/units-toggle"} para traerlos. Consulta [Actualizar una rama desde su rama padre](/guide/branches/merge-rebase/#update).
- En la rama en la que estás, :ui[branch.mergeWith]{1="main"} y :ui[branch.rebaseOn]{1="main"} del menú abren los diálogos de fusión y de rebase con la rama padre elegida.
- La rama padre nunca es obsoleta.

## Filtrar y agrupar {#filter}

Escribe en :ui[sidebar.filter], en la parte inferior de la barra lateral, para mostrar solo las ramas, etiquetas, ramas remotas, submódulos y worktrees que coinciden. Las letras no tienen que ir seguidas: `stm` encuentra `station-map`. No importan las mayúsculas ni los acentos. Las carpetas se abren mientras filtras, y <kbd>Esc</kbd> vacía el campo.

Haz clic en el botón de ajustes de visualización, abajo a la derecha, o selecciona :ui[menu.view > sidebar.menu], para decidir qué muestra la barra lateral. Los ajustes se aplican a todas las ventanas.

- :ui[sidebar.groupRefs] pone en carpetas los nombres con una `/`. Al principio está activado. :ui[sidebar.groupedRefsOnTop] muestra las carpetas antes que las demás ramas.
- :ui[sidebar.showStaleInfo] muestra qué ramas son obsoletas. :ui[sidebar.staleInterval] fija cuánto tiempo puede pasar una rama sin commits, 6 meses al principio.
- :ui[sidebar.remoteFilter] y :ui[sidebar.tagsFilter] limitan la lista a las más recientes, en :ui[sidebar.showNewest]. El límite cuenta para cada remoto por separado. Las etiquetas también se pueden ordenar en :ui[sidebar.sortBy]. Mientras filtras, se muestran todas las coincidencias.
- :ui[sidebar.autoArchive] se explica en [Revisión de ramas](/guide/branches/review/#auto-archive).

## Consulta también

- [Fetch, pull y push](/guide/branches/sync/)
- [Fusionar y hacer rebase](/guide/branches/merge-rebase/)
- [Revisión de ramas](/guide/branches/review/)
- [Worktrees](/guide/advanced/worktrees/)
