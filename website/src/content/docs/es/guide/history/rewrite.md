---
title: "Reescribir el historial"
description: "Revierte commits, haz cherry-pick de ellos y restablece ramas, haz rebase interactivo y enmienda commits anteriores."
---

La mayoría de los comandos de esta página parten de la lista del [historial](/guide/history/browse/): haz clic derecho en un commit, o selecciona varios antes. Revertir y hacer cherry-pick añaden commits nuevos. El resto reescriben commits que ya existen.

:::caution
Los commits reescritos reciben hashes nuevos. Si ya habías hecho push de ellos, tu rama y su upstream divergen, y para volver a hacer push hace falta un push forzado. Quien ya tenga los commits antiguos tendrá que reconciliar su historial. Consulta [Push forzado](/guide/branches/sync/#force-push).
:::

Salvo hacer cherry-pick y restablecer, estos comandos solo aparecen en el menú de un commit mientras la lista muestra únicamente la rama en la que estás. Para llegar ahí, selecciona :ui[menu.view > history.showHead] (<kbd>⌘0</kbd>), o haz clic en la rama en la barra lateral.

::screenshot[El menú contextual del commit 2daa6982 mientras la lista muestra la rama en la que estás. Entre sus opciones están las de restablecer, revertir y hacer rebase en otra base, seguidas de las de enmendar, editar, editar el mensaje y eliminar este commit.]{name="history-commit-menu" frame="closeup"}

## Revertir un commit {#revert}

Revertir añade un commit que deshace los cambios de uno anterior. El commit anterior sigue en el historial, así que esta es la forma segura de retirar algo de lo que ya hiciste push.

1. Haz clic derecho en el commit y selecciona :ui[rewrite.menu.revert]{1="e2dda2bc"} en el menú. Con varios commits seleccionados, la opción es :ui[rewrite.menu.revertMany]{1="3"}.
2. :ui[rewrite.revert.commit] está activado de forma predeterminada, así que cada commit revertido recibe un commit propio. Desactívalo para dejar los cambios en la copia de trabajo. Spooky recuerda esta elección.
3. Haz clic en :ui[rewrite.revert.button].

Varios commits se revierten del más reciente al más antiguo. Para revertir un commit de fusión, elige su :ui[rewrite.mainline]: el padre cuyo lado cuenta como línea principal. Un commit de fusión solo se puede revertir por separado.

Los detalles del commit y la [selección múltiple](/guide/history/commit-details/#multiple) también tienen un botón :ui[rewrite.revert.button].

## Hacer cherry-pick de un commit {#cherry-pick}

Hacer cherry-pick copia los cambios de commits de otra rama en la rama en la que estás, como commits nuevos.

1. Haz clic en la otra rama en la barra lateral para ver su historial.
2. Haz clic derecho en el commit y selecciona :ui[rewrite.menu.cherryPick]{1="e2dda2bc"} en el menú. Con varios commits seleccionados, la opción es :ui[rewrite.menu.cherryPickMany]{1="3"}, y también puedes hacer clic en :ui[rewrite.cherryPick.button] a la derecha.
3. Elige las opciones. Spooky las recuerda:
   - :ui[rewrite.cherryPick.commit] (activado de forma predeterminada) hace commit de cada uno. Desactívalo para aplicar los cambios solo a la copia de trabajo.
   - :ui[rewrite.cherryPick.fastForward] mueve tu rama al commit en lugar de copiarlo, cuando tu rama está en el padre del commit. Solo se aplica mientras la primera opción está activada.
4. Haz clic en :ui[rewrite.cherryPick.button].

Los commits se aplican del más antiguo al más reciente. Un commit de fusión necesita una :ui[rewrite.mainline], como al revertir.

Mientras la lista muestra la rama en la que estás, la opción solo aparece para los commits del upstream de los que aún no has hecho pull.

También puedes arrastrar commits desde la lista a :ui[workspace.title] o a la rama en la que estás en la barra lateral. Mantén pulsada <kbd>⌥</kbd> al soltar para revertirlos.

## Restablecer a un commit anterior {#reset}

Restablecer mueve la rama en la que estás a otro commit. Los commits posteriores salen de la rama.

1. Haz clic derecho en el commit y selecciona :ui[rewrite.menu.reset]{1="e2dda2bc"} en el menú. También puedes hacer clic en :ui[history.rollback] en los detalles del commit, o seleccionar :ui[workspace.title > rewrite.reset.menu] en la barra de menús.
2. Comprueba :ui[rewrite.revision]. Puedes elegir una rama, una rama remota o una etiqueta, o escribir un hash. El diálogo muestra los commits que saldrán de la rama.
3. Elige un :ui[rewrite.reset.mode]:
   - :ui[rewrite.reset.soft] deja el índice y la copia de trabajo como están. Los cambios de los commits que salen se quedan en el stage.
   - :ui[rewrite.reset.mixed] restablece el índice y conserva la copia de trabajo. Esos cambios quedan fuera del stage.
   - :ui[rewrite.reset.hard] restablece las dos. Se descartan los cambios sin commit y los cambios de los commits que salen.
4. Haz clic en :ui[rewrite.reset.button].

El diálogo empieza siempre en :ui[rewrite.reset.soft]. Restablecer no ofrece guardar tus cambios en un stash.

:::caution
:ui[rewrite.reset.hard] descarta los cambios sin commit de los archivos con seguimiento. El diálogo te avisa cuando los hay. <kbd>⌘Z</kbd> los recupera, pero solo hasta que sales de Spooky.
:::

## Hacer rebase de commits en otra base {#rebase-onto}

:ui[rewrite.rebaseOnto] mueve commits para que queden encima de un commit distinto.

- Para mover todo un tramo de tu rama, selecciona :ui[workspace.title > rewrite.rebaseOnto.menu] en la barra de menús. Rellena :ui[rewrite.rebaseOnto.current] y :ui[rewrite.rebaseOnto.new]. Los commits posteriores a la base actual se vuelven a aplicar encima de la nueva.
- Para mover solo algunos commits, selecciónalos y haz clic derecho. Selecciona :ui[rewrite.menu.rebaseOntoMany]{1="3"} en el menú, o :ui[rewrite.menu.rebaseOnto]{1="e2dda2bc"} para un solo commit, y rellena :ui[rewrite.rebaseOnto.new]. Los commits del mismo tramo que no seleccionaste se quitan de la rama.

Ninguna de las dos bases puede ser el commit del que tienes hecho checkout. El diálogo muestra los commits que se van a reescribir, y te avisa cuando de algunos ya se ha hecho push o están en otras ramas. :ui[sync.skipHooks] omite esta vez el hook pre-rebase del repositorio. Haz clic en :ui[rewrite.rebaseOnto.button] para empezar.

Para hacer rebase de una rama sobre otra rama, consulta [Hacer rebase](/guide/branches/merge-rebase/#rebase).

## Combinar, incorporar, eliminar y mover {#interactive}

Estos comandos reescriben una serie de commits de la rama en la que estás. Selecciona los commits, haz clic derecho y selecciona:

- :ui[rewrite.menu.squashMany]{1="3"} para combinarlos en el más antiguo. Sus mensajes se combinan, y la lista selecciona después el commit nuevo.
- :ui[rewrite.menu.fixupMany]{1="3"} para incorporarlos al más antiguo y conservar solo su mensaje.
- :ui[rewrite.menu.deleteMany]{1="3"} para quitarlos de la rama. Con un solo commit seleccionado, :ui[rewrite.menu.delete]{1="e2dda2bc"} hace lo mismo.

También puedes arrastrar commits dentro de la lista:

- Suéltalos sobre otro commit para combinarlos con él. Mantén pulsada <kbd>⌥</kbd> al soltar para incorporarlos con fixup. La etiqueta del punto de destino dice :ui[rewrite.squash.button] o :ui[rewrite.fixup.button].
- Suéltalos entre dos filas para moverlos ahí. La etiqueta dice :ui[branch.moveHere].

En todos estos casos, Spooky pregunta antes de reescribir nada. El diálogo muestra todos los commits que se van a reescribir, con lo que le pasa a cada uno, como :ui[rewrite.note.squash] o :ui[rewrite.note.drop]. Una señal de advertencia amarilla marca los commits de los que ya se ha hecho push o que están en otras ramas, y una advertencia sobre la lista lo explica. Eliminar commits que ya están en el upstream hace antes una pregunta más.

::screenshot[El diálogo que pregunta antes de combinar dos commits en 10e44ab8. Dos advertencias en la parte superior indican que algunos de los commits ya están en la rama upstream o en otras ramas. La lista de debajo muestra los cuatro commits que se reescriben, con lo que le pasa a cada uno. El commit del que ya se hizo push tiene una señal de advertencia amarilla al final de su fila. Los botones son Cancelar y Combinar commits.]{name="history-rewrite-confirm" frame="dialog"}

## Editar el mensaje de un commit {#reword}

1. Haz clic derecho en el commit y selecciona :ui[rewrite.menu.reword]{1="e2dda2bc"} en el menú.
2. Cambia :ui[working.subject] y :ui[working.body]. Las líneas de comentario se tratan como en el [área de commit](/guide/work/commit/#comments).
3. Haz clic en :ui[rewrite.reword.button].

Los commits posteriores también se reescriben, y la lista selecciona después el commit con su nuevo hash. Si el commit ya está en el upstream, Spooky pregunta antes de abrir el diálogo.

## Editar un commit {#edit}

Editar se detiene en un commit y devuelve sus cambios a la copia de trabajo, para que puedas dividirlo o rehacerlo.

1. Haz clic derecho en el commit y selecciona :ui[rewrite.menu.edit]{1="e2dda2bc"}. Confirma con :ui[rewrite.edit.button].
2. El aviso dice :ui[conflict.title.edit]{1="e2dda2bc" 2="main"}. Los cambios del commit están en la copia de trabajo, fuera del stage.
3. Añádelos al stage y haz commit como siempre, en tantos commits como quieras.
4. Haz clic en :ui[working.endEditing] en el aviso. Los commits posteriores se vuelven a aplicar encima.

Para desistir, haz clic en :ui[working.abort] en el aviso. El primer commit de un repositorio no se puede editar.

## Enmendar un commit anterior {#amend}

Enmendar un commit anterior le añade cambios, igual que [enmendar el último commit](/guide/work/commit/#amend).

1. Haz clic derecho en el commit y selecciona :ui[rewrite.menu.amend]{1="e2dda2bc"}. Spooky empieza al instante, sin pedir confirmación.
2. El rebase se detiene en ese commit. Haz tus cambios y añádelos al stage.
3. Marca :ui[working.amend] en el área de commit y haz commit.
4. Haz clic en :ui[working.endEditing] en el aviso. Los commits posteriores se vuelven a aplicar encima.

Si tienes cambios locales al empezar, Spooky ofrece guardarlos antes en un stash. Se quedan después en el stash, así que puedes aplicarlos mientras el rebase está detenido, o más adelante.

## Autosquash {#autosquash}

Un commit puede marcarse a sí mismo como una corrección de uno anterior: empieza su asunto con `fixup!`, `squash!` o `amend!`, seguido del asunto del commit anterior. El área de commit [completa el asunto](/guide/work/commit/#autocomplete) por ti.

Cuando la lista muestra la rama en la que estás sin ninguna búsqueda, y entre sus últimos 1000 commits hay commits así, aparece bajo la cabecera un aviso titulado :ui[rewrite.autosquash]. Haz clic en :ui[rewrite.autosquash.button] en el aviso y confirma. Cada commit marcado se incorpora al commit que nombra:

- `fixup!` conserva el mensaje del commit anterior.
- `squash!` combina los dos mensajes.
- `amend!` sustituye el mensaje del commit anterior por el suyo.

Haz clic en × para ocultar el aviso por ahora.

## Cuando la reescritura no puede empezar {#errors}

Spooky comprueba los commits antes de reescribir nada. Si algo no cuadra, lo explica, y no cambia nada:

| Mensaje | Por qué |
|---|---|
| :ui[rewrite.error.notInHead] | Todos los commits deben estar en el historial de la rama en la que estás, en una sola línea. |
| :ui[rewrite.error.merges] | Hay un commit de fusión por medio, y la reescritura lo aplanaría. Elige commits posteriores a la última fusión. |
| :ui[rewrite.error.root] | El primer commit de un repositorio no tiene un padre al que devolver sus cambios. |
| :ui[rewrite.error.selection] | Combinar necesita al menos dos commits, y el destino no puede ser uno de los commits que se incorporan. |
| :ui[rewrite.error.autosquash] | Ningún commit reciente está marcado para uno anterior. |
| :ui[rewrite.error.changed] | La rama cambió después de que Spooky la leyera. Actualiza el historial y vuelve a intentarlo. |

## Cambios locales y conflictos {#local-changes}

Revertir, hacer cherry-pick y hacer rebase necesitan una copia de trabajo que no estorbe. Cuando tus cambios locales bloquean una de estas operaciones, Spooky ofrece [guardarlos antes en un stash](/guide/work/stash/#auto-stash). Enmendar un commit anterior pregunta antes de empezar.

Si un commit entra en conflicto por el camino, Spooky se detiene y muestra el [aviso de la operación](/guide/work/conflicts/#banner). Resuelve los conflictos y después continúa o aborta ahí.

## Deshacer una reescritura {#undo}

Selecciona :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>) para deshacer un revert, un cherry-pick, un restablecimiento o una reescritura. Mientras un rebase está detenido, por ejemplo para editar un commit, termínalo o abórtalo antes. Un rebase o un cherry-pick que se detuvo en un conflicto no se puede deshacer. Consulta [Deshacer y recuperar](/guide/work/undo/).

Los commits antiguos también se quedan un tiempo en el [reflog](/guide/work/undo/#reflog).

:::note[Repositorios de servidor]
Los commits se reescriben en el servidor. Todos los diálogos que reescriben el historial nombran el servidor en el que se ejecutan.
:::

## Consulta también

- [Resolver conflictos](/guide/work/conflicts/)
- [Deshacer y recuperar](/guide/work/undo/)
- [Fusionar y hacer rebase](/guide/branches/merge-rebase/)
