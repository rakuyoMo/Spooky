---
title: "Stashes"
description: "Guarda, aplica y examina stashes, y usa el stash automático."
---

Un stash aparta tus cambios locales sin hacer commit de ellos. Úsalo cuando necesites una copia de trabajo limpia por un momento, por ejemplo para cambiar de rama o hacer pull, y quieras recuperar tus cambios después.

Los stashes pertenecen al repositorio. No se hace push de ellos al remoto.

## Guardar un stash {#save}

1. Selecciona :ui[workspace.title > stash.saveMenu] (<kbd>⇧⌘S</kbd>), o haz clic en :ui[toolbar.saveStash] en la barra de herramientas.
2. Si quieres, describe los cambios en :ui[stash.message] para encontrar el stash más adelante.
3. Para apartar también los archivos nuevos, marca :ui[stash.includeUntracked]. Spooky recuerda esta elección.
4. Haz clic en :ui[stash.save].

Todos tus cambios van al stash, y la copia de trabajo vuelve a estar limpia. Si no hay nada que guardar, Spooky dice :ui[stash.error.noChanges]. Los archivos nuevos solo cuentan cuando :ui[stash.includeUntracked] está marcado.

Para guardar una copia de tus cambios y seguir trabajando en ellos, selecciona :ui[workspace.title > stash.snapshotMenu] (<kbd>⌃⇧⌘S</kbd>) en su lugar. El diálogo es el mismo, y la copia de trabajo se queda como está.

## Guardar algunos archivos en un stash {#partial}

Para apartar solo algunos archivos, selecciónalos en la copia de trabajo, haz clic derecho y selecciona :ui[stash.stashFile]{1="README.md"} o :ui[stash.stashItems]{1="3"} en el menú. Las opciones de instantánea que hay debajo dejan los archivos como están.

También puedes arrastrar los archivos a :ui[stash.title] en la barra lateral.

Los archivos nuevos que hayas seleccionado siempre van al stash, esté o no marcado :ui[stash.includeUntracked].

:::tip
Mantén pulsada <kbd>⌥</kbd> mientras el menú está abierto, y las opciones se convierten en versiones rápidas como :ui[stash.quickStashFile]{1="README.md"}. Guardan al instante, sin el diálogo, con un mensaje que escribe Git.
:::

## Ver los stashes {#view}

Haz clic en :ui[stash.title] en la barra lateral, o selecciona :ui[menu.view > stash.show] (<kbd>⌘3</kbd>).

La lista de la izquierda muestra primero el stash más reciente. Cada fila muestra :ui[stash.basedOn] con la rama desde la que se guardó el stash, la fecha y el mensaje. Para filtrar la lista, escribe en el campo de búsqueda de la barra de herramientas.

::screenshot[La vista de stashes. La lista de la izquierda muestra tres stashes, y Halfway through the units toggle está seleccionado. Sus detalles están a la derecha, con los botones Aplicar, Eliminar y Comparar visibles bajo la información del commit.]{name="work-stashes" frame="window" markers="33,36 84,35.5"}

1. La lista de stashes
2. :ui[stash.applyButton], :ui[stash.deleteButton] y :ui[history.diffTool]

Selecciona un stash para ver sus cambios a la derecha, dispuestos como los detalles de un commit. Deja el puntero sobre los detalles para mostrar los botones :ui[stash.applyButton], :ui[stash.deleteButton] y :ui[history.diffTool]. :ui[history.diffTool] abre el stash en una app de comparación.

## Aplicar un stash {#apply}

Aplicar devuelve los cambios de un stash a la copia de trabajo.

1. Selecciona :ui[workspace.title > stash.applyMenu] (<kbd>⌥⇧⌘S</kbd>), o haz clic en :ui[toolbar.applyStash] en la barra de herramientas. También puedes arrastrar un stash a :ui[workspace.title] o a la rama actual en la barra lateral.
2. Elige el stash en :ui[stash.picker]. En la vista de stashes, el stash seleccionado ya está elegido.
3. Configura las opciones:
   - :ui[stash.deleteAfterApply] elimina el stash una vez recuperados sus cambios.
   - :ui[stash.restoreIndex] vuelve a añadir al stage lo que estaba en el stage cuando guardaste el stash.
4. Haz clic en :ui[stash.apply].

Spooky recuerda ambas opciones para la próxima vez.

Si los cambios chocan con lo que hay ahora en la copia de trabajo, Spooky informa de :ui[stash.error.conflicts]. El stash se conserva, aunque :ui[stash.deleteAfterApply] esté marcado. Resuelve los conflictos como se describe en [Resolver conflictos](/guide/work/conflicts/).

Para recuperar un solo archivo, abre el stash y arrastra el archivo desde sus detalles a :ui[workspace.title] en la barra lateral.

## Eliminar stashes {#delete}

En la vista de stashes, haz clic derecho en un stash y selecciona :ui[stash.deleteNamed]{1="Halfway through the units toggle"} en el menú. Si hay varios stashes seleccionados, la opción es :ui[stash.deleteMultiple]{1="2"}. También puedes pulsar <kbd>⌘⌫</kbd>.

Spooky siempre pregunta antes. Para recuperar un stash después de eliminarlo, selecciona :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

## Stash automático {#auto-stash}

Algunas operaciones no pueden ejecutarse mientras tienes cambios locales, como cambiar de rama, hacer pull o fusionar. Cuando una de ellas queda bloqueada, Spooky pregunta si quieres guardar antes tus cambios en un stash.

::screenshot[Un diálogo que pregunta si se guardan en un stash los cambios locales que bloquean la operación. Tiene un campo para un mensaje opcional, una casilla para volver a aplicar los cambios cuando termine la operación y los botones Interrumpir, No hacer stash y Hacer stash de los cambios.]{name="work-auto-stash" frame="dialog"}

- :ui[stash.autoStash.confirm] guarda los cambios en un stash y ejecuta la operación.
- :ui[stash.autoStash.skip] ejecuta la operación sin guardar nada en un stash. Si tus cambios siguen bloqueándola, falla como habría fallado.
- :ui[stash.autoStash.abort] cancela la operación.

Marca :ui[stash.autoStash.reapply] para recuperar los cambios en cuanto termine la operación. Si no, el stash se queda en la lista, y puedes aplicarlo tú más adelante. Spooky recuerda esta elección.

Cuando cambias de rama con cambios en archivos con seguimiento, Spooky pregunta antes de empezar, aunque los cambios no fueran a estorbar.

Si algo sale mal por el camino, tus cambios se quedan en el stash, y Spooky te dice qué ha pasado.

Para que deje de preguntar, desactiva :ui[stash.offerAutoStash] en :ui[app.name > settings.title] › :ui[settings.general]. Consulta [Operaciones](/guide/settings/general/#operations).

## Consulta también

- [Copia de trabajo](/guide/work/working-copy/)
- [Resolver conflictos](/guide/work/conflicts/)
- [Ramas](/guide/branches/branches/)
