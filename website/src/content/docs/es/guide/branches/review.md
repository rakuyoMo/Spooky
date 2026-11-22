---
title: "Revisión de ramas"
description: "Compara tus ramas locales con una rama base, encuentra las que puedes limpiar, sigue las sugerencias de archivado y archiva ramas automáticamente."
---

La revisión de ramas muestra tus ramas locales y compara cada una con una rama base. Indica qué ramas se pueden fusionar, cuáles darían conflictos, cuáles son obsoletas y cuáles ya no tienen su rama remota. Así decides qué fusionar, archivar o eliminar.

Para abrirla, haz clic en :ui[review.title] en la parte superior de la barra lateral, o selecciona :ui[menu.view > review.show] (<kbd>⌘5</kbd>).

::screenshot[La ventana de revisión de ramas. La rama base es main. La lista muestra seis ramas, de feature/csv-export a spike/radar-overlay, cada una con su estado de fusión, los commits por delante y por detrás, y la rama a la que sigue. feature/units-toggle está seleccionada, y los detalles de la derecha muestran sus commits y un botón de conflictos.]{name="branches-review" frame="window" markers="41.8,9 47.3,9 22,52 76,9"}

1. La rama base
2. El botón de filtro
3. Si la rama se puede fusionar sin conflictos
4. El botón de conflictos

## La lista {#list}

Elige la rama base en :ui[review.compareTo], en la parte superior de la lista. Al principio es la primera de `next`, `develop`, `dev`, `main` y `master` que tenga el repositorio; si no tiene ninguna, la rama en la que estás.

Cada rama ocupa una fila:

- Un icono a la izquierda indica si la rama se puede fusionar en la base sin conflictos o si los daría. Deja el puntero sobre él para ver los detalles.
- A la derecha, cuántos commits lleva la rama por delante y por detrás de la base. Pone :ui[review.comparing] mientras Spooky compara.
- La segunda línea muestra la rama remota a la que sigue, o :ui[review.noTracking]. Cuando la rama remota ya no existe, el nombre se pone rojo.
- Cuándo se actualizó la rama por última vez, y la pull request o merge request más reciente de la rama, con su número y un color según su estado.

## Filtrar y ordenar {#filter}

El botón de filtro, arriba a la derecha, muestra solo algunas de las ramas:

- :ui[review.filter.stale] y :ui[review.filter.active] separan las ramas según sean obsoletas o no. Obsoleta significa sin commits nuevos durante el tiempo fijado en los [ajustes de visualización](/guide/branches/branches/#filter) de la barra lateral, 6 meses al principio.
- :ui[review.filter.trackingError] muestra las ramas cuya rama remota ya no existe.
- :ui[review.filter.mergeable] y :ui[review.filter.conflicts] dependen de lo que pasaría al fusionar en la base.
- :ui[pr.filter.with] y :ui[pr.filter.without] dependen de las pull requests o merge requests abiertas. Necesitan una [cuenta de alojamiento](/guide/hosting/accounts/) para el remoto. Si no la hay, la lista lo indica.
- :ui[review.filter.none] vuelve a mostrar todas las ramas.

El botón de ajustes de visualización que hay al lado ordena la lista por :ui[review.sort.name] o :ui[review.sort.date], en orden :ui[review.sort.ascending] o :ui[review.sort.descending]. Spooky recuerda tanto el filtro como el orden.

Para buscar una rama por su nombre, escribe en el campo de búsqueda de la barra de herramientas.

## Detalles {#details}

Selecciona una rama para ver a la derecha cómo queda frente a la base. Arriba se muestran la rama y la base. Cuando la fusión daría conflictos, un botón que hay ahí muestra los archivos.

:ui[compare.commits] muestra los commits que ha hecho la rama desde que se separó de la base. :ui[history.changeset] muestra qué cambiaron esos commits. Encima de los dos, un resumen muestra :ui[review.summary.contributors], :ui[review.summary.updated], :ui[review.summary.tracking] y :ui[review.summary.mergeStatus].

Puedes seleccionar varias ramas a la vez, por ejemplo para archivarlas o eliminarlas juntas.

## Trabajar con las ramas {#actions}

Haz clic derecho en una rama para ver el mismo menú que en la barra lateral. Con varias ramas seleccionadas, el menú se aplica a todas.

Cuando una rama daría conflictos con la base, su menú tiene también :ui[review.resolveConflicts]. Spooky hace checkout de la rama y fusiona la base en ella. Después resuelves los conflictos en la rama. Consulta [Resolver conflictos](/guide/work/conflicts/).

Para eliminar ramas, selecciónalas y pulsa <kbd>⌘⌫</kbd>, o desliza una fila hacia la izquierda y haz clic en :ui[review.delete]. Spooky pregunta antes, igual que en la barra lateral.

## Sugerencias de archivado {#archive-suggestions}

Spooky sugiere [archivar](/guide/branches/branches/#archive) una rama local cuando:

- es obsoleta, o
- su pull request o merge request se fusionó, y la rama no tiene commits nuevos desde entonces.

Las ramas fijadas y las archivadas nunca se sugieren. Tampoco `main`, `master`, `trunk`, `dev`, `develop`, `next` ni las ramas que son la rama padre de otra.

Cuando hay sugerencias y el archivado automático está desactivado, aparece un botón con el número de ramas en la parte inferior de la barra lateral. Haz clic en él para abrir :ui[review.archive.title]:

1. Selecciona las ramas que quieres archivar, o selecciona :ui[menu.selectAll]. Al principio no hay nada seleccionado. Cada rama muestra por qué se sugiere: :ui[pr.archive.merged] o :ui[review.filter.stale].
2. Haz clic en :ui[review.archive.submit].

::screenshot[El diálogo para archivar ramas muestra tres ramas, cada una marcada como obsoleta, y una está seleccionada. Abajo está el interruptor para archivar ramas automáticamente.]{name="branches-archive" frame="dialog"}

Después, una nota en la parte inferior de la barra lateral dice cuántas ramas se han archivado, con un botón :ui[review.archived.undo]. <kbd>⌘Z</kbd> también funciona. :ui[activity.title] registra por qué se archivó cada rama.

## Archivar automáticamente {#auto-archive}

Spooky puede buscar ramas que archivar una vez al día. Cualquiera de estas opciones lo activa. Todas son el mismo ajuste:

- :ui[review.archive.auto] en el diálogo :ui[review.archive.title]
- :ui[sidebar.autoArchive] en los ajustes de visualización de la barra lateral
- :ui[settings.autoArchive] en :ui[app.name > settings.title] › :ui[settings.general] (consulta [Operaciones](/guide/settings/general/#operations))

Al principio está desactivado.

Una vez al día para cada repositorio, mientras trabajas en su ventana, Spooky busca sugerencias. Si hay alguna, abre el mismo diálogo. Ahí eliges las ramas que quieres archivar. Archives alguna o no, vuelve a comprobarlo un día después.

Para dejar fuera una rama, haz clic derecho en ella y selecciona :ui[review.skipAutoArchive], debajo del ítem de archivado del menú.

Cuando se archivan ramas de esta manera:

- Una notificación dice :ui[review.archived.notification]. El registro de :ui[activity.title] se llama :ui[review.autoArchive].
- Un punto junto a :ui[sidebar.archived] en la barra lateral marca las ramas que aún no has mirado. Haz clic en una y su marca desaparece al cabo de un momento. Para quitarlas todas, haz clic derecho en :ui[sidebar.archived] y selecciona :ui[sidebar.markAllReviewed].

## Consulta también

- [Ramas](/guide/branches/branches/)
- [Fusionar y hacer rebase](/guide/branches/merge-rebase/)
- [Pull requests y merge requests](/guide/hosting/pull-requests/)
- [Cuentas de alojamiento](/guide/hosting/accounts/)
