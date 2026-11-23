---
title: "Fusionar y hacer rebase"
description: "Fusiona ramas y haz rebase, consulta los conflictos antes de empezar, actualiza una rama desde su rama padre, y arrastra y suelta ramas en la barra lateral."
---

Tanto la fusión como el rebase traen los commits de otra rama a la rama en la que estás:

- Una fusión une los dos historiales, normalmente con un commit de fusión.
- Un rebase mueve tus commits para que queden después de los de la otra rama. El historial sigue siendo una línea recta, pero tus commits se reescriben.

Los dos se inician desde el menú :ui[workspace.title]. Para poner :ui[sync.merge] y :ui[sync.rebaseHead] en la barra de herramientas, selecciona :ui[menu.view > menu.customizeToolbar] y arrástralos a ella.

## Fusionar {#merge}

1. Selecciona :ui[workspace.title > sync.mergeMenu] (<kbd>⇧⌘M</kbd>). En la barra lateral, también puedes hacer clic derecho en la rama en la que estás y seleccionar :ui[workspace.mergeMenu] en el menú, o arrastrar otra rama sobre ella.
2. Elige qué fusionar en :ui[branch.target]: una rama local, una rama remota o una etiqueta. Al principio es el upstream de la rama en la que estás.
3. Elige cómo hacer el commit:
   - :ui[merge.squash] añade todos los cambios al stage para un único commit tuyo, sin commit de fusión.
   - :ui[merge.alwaysCommit] crea un commit de fusión aunque Git pudiera limitarse a avanzar tu rama.
   - :ui[merge.autoCommit] hace el commit de la fusión enseguida. Solo puedes desmarcarlo mientras :ui[merge.alwaysCommit] está seleccionado. En ese caso, los cambios fusionados esperan en la copia de trabajo a que hagas el commit.
4. Si la fusión fuera a dar conflictos, una línea debajo lo indica. Consulta [Consultar los conflictos antes](#preview).
5. Ajusta las opciones:
   - :ui[merge.verify] detiene la fusión salvo que el commit fusionado tenga una firma de confianza.
   - :ui[sync.skipHooks] omite esta vez los hooks de Git del repositorio.
6. Haz clic en :ui[sync.merge].

Spooky recuerda :ui[merge.alwaysCommit], :ui[merge.autoCommit] y :ui[merge.verify].

Si la fusión se detiene por conflictos, Spooky cambia a la copia de trabajo y muestra un aviso. Consulta [Resolver conflictos](/guide/work/conflicts/#banner).

<kbd>⌘Z</kbd> deshace una fusión. Si la fusión se detuvo por conflictos, deshacerla la cancela.

## Hacer rebase {#rebase}

1. Selecciona :ui[workspace.title > sync.rebaseMenu] (<kbd>⇧⌘R</kbd>). También puedes hacer clic derecho en la rama en la que estás y seleccionar :ui[workspace.rebaseMenu] en el menú.
2. Elige la rama sobre la que hacer rebase en :ui[branch.target]. Al principio es el upstream de la rama en la que estás.
3. Revisa la previsión y, si lo necesitas, selecciona :ui[sync.skipHooks].
4. Haz clic en :ui[sync.rebaseHead].

<kbd>⌘Z</kbd> deshace un rebase que ha terminado. Un rebase que se detiene por un conflicto no se puede deshacer: resuelve el conflicto y continúa, o cancélalo desde el aviso.

Para mover solo algunos de tus commits a otra base, consulta [Hacer rebase de commits en otra base](/guide/history/rewrite/#rebase-onto).

:::caution
El rebase reescribe tus commits. Si ya habías hecho push de ellos, el siguiente push tiene que ser un [push forzado](/guide/branches/sync/#force-push).
:::

## Cambios locales {#local-changes}

Una fusión necesita que tus archivos con seguimiento estén sin cambios. Los archivos nuevos solo estorban cuando la fusión los sobrescribiría.

El rebase y la actualización de una rama desde su rama padre necesitan una copia de trabajo sin ningún cambio, archivos nuevos incluidos.

Cuando los cambios locales impiden alguna de estas operaciones, Spooky te ofrece guardarlos antes en un stash. Consulta [Stash automático](/guide/work/stash/#auto-stash).

## Consultar los conflictos antes {#preview}

Antes de que empieces, los diálogos de fusión, rebase, pull y sincronización comprueban si las ramas entran en conflicto, y muestran el resultado en el propio diálogo:

- :ui[merge.checking] mientras Spooky las compara.
- Cuántos archivos tienen conflictos. Deja el puntero sobre la línea para ver cuáles son.
- :ui[merge.clean] o :ui[merge.unchanged].
- :ui[merge.unavailable] cuando la comprobación no ha funcionado. Deja el puntero sobre la línea para ver por qué.

El diálogo de fusión no muestra :ui[merge.clean] ni :ui[merge.unchanged]. Los demás muestran todos los resultados.

## Versiones rápidas {#quick}

Mantén pulsada <kbd>⌥</kbd>, y :ui[sync.merge] y :ui[sync.rebaseHead], una vez añadidos a la barra de herramientas, se convierten en :ui[sync.quickMerge] y :ui[sync.quickRebase]. Se ejecutan enseguida, sin el diálogo:

- :ui[sync.quickMerge] fusiona el upstream de la rama en la que estás.
- :ui[sync.quickRebase] hace rebase de la rama en la que estás sobre su upstream.

La fusión rápida usa las opciones de commit y de firma que elegiste la última vez en el diálogo de fusión. Las dos te ofrecen guardar los cambios locales en un stash, igual que los diálogos.

Los ítems del menú de la barra lateral cambian de la misma manera. Por ejemplo, :ui[workspace.mergeMenu] pasa a ser :ui[sync.quickMergeInto]{1="origin/main" 2="main"}.

## Actualizar una rama desde su rama padre {#update}

Cuando una rama tiene [rama padre](/guide/branches/branches/#parent), la actualización trae los commits nuevos de la rama padre.

1. Haz clic derecho en la rama y selecciona :ui[branch.updateNamed]{1="feature/units-toggle"} en el menú. Cuando ves el historial de la rama y la rama padre tiene commits nuevos, el aviso :ui[history.parentBanner.title] tiene también un botón :ui[review.updateBranch.menu].
2. Revisa :ui[review.update.branch]. La línea de debajo dice cuántos commits llegarán de la rama padre.
3. En :ui[review.update.strategy], selecciona :ui[review.update.merge] o :ui[review.update.rebase]. Con :ui[review.update.merge], también puedes seleccionar :ui[merge.alwaysCommit].
4. Revisa la previsión: :ui[review.update.conflicts], :ui[review.update.clean] o :ui[review.update.noChanges].
5. Ajusta las opciones: :ui[merge.verify] (solo para la fusión) y :ui[sync.skipHooks].
6. Haz clic en :ui[review.update.button].

Spooky hace primero checkout de la rama, y después fusiona o hace rebase. La actualización solo está disponible cuando la rama padre tiene commits que la rama no tiene, y no hay ninguna otra operación en curso.

En la rama en la que estás, :ui[branch.mergeWith]{1="main"} y :ui[branch.rebaseOn]{1="main"} del menú de la barra lateral abren los diálogos de fusión y de rebase con la rama padre ya elegida.

:::tip
Mantén pulsada <kbd>⌥</kbd> con el menú abierto, y :ui[branch.updateNamed]{1="feature/units-toggle"} se convierte en :ui[branch.quickUpdateNamed]{1="feature/units-toggle"}. Fusiona la rama padre enseguida, sin el diálogo.
:::

## Arrastrar y soltar {#drag-and-drop}

Muchas operaciones con ramas empiezan arrastrando en la barra lateral. Mientras arrastras, la etiqueta que hay junto al puntero dice qué va a pasar. Detente un momento sobre una carpeta o un remoto contraídos, y se abren.

| Arrastra | Sobre | Qué pasa |
|---|---|---|
| Una rama local | :ui[workspace.title] o la rama en la que estás | El diálogo de fusión. Mantén pulsada <kbd>⌥</kbd> para el diálogo de rebase. |
| Una rama remota | :ui[workspace.title] o la rama en la que estás | El diálogo de pull |
| Una rama remota, con <kbd>⌥</kbd> pulsada | La rama en la que estás | Pasa a ser el upstream de tu rama. |
| Una rama local, una etiqueta o un commit | :ui[branch.group] | El diálogo para crear una rama a partir de ese elemento |
| Una rama remota | :ui[branch.group] | El diálogo para seguirla |
| Una rama local | Un remoto | El diálogo de publicación |
| Una rama local | Una rama remota | El diálogo :ui[sync.pushBranch] |
| Una rama local o un commit | :ui[sidebar.tags] o una carpeta de etiquetas | El diálogo para crear una etiqueta |
| Una etiqueta | Un remoto | El diálogo para publicar la etiqueta |
| Una rama local | :ui[sidebar.pinned] o :ui[sidebar.archived] | La rama se fija o se archiva. |
| Una rama local | :ui[worktree.group] | El diálogo para crear un worktree para ella |

Para mover una rama a una carpeta, arrástrala sobre la carpeta. La rama pasa a llamarse como la carpeta más la última parte de su nombre, sin ningún diálogo. Una rama remota solo puede moverse a carpetas de su propio remoto. Para sacar una rama de su carpeta, arrástrala al borde superior o inferior de la lista. Puedes deshacer el cambio de nombre con <kbd>⌘Z</kbd>.

También puedes arrastrar commits desde el historial a :ui[workspace.title] o a la rama en la que estás para hacer cherry-pick de ellos. Mantén pulsada <kbd>⌥</kbd> para revertirlos. Consulta [Hacer cherry-pick de un commit](/guide/history/rewrite/#cherry-pick). Arrastra ahí un solo archivo del conjunto de cambios de un commit, y solo los cambios de ese archivo se aplican a la copia de trabajo, sin añadirlos al stage.

## Consulta también

- [Resolver conflictos](/guide/work/conflicts/)
- [Reescribir el historial](/guide/history/rewrite/)
- [Fetch, pull y push](/guide/branches/sync/)
- [Ramas](/guide/branches/branches/)
