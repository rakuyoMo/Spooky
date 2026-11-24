---
title: "Atajos de teclado"
description: "Consulta todos los atajos de teclado de Spooky."
---

Los ítems de menú muestran su atajo al lado. Esta página los reúne todos, junto con las teclas que funcionan en sitios concretos, como el área de commit, las listas y los diálogos. Los símbolos se explican en [Atajos de teclado](/guide/#shortcuts).

Un atajo solo funciona mientras su ítem de menú está disponible. Cuando un ítem está atenuado, su atajo no hace nada.

## Menús {#menus}

### App y ventanas {#app-windows}

| Atajo | Ítem de menú |
|---|---|
| <kbd>⌘,</kbd> | :ui[app.name > settings.title] |
| <kbd>⌘H</kbd> | :ui[app.name > menu.hide] |
| <kbd>⌥⌘H</kbd> | :ui[app.name > menu.hideOthers] |
| <kbd>⌘Q</kbd> | :ui[app.name > menu.quit] |
| <kbd>⌘N</kbd> | :ui[menu.file > menu.newWindow] |
| <kbd>⌘T</kbd> | :ui[menu.file > menu.newTab] |
| <kbd>⌘W</kbd> | :ui[menu.file > menu.closeWindow] |
| <kbd>⌃⌘F</kbd> | :ui[menu.view > menu.fullscreen] |
| <kbd>⌘M</kbd> | :ui[menu.window > menu.minimize] |
| <kbd>⌃⌘0</kbd> | :ui[menu.window > activity.title] |
| <kbd>⌘?</kbd> | :ui[menu.help > help.help] |

### Repositorios {#repositories}

| Atajo | Ítem de menú |
|---|---|
| <kbd>⌘O</kbd> | :ui[menu.file > action.openLocal] |
| <kbd>⌃⌘C</kbd> | :ui[menu.file > clone.menu] |
| <kbd>⇧⌘A</kbd> | :ui[menu.file > quickActions.menu] |
| <kbd>⌃⌘R</kbd> | :ui[menu.view > menu.showRepositories] |

### Vistas {#views}

| Atajo | Ítem de menú |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.view > menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.view > menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[menu.view > stash.show] |
| <kbd>⌘4</kbd> | :ui[menu.view > pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[menu.view > review.show] |
| <kbd>⌘6</kbd> | :ui[menu.view > reflog.show] |
| <kbd>⌘0</kbd> | :ui[menu.view > history.showHead] |
| <kbd>⌘[</kbd> | :ui[menu.view > navigation.back] |
| <kbd>⌘]</kbd> | :ui[menu.view > navigation.forward] |
| <kbd>⌘R</kbd> | :ui[menu.view > action.refresh] |
| <kbd>⌃⌘T</kbd> | :ui[menu.view > files.statusMenu > working.tree] |
| <kbd>⌃⌘L</kbd> | :ui[menu.view > files.statusMenu > working.list] |
| <kbd>⌃⌘M</kbd> | :ui[menu.view > files.statusMenu > files.showNonModified] |
| <kbd>⌃⌘I</kbd> | :ui[menu.view > files.statusMenu > files.showIgnored] |
| <kbd>⌃⌘G</kbd> | :ui[menu.view > history.title > history.showGraph] |
| <kbd>⌃⌥⌘C</kbd> | :ui[menu.view > history.title > history.compareBranches] |
| <kbd>⌃⌘→</kbd> | :ui[menu.view > history.diffs > history.expandAll] |
| <kbd>⌃⌘←</kbd> | :ui[menu.view > history.diffs > history.collapseAll] |

### Edición y búsqueda {#edit}

| Atajo | Ítem de menú |
|---|---|
| <kbd>⌘Z</kbd> | :ui[menu.edit > menu.undo] |
| <kbd>⇧⌘Z</kbd> | :ui[menu.edit > menu.redo] |
| <kbd>⌘X</kbd> | :ui[menu.edit > menu.cut] |
| <kbd>⌘C</kbd> | :ui[menu.edit > menu.copy] |
| <kbd>⌘V</kbd> | :ui[menu.edit > menu.paste] |
| <kbd>⌥⇧⌘V</kbd> | :ui[menu.edit > menu.pasteAndMatchStyle] |
| <kbd>⌘⌫</kbd> | :ui[menu.edit > menu.delete] |
| <kbd>⌘A</kbd> | :ui[menu.edit > menu.selectAll] |
| <kbd>⇧⌘W</kbd> | :ui[menu.edit > commit.reformatParagraph] |
| <kbd>⌘F</kbd> | :ui[menu.edit > menu.find > action.find] |
| <kbd>⌥⌘F</kbd> | :ui[menu.edit > menu.find > action.search] |
| <kbd>⌘G</kbd> | :ui[menu.edit > menu.find > menu.findNext] |
| <kbd>⇧⌘G</kbd> | :ui[menu.edit > menu.find > menu.findPrevious] |
| <kbd>⌘E</kbd> | :ui[menu.edit > menu.find > menu.useSelectionForFind] |
| <kbd>⌘J</kbd> | :ui[menu.edit > menu.find > menu.jumpToSelection] |
| <kbd>⌘:</kbd> | :ui[menu.edit > menu.spelling > menu.showSpelling] |
| <kbd>⌘;</kbd> | :ui[menu.edit > menu.spelling > menu.checkDocument] |

- Consulta [Deshacer y rehacer](/guide/work/undo/#undo) para saber qué puede deshacer :ui[menu.undo].
- :ui[menu.delete] elimina también lo que está seleccionado en algunas listas. Consulta [Listas](#lists).
- Tanto :ui[action.find] como :ui[action.search] ponen el cursor en el campo de búsqueda de la barra de herramientas. Consulta [Buscar y filtrar](/guide/history/browse/#search) y [Buscar un archivo](/guide/work/working-copy/#search).
- :ui[commit.reformatParagraph] funciona en el mensaje de commit. Consulta [Escribir el mensaje](/guide/work/commit/#write).

### Ramas y sincronización {#sync}

| Atajo | Ítem de menú |
|---|---|
| <kbd>⌘B</kbd> | :ui[menu.repository > branch.createMenu] |
| <kbd>⇧⌘T</kbd> | :ui[menu.repository > tag.createMenu] |
| <kbd>⌃⌘P</kbd> | :ui[menu.repository > pr.create.menu] |
| <kbd>⇧⌘F</kbd> | :ui[menu.repository > sync.fetchMenu] |
| <kbd>⌥⇧⌘F</kbd> | :ui[menu.repository > sync.quickFetch] |
| <kbd>⇧⌘P</kbd> | :ui[menu.repository > sync.pullMenu] |
| <kbd>⌥⇧⌘P</kbd> | :ui[menu.repository > sync.quickPull] |
| <kbd>⇧⌘Y</kbd> | :ui[menu.repository > sync.syncMenu] |
| <kbd>⌥⇧⌘Y</kbd> | :ui[menu.repository > sync.quickSync] |
| <kbd>⇧⌘U</kbd> | :ui[menu.repository > sync.pushMenu] |
| <kbd>⌥⇧⌘U</kbd> | :ui[menu.repository > sync.quickPushMenu] |
| <kbd>⌃⌘U</kbd> | :ui[menu.repository > sync.forcePushMenu] |
| <kbd>⇧⌘B</kbd> | :ui[workspace.title > rewrite.checkout.menu] |
| <kbd>⇧⌘M</kbd> | :ui[workspace.title > sync.mergeMenu] |
| <kbd>⌥⇧⌘M</kbd> | :ui[workspace.title > sync.quickMerge] |
| <kbd>⇧⌘R</kbd> | :ui[workspace.title > sync.rebaseMenu] |
| <kbd>⌥⇧⌘R</kbd> | :ui[workspace.title > sync.quickRebase] |
| <kbd>⌃⇧⌘R</kbd> | :ui[workspace.title > rewrite.rebaseOnto.menu] |

Los ítems con <kbd>⌥⇧⌘</kbd> son versiones rápidas. Ocupan el lugar del ítem que tienen encima mientras mantienes pulsada <kbd>⌥</kbd> con el menú abierto. Se ejecutan enseguida, sin diálogo. Sus atajos funcionan sin abrir el menú. Consulta las versiones rápidas en [Fetch, pull y push](/guide/branches/sync/#quick) y en [Fusionar y hacer rebase](/guide/branches/merge-rebase/#quick).

### Cambios y commits {#changes}

| Atajo | Ítem de menú |
|---|---|
| <kbd>⇧⌘C</kbd> | :ui[workspace.title > working.commitMenu] |
| <kbd>⇧⌘E</kbd> | :ui[workspace.title > working.stageAllMenu] |
| <kbd>⌥⇧⌘E</kbd> | :ui[workspace.title > working.unstageAllMenu] |
| <kbd>⇧⌘⌫</kbd> | :ui[workspace.title > working.discardMenu] |
| <kbd>⇧⌘S</kbd> | :ui[workspace.title > stash.saveMenu] |
| <kbd>⌥⇧⌘S</kbd> | :ui[workspace.title > stash.applyMenu] |
| <kbd>⌃⇧⌘S</kbd> | :ui[workspace.title > stash.snapshotMenu] |
| <kbd>⌃⇧⌘D</kbd> | :ui[workspace.title > externalTool.compare > externalTool.compare.workingTreeToBase] |
| <kbd>⇧⌘D</kbd> | :ui[menu.repository > externalTool.openDiffTool] |

## Mantener pulsada Opción {#option}

Mantener pulsada <kbd>⌥</kbd> cambia algunos botones y menús. Suéltala, y vuelven a como estaban.

| Dónde | Qué cambia |
|---|---|
| Los botones de fetch, pull, push, sincronización, fusión y rebase de la barra de herramientas | Se convierten en versiones rápidas. Consulta [Fetch, pull y push](/guide/branches/sync/#quick). |
| El área de commit, mientras no se edita ninguno de los dos campos del mensaje | Pasa a enmendar el último commit. Consulta [Enmendar el último commit](/guide/work/commit/#amend). |
| :ui[working.stageAll] encima de la lista de archivos, mientras solo algunos cambios están en el stage | Se convierte en :ui[working.unstageAll]. Consulta [Añadir archivos enteros al stage](/guide/work/diff/#stage-file). |
| El menú de los archivos de la copia de trabajo | Los ítems de stash se convierten en versiones rápidas. Consulta [Guardar algunos archivos en un stash](/guide/work/stash/#partial). |
| El menú de un submódulo | El fetch y la actualización se convierten en versiones rápidas. Consulta [Hacer fetch y actualizar](/guide/advanced/submodules/#update). |
| El menú de una rama con rama padre | La actualización desde la rama padre se convierte en una versión rápida. Consulta [Actualizar una rama desde su rama padre](/guide/branches/merge-rebase/#update). |
| El menú de un commit | Guardar un parche se convierte en una versión rápida. Con dos commits seleccionados, la comparación va en el otro sentido. Consulta [Guardar un parche](/guide/history/commit-details/#patch). |
| :ui[compare.submit] con dos commits seleccionados | Compara en el otro sentido. Consulta [Varios commits](/guide/history/commit-details/#multiple). |
| Arrastrar | Consulta [Arrastrar con Opción](#drag). |

## Área de commit {#commit-area}

| Teclas | Qué hacen |
|---|---|
| <kbd>↩</kbd> o <kbd>Tab</kbd> en el asunto | Pasa a la descripción |
| <kbd>Tab</kbd> en la descripción | Pasa a la lista de archivos |
| <kbd>⇧Tab</kbd> en la descripción | Vuelve al asunto |
| <kbd>⌘↩</kbd> mientras escribes en el mensaje | Hace clic en el botón principal del área de commit, como :ui[working.commit]. <kbd>Intro</kbd> en un teclado numérico hace lo mismo. |
| <kbd>⌥⌘↩</kbd> mientras no se edita ninguno de los dos campos del mensaje | Enmienda el último commit. Consulta [Enmendar el último commit](/guide/work/commit/#amend). |
| <kbd>↑</kbd> <kbd>↓</kbd>, <kbd>↩</kbd>, <kbd>Esc</kbd> en la lista de autocompletado | Eligen una coincidencia, la insertan y cierran la lista |

Consulta [Hacer commit de los cambios](/guide/work/commit/).

## Lista de archivos {#file-list}

Estas teclas funcionan en la lista de archivos de la copia de trabajo:

| Teclas | Qué hacen |
|---|---|
| <kbd>Espacio</kbd> | Añade al stage o quita del stage los archivos seleccionados. Con :ui[files.spacebar] en :ui[files.spacebar.quickLook], los muestra en Vista Rápida. Consulta [Lista de archivos](/guide/settings/general/#file-list). |
| <kbd>⌘⌫</kbd> | Traslada los archivos seleccionados a la papelera |
| <kbd>⇧Tab</kbd> | Vuelve a la descripción del mensaje de commit |

## Líneas de un diff {#diff-lines}

En la copia de trabajo, pulsa <kbd>Tab</kbd> hasta que los números de línea de un fragmento tengan el foco del teclado. Después:

| Teclas | Qué hacen |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Pasan de una línea seleccionable a otra |
| <kbd>Espacio</kbd> | Selecciona la línea o anula su selección |
| <kbd>Tab</kbd> o <kbd>⇧Tab</kbd> | Sale de los números de línea |

Con el ratón, mantén pulsada <kbd>⇧</kbd> y haz clic en un número de línea para seleccionar todas las líneas intermedias. Consulta [Añadir líneas al stage](/guide/work/diff/#lines).

## Listas {#lists}

| Dónde | Teclas | Qué hacen |
|---|---|---|
| La lista de commits del historial | <kbd>⌘C</kbd> | Copia los hashes completos de los commits seleccionados |
| El conjunto de cambios de un commit | <kbd>↑</kbd> <kbd>↓</kbd> | Mueven la selección |
| Los archivos cambiados en los detalles a página completa | <kbd>↩</kbd> | Abre los archivos seleccionados en sus apps predeterminadas |
| El árbol de archivos de un commit | <kbd>↩</kbd> | Abre o cierra la carpeta seleccionada |
| El historial del archivo | <kbd>↩</kbd> | Abre el commit seleccionado en los detalles a página completa |
| La barra lateral | <kbd>⌘⌫</kbd> | Elimina las ramas, las etiquetas, el remoto o el submódulo seleccionados, después de preguntar |
| El campo de filtro de la barra lateral | <kbd>Esc</kbd> | Vacía el campo |
| Los stashes | <kbd>⌘⌫</kbd> | Elimina los stashes seleccionados, después de preguntar |
| La revisión de ramas | <kbd>⌘⌫</kbd> | Elimina las ramas seleccionadas, después de preguntar |
| La ventana Repositorios | <kbd>↩</kbd> | Renombra la entrada seleccionada |
| La ventana Repositorios | <kbd>⌫</kbd> o <kbd>⌦</kbd> | Quita las entradas seleccionadas. Consulta [Eliminar repositorios](/guide/repositories/manager/#delete). |
| La ventana que se muestra al arrancar | <kbd>↩</kbd> | Abre el repositorio seleccionado. Consulta [Seguir donde lo dejaste](/guide/repositories/navigation/#restore). |
| La conversación de una pull request | <kbd>↩</kbd> | Abre el commit seleccionado |
| La conversación de una pull request | <kbd>⌘S</kbd> | Hace clic en :ui[pullRequests.addComment] |
| :ui[settings.themes] en Ajustes | <kbd>↩</kbd> | Renombra el tema seleccionado |
| :ui[settings.appIcon.label] en Ajustes | Teclas de flecha, <kbd>Espacio</kbd> | Pasan de un icono a otro, y usan aquel en el que estás |
| :ui[settings.sshHosts] en Ajustes | <kbd>↩</kbd> | Abre el alias seleccionado para editarlo |

En las listas en las que puedes seleccionar varios ítems, hacer clic con <kbd>⇧</kbd> pulsada selecciona un intervalo. Hacer clic con <kbd>⌘</kbd> pulsada añade o quita un solo ítem. En la barra lateral, haz clic con <kbd>⌘</kbd> pulsada en ramas y etiquetas para ver su historial junto. Consulta [Abrir el historial](/guide/history/browse/#open).

Mantén pulsada <kbd>⌘</kbd> y haz doble clic en una rama que tiene checkout en otro worktree. Ese worktree se abre en una pestaña nueva. Consulta [Hacer checkout de una rama](/guide/branches/branches/#checkout).

## Acciones rápidas {#quick-actions}

Estas teclas funcionan en el panel de [Acciones rápidas](/guide/repositories/navigation/#quick-actions):

| Teclas | Qué hacen |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Mueven la selección |
| <kbd>↩</kbd> | Ejecuta la acción predeterminada del ítem seleccionado |
| <kbd>Tab</kbd>, o <kbd>→</kbd> al final del texto | Muestra todas las acciones del ítem seleccionado |
| <kbd>←</kbd> sin texto, o <kbd>⇧Tab</kbd> | Vuelve desde la lista de acciones |
| <kbd>Esc</kbd> | Borra el texto. Sin texto, vuelve desde la lista de acciones o cierra el panel. |

## Diálogos {#dialogs}

En un diálogo, <kbd>↩</kbd> hace clic en el botón resaltado. <kbd>Esc</kbd> hace clic en el botón que cancela. Si un diálogo no tiene ese botón, <kbd>Esc</kbd> también hace clic en el botón resaltado.

## Arrastrar con Opción {#drag}

Mantén pulsada <kbd>⌥</kbd> al soltar para hacer otra cosa:

| Arrastra | Sobre | Sin <kbd>⌥</kbd> | Con <kbd>⌥</kbd> |
|---|---|---|---|
| Una rama local | :ui[workspace.title] o la rama en la que estás | El diálogo de fusión | El diálogo de rebase |
| Una rama remota | La rama en la que estás | El diálogo de pull | Pasa a ser el upstream de tu rama. |
| Commits del historial | :ui[workspace.title] o la rama en la que estás | Hace cherry-pick de ellos | Los revierte |
| Commits en el historial | Otro commit de la lista | Los combina en ese commit | Los incorpora (fixup) |

Consulta [Arrastrar y soltar](/guide/branches/merge-rebase/#drag-and-drop) y [Combinar, incorporar, eliminar y mover](/guide/history/rewrite/#interactive).

## Consulta también

- [Ventanas y navegación](/guide/repositories/navigation/)
- [Hacer commit de los cambios](/guide/work/commit/)
- [Revisar y añadir cambios al stage](/guide/work/diff/)
- [Fusionar y hacer rebase](/guide/branches/merge-rebase/)
