---
title: "Worktrees"
description: "Haz checkout de ramas en worktrees adicionales, y ábrelos, muévelos, repáralos y elimínalos."
---

Un worktree es otra carpeta con un checkout del mismo repositorio. Cada worktree tiene su propia rama con checkout hecho y su propia copia de trabajo. Todos comparten los commits y las ramas del repositorio. Así puedes trabajar en una segunda rama sin guardar un stash ni cambiar de rama en la primera carpeta.

Solo se puede hacer checkout de una rama en un worktree a la vez.

## En la barra lateral {#sidebar}

Los worktrees aparecen bajo :ui[worktree.group] en la barra lateral, ordenados por nombre. El nombre es la última parte de la ruta del worktree. El worktree abierto en la ventana no aparece. Deja el puntero sobre uno para ver dónde se ha hecho el checkout.

Haz clic en un worktree para ver su nombre, su ruta, su revisión actual y su rama. Haz doble clic en él para abrirlo en la misma ventana.

Una rama de la que se ha hecho checkout en otro worktree tiene una pequeña insignia en su icono. Cuando haces clic derecho en ella, el menú dice en qué worktree está. También tiene opciones para abrir o eliminar ese worktree. Consulta [Hacer checkout de una rama](/guide/branches/branches/#checkout).

Para mostrar también los worktrees en la ventana Repositorios, consulta [Organizar la lista](/guide/repositories/manager/#organize).

## Añadir un worktree {#add}

Empieza de una de estas formas:

- Selecciona :ui[menu.repository > menu.addWorktree] en la barra de menús.
- Haz clic en el botón de añadir de la parte inferior de la barra lateral, o haz clic derecho en :ui[worktree.group], y selecciona :ui[worktree.add.menu] en el menú.
- Haz clic derecho en una rama local y selecciona :ui[worktree.checkoutBranch]{1="feature/units-toggle"} en el menú.
- Arrastra una rama local a :ui[worktree.group].

En el diálogo:

1. Junto a :ui[worktree.revision], elige o escribe la rama o la revisión de la que hacer checkout. Si partiste de una rama, ya está rellenada.
2. Junto a :ui[worktree.destination], escribe la ruta completa de la nueva carpeta. El botón :ui[submodule.path.select] empieza junto a la carpeta del repositorio. Sugiere un nombre formado por el nombre del repositorio y la revisión. La carpeta no debe existir todavía, o debe estar vacía.
3. Marca :ui[worktree.detach] para hacer checkout de un HEAD desacoplado en esa revisión. Entonces el worktree no ocupa ninguna rama.
4. Haz clic en :ui[worktree.add.submit].

Si ya se ha hecho checkout de la rama en un worktree, el diálogo lo indica. Marca :ui[worktree.detach], o :ui[worktree.force] bajo :ui[dialog.options], para crear el worktree de todos modos.

El repositorio necesita al menos un commit. Después de crear el worktree, la ventana sigue en el repositorio que tenías abierto. El nuevo worktree aparece en la barra lateral.

## Abrir un worktree {#open}

Un worktree se abre como cualquier otro repositorio. Haz clic derecho en él en la barra lateral y elige en el menú:

- :ui[worktree.open.current], :ui[worktree.open.newTab] o :ui[worktree.open.newWindow]
- :ui[worktree.reveal], :ui[action.copyPath] o :ui[action.openTerminal]

## Mover un worktree {#move}

Haz clic derecho en un worktree y selecciona :ui[worktree.move.menu] en el menú. Escribe la nueva ruta, o haz clic en el botón :ui[submodule.path.select]. Los cambios del worktree se mueven con él.

## Eliminar un worktree {#remove}

Haz clic derecho en un worktree y selecciona :ui[worktree.remove.menu] en el menú. Esto elimina la carpeta del worktree. La rama de la que tenía hecho checkout sigue en el repositorio.

Si el worktree tiene cambios o archivos sin seguimiento, Git se niega a eliminarlo. Marca :ui[worktree.remove.force] para eliminarlo junto con ellos.

El worktree principal del repositorio, la carpeta que contiene su directorio `.git`, no se puede mover ni eliminar. Aparece en la lista cuando tienes abierto otro worktree.

## Reparar un worktree {#repair}

Si la carpeta de un worktree se mueve o se elimina fuera de Spooky, el worktree deja de funcionar. Recibe un icono de advertencia en la barra lateral. No puedes abrirlo. Sus detalles dicen :ui[worktree.invalid], con el motivo que da Git, y dos botones:

- :ui[worktree.invalid.repair]: si moviste la carpeta, selecciona :ui[submodule.path.select] en el menú :ui[worktree.location] y busca dónde está ahora la carpeta. Spooky comprueba que la carpeta es este worktree de este repositorio. Después haz clic en :ui[worktree.relocate.submit].
- :ui[worktree.invalid.remove]: si la carpeta ya no existe, esto quita del repositorio lo que queda del worktree.

Encontrarás las dos opciones también en el menú contextual del worktree.

## Deshacer {#undo}

Añadir, mover, eliminar y reparar worktrees no se puede deshacer con <kbd>⌘Z</kbd>. Después de una de estas operaciones, las anteriores tampoco se pueden deshacer ya. Consulta [Deshacer y recuperar](/guide/work/undo/).

:::note[Repositorios de servidor]
Los worktrees se crean en el servidor. Sus rutas son rutas del servidor. :ui[submodule.path.select] explora las carpetas del servidor.

:ui[worktree.reveal] está disponible cuando Spooky puede encontrar la carpeta del worktree en tu Mac. Si el worktree está dentro de la carpeta del repositorio, Spooky lo encuentra mediante la ubicación del repositorio. Si no, busca entre los volúmenes montados en tu Mac. Consulta [Ubicación en este Mac](/guide/server/local-location/).
:::

## Consulta también

- [Ramas](/guide/branches/branches/)
- [Submódulos](/guide/advanced/submodules/)
- [La ventana Repositorios](/guide/repositories/manager/)
