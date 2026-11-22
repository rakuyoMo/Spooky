---
title: "Detalles del commit"
description: "Examina los detalles de un commit, su conjunto de cambios, su árbol de archivos y el estado de su firma, compara revisiones y exporta archivos."
---

Selecciona un commit en el [historial](/guide/history/browse/) y la columna derecha muestra sus detalles: quién lo hizo y cuándo, el mensaje completo y los archivos que cambió.

## La cabecera {#header}

La barra de la parte superior muestra el hash corto del commit y los botones :ui[history.changeset] y :ui[history.tree]. Puedes seleccionar y copiar el hash. Bajo la barra, la cabecera muestra:

- :ui[history.author] y :ui[history.committer], con sus fechas. El avatar de la derecha es el del autor. Si otra persona hizo el commit, el avatar del committer está a su izquierda.
- :ui[history.refs], las ramas y etiquetas que apuntan al commit
- :ui[history.hash], el hash completo
- :ui[history.parentHash], una fila por cada padre
- :ui[history.treeHash]
- La firma, si el commit está firmado. Consulta [Firmas](#signatures).

Haz clic en la flecha de arriba a la derecha para contraer la cabecera y dejar el autor, la fecha y las referencias. Spooky recuerda tu elección. El mensaje completo va después de la cabecera.

### Botones de acción {#actions}

Deja el puntero sobre los detalles, y aparece una fila de botones en la línea que separa la cabecera del mensaje:

- :ui[history.rollback] abre el diálogo para restablecer la rama actual a este commit. Consulta [Restablecer a un commit anterior](/guide/history/rewrite/#reset).
- :ui[rewrite.revert.button] abre el diálogo para añadir un commit que deshace este. Consulta [Revertir un commit](/guide/history/rewrite/#revert).
- :ui[history.diffTool] abre todos los cambios del commit en tu herramienta de comparación. Consulta [Comparar en otra app](/guide/work/diff/#external).

:ui[history.rollback] y :ui[rewrite.revert.button] solo aparecen mientras la lista muestra la rama en la que estás.

## El conjunto de cambios {#changeset}

:ui[history.changeset] muestra los archivos que cambió el commit, ordenados por ruta. La línea que hay sobre la lista cuenta los archivos, las adiciones y las eliminaciones.

- Haz clic en la flecha que hay junto a un archivo para mostrar sus cambios. Para mostrar u ocultar los cambios de todos los archivos, haz clic en :ui[history.expandAll] o :ui[history.collapseAll] al principio de la línea que hay sobre la lista, o pulsa <kbd>⌃⌘→</kbd> o <kbd>⌃⌘←</kbd>.
- Haz clic en un archivo para seleccionarlo. Con <kbd>⇧</kbd> o <kbd>⌘</kbd> pulsada, el clic selecciona varios. <kbd>↑</kbd> <kbd>↓</kbd> mueven la selección.

Los archivos empiezan contraídos. Para que se abran solos, elige un número en :ui[history.autoExpand.title] en :ui[menu.view > history.diffs]. Un commit que no cambia más archivos que ese número abre todos los diffs. :ui[history.autoExpand.always] los abre siempre.

En un commit de fusión, :ui[history.mergeDiff] en :ui[app.name > settings.title] › :ui[settings.general] decide qué muestra el conjunto de cambios:

- :ui[history.mergeDiff.firstParent] (la opción predeterminada) muestra los cambios que la fusión trajo a la rama.
- :ui[history.mergeDiff.mergedFilePaths] muestra solo los archivos que difieren de todos los padres.
- :ui[history.mergeDiff.off] no muestra cambios.

Consulta [Historial y diffs](/guide/settings/general/#history).

Haz clic derecho en un archivo para:

- Copiar su ruta, o su ruta dentro del repositorio
- Ver el archivo como estaba en este commit, su blame o su historial. Consulta [Historial del archivo y blame](/guide/history/file-views/).
- Abrirlo en tu herramienta de comparación, comparado con el primer padre del commit
- Restaurarlo en la copia de trabajo a la versión de este commit. Consulta [Restaurar un archivo desde una revisión](/guide/history/file-views/#restore).
- Guardar en tu Mac la versión de este commit

Con varios archivos seleccionados, puedes abrirlos en tu herramienta de comparación, restaurarlos o exportarlos juntos.

## El árbol de archivos {#tree}

:ui[history.tree] muestra todos los archivos del repositorio como estaban en este commit, no solo los modificados. Haz clic en la flecha que hay junto a una carpeta para abrirla.

Haz clic derecho en un archivo o una carpeta para:

- Abrir el archivo en su app predeterminada, o en una app que elijas
- Ver el archivo, su blame o su historial
- Restaurarlo en la copia de trabajo a la versión de este commit
- Exportarlo, o guardarlo como un archivo zip

Abrir y ver solo funcionan con archivos. Con varios ítems seleccionados, puedes abrirlos, restaurarlos, exportarlos o archivarlos juntos. Los ítems exportados van a una carpeta que tú eliges. Si ya hay ítems con los mismos nombres, Spooky pregunta antes de sobrescribirlos.

## Detalles a página completa {#full-page}

Haz doble clic en un commit de la lista para dar a sus detalles toda la ventana. La columna izquierda muestra el commit, con la lista de archivos modificados debajo. La columna derecha muestra los cambios del archivo seleccionado.

- Haz clic en el hash corto de arriba a la izquierda para elegir otro commit. Haz doble clic en un commit de la lista para cambiar a él.
- Haz doble clic en un archivo, o pulsa <kbd>Retorno</kbd>, para abrir la versión de este commit en su app predeterminada.

Para volver al historial, selecciona :ui[menu.view > navigation.back] (<kbd>⌘[</kbd>), o haz clic en :ui[toolbar.previous] en la barra de herramientas.

## Varios commits {#multiple}

Selecciona más de un commit, y la columna derecha muestra cuántos son. Debajo están estos botones:

- :ui[rewrite.cherryPick.button] aplica los commits a la rama en la que estás. Mientras la lista muestra esa rama, el botón es :ui[rewrite.revert.button]. Consulta [Reescribir el historial](/guide/history/rewrite/).
- :ui[compare.submit] aparece cuando hay exactamente dos commits seleccionados. Muestra lo que cambió del commit más antiguo al más reciente. Mantén pulsada <kbd>⌥</kbd> para comparar en el otro sentido.

## Firmas {#signatures}

Los detalles comprueban la firma del commit que seleccionas. La cabecera expandida muestra la clave y el estado, como :ui[signature.good].

Para ver también las firmas en la lista, activa :ui[signature.verify] en las [opciones de visualización](/guide/history/browse/#view-options). Los commits firmados llevan entonces un punto al final de la fila:

- Verde: la firma es correcta.
- Rojo: la firma es incorrecta.
- Amarillo: cualquier otro estado, como una clave caducada o una firma que Spooky no puede comprobar.

Haz clic en el punto para ver la clave y el estado.

## Comparar dos revisiones {#compare}

Para ver qué cambió entre dos commits, ramas o etiquetas cualesquiera:

1. Selecciona :ui[menu.repository > compare.menu] en la barra de menús. O haz clic derecho en un commit y selecciona :ui[compare.menuFrom]{1="e2dda2bc"} para partir de él.
2. Rellena :ui[compare.base] y :ui[compare.target]. Los menús muestran tus ramas, ramas remotas y etiquetas. También puedes escribir un hash.
3. Haz clic en :ui[compare.submit].

La columna derecha muestra la comparación. :ui[compare.commits] muestra los commits que tiene la segunda revisión y no tiene la primera. :ui[history.changeset] muestra los cambios de la primera a la segunda. Para cerrarla, haz clic en × arriba a la derecha, o selecciona otro commit.

Con dos commits seleccionados, el menú ofrece directamente :ui[compare.menuPair]{1="e2dda2bc" 2="f6b437e0"}.

## Exportar archivos {#export}

Para guardar todos los archivos de un commit como estaban en ese momento:

1. Haz clic derecho en un commit y selecciona :ui[export.menuFrom]{1="e2dda2bc"} en el menú. :ui[menu.repository > export.menu] en la barra de menús parte del commit seleccionado.
2. Comprueba la revisión. Para obtener un único archivo zip, marca :ui[export.createArchive].
3. Haz clic en :ui[export.submit] y elige dónde guardar.

Sin archivo comprimido, obtienes una carpeta con el nombre del repositorio y el hash corto.

La exportación aparece en la [ventana Actividad](/guide/advanced/queue-activity/), donde puedes cancelarla.

## Guardar un parche {#patch}

Un parche es un archivo de texto con los cambios de un commit. Puedes aplicarlo en otro repositorio con `git am`.

1. Haz clic derecho en un commit y selecciona :ui[patch.menu]{1="e2dda2bc"} en el menú. Con varios commits seleccionados, la opción guarda un parche por cada uno.
2. Marca :ui[patch.omitPrefixes] para dejar fuera los `a/` y `b/` que preceden a cada ruta.
3. Haz clic en :ui[patch.save] y elige una carpeta.

Cada commit tiene su propio archivo, numerado del más antiguo al más reciente, como `0001-Add-a-theme-toggle-to-the-header.patch`. Cuando termina, el Finder se abre con los archivos seleccionados. El guardado también aparece en la ventana Actividad.

Mantén pulsada <kbd>⌥</kbd> en el menú para ver :ui[patch.quickMenu]{1="e2dda2bc"}. Guarda al instante en la carpeta del repositorio, con tu última elección de :ui[patch.omitPrefixes].

:::note[Repositorios de servidor]
Las exportaciones y los parches que guardas con :ui[patch.save] van a tu Mac. Un parche de guardado rápido va a la carpeta del repositorio en el servidor.
:::

## Copiar la información del commit {#copy}

Haz clic derecho en un commit para copiar:

- :ui[history.copyHash], el hash completo
- :ui[history.copyInfo], el hash corto y la primera línea del mensaje

Con varios commits seleccionados, obtienes una línea por cada uno.

## Consulta también

- [Explorar el historial](/guide/history/browse/)
- [Historial del archivo y blame](/guide/history/file-views/)
- [Reescribir el historial](/guide/history/rewrite/)
