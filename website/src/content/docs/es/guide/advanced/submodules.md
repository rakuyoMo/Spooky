---
title: "Submódulos"
description: "Abre, actualiza, inicializa, sincroniza, mueve, renombra y elimina submódulos, y haz fetch de ellos."
---

Un submódulo es otro repositorio de Git dentro de una carpeta de tu repositorio. Tu repositorio registra qué commit de él hay que usar. Spooky llama a ese registro el puntero del submódulo.

## En la barra lateral {#sidebar}

Los submódulos aparecen bajo :ui[submodule.group] en la barra lateral, ordenados por ruta. Deja el puntero sobre uno para ver su nombre y su URL.

- Una fila atenuada es un submódulo del que aún no se ha hecho checkout.
- Un icono de advertencia significa que su configuración está incompleta, o que hay que sincronizar su URL.
- Un número indica cuántos archivos han cambiado dentro de él.
- ↑ y ↓ muestran cuánto va por delante o por detrás del puntero el commit del que se ha hecho checkout.

Haz clic en un submódulo para ver sus detalles. Haz doble clic en un submódulo con checkout hecho para abrirlo como repositorio en la misma ventana. Mientras está abierto, :ui[toolbar.parentRepository] en la barra de herramientas te lleva de vuelta.

Hacer doble clic en un submódulo con checkout hecho en la lista de archivos de la copia de trabajo lo abre de la misma forma. Para que ese doble clic lo abra como los demás archivos, desactiva :ui[files.openSubmodules] en :ui[app.name > settings.title] › :ui[settings.general]. Consulta [Lista de archivos](/guide/settings/general/#file-list).

## Detalles {#details}

Los detalles tienen tres páginas, que se eligen arriba:

- :ui[submodule.page.general]: el nombre, la ruta, el estado, los cambios locales, el commit del que se ha hecho checkout, el puntero y los ajustes vigentes. Si el submódulo no está inicializado, o su URL en `.gitmodules` ha cambiado, una nota en la parte superior tiene un botón para arreglarlo.
- :ui[submodule.page.shared]: los ajustes de `.gitmodules`. Todos los que clonan el repositorio los reciben. Los cambios que hagas aquí aparecen en la copia de trabajo. Haces commit de ellos como de los demás cambios.
- :ui[submodule.page.local]: los ajustes de la configuración propia de este repositorio. Solo se aplican aquí. Tienen prioridad sobre `.gitmodules`.

En las dos páginas de configuración, puedes renombrar y mover el submódulo, cambiar su URL y definir tres opciones. :ui[submodule.useDefault] quita una opción. Entonces se aplica el valor predeterminado de Git.

- :ui[submodule.field.fetchMode]: si hacer fetch del repositorio padre hace también fetch de este submódulo. Elige :ui[submodule.fetchMode.always], :ui[submodule.fetchMode.onDemand] (solo cuando los commits obtenidos cambian su puntero; es el valor predeterminado) o :ui[submodule.fetchMode.never].
- :ui[submodule.field.ignoreMode]: qué cambios del submódulo ignora la copia de trabajo del padre. Elige :ui[submodule.ignoreMode.none] (el valor predeterminado), :ui[submodule.ignoreMode.untracked], :ui[submodule.ignoreMode.dirty] (solo cuenta que haya otro commit con checkout hecho) o :ui[submodule.ignoreMode.all].
- :ui[submodule.field.updateStrategy]: cómo lleva la actualización el submódulo a su puntero. Elige :ui[submodule.updateStrategy.checkout] (el valor predeterminado), :ui[submodule.updateStrategy.rebase] o :ui[submodule.updateStrategy.merge] sobre su rama actual, o :ui[submodule.updateStrategy.none].

## Añadir un submódulo {#add}

1. Selecciona :ui[menu.repository > menu.addSubmodule] en la barra de menús. También puedes hacer clic en el botón de añadir de la parte inferior de la barra lateral, o hacer clic derecho en :ui[submodule.group], y seleccionar :ui[submodule.add.menu] en el menú.
2. Escribe la URL del repositorio del submódulo.
3. En :ui[submodule.path], selecciona :ui[submodule.path.select] y elige una carpeta vacía dentro de tu repositorio.
4. Haz clic en :ui[submodule.add.submit].

Si tu repositorio ya tiene un directorio de Git para un submódulo con ese nombre, por ejemplo de uno que eliminaste, Spooky pregunta qué hacer. :ui[submodule.forceAdd.reuse] lo vuelve a usar. :ui[submodule.forceAdd.overwrite] lo elimina y clona de nuevo.

## Hacer fetch y actualizar {#update}

- **Hacer fetch** descarga los commits nuevos del remoto del submódulo. No cambia aquello de lo que se ha hecho checkout.
- **Actualizar** hace checkout del commit que registra el puntero. Un submódulo que no está inicializado se inicializa antes.

Haz clic derecho en un submódulo y selecciona :ui[submodule.fetch.menu]{1="vendor/charts"} o :ui[submodule.update.menu]{1="vendor/charts"} en el menú. El menú :ui[menu.repository] tiene las mismas opciones, además de otras para todos los submódulos a la vez.

Los diálogos tienen estas opciones:

- :ui[sync.prune] al hacer fetch
- :ui[submodule.update.recursive] al actualizar. Actualiza también los submódulos que hay dentro del submódulo. Sus remotos deben funcionar con credenciales que ya estén configuradas. Spooky no puede pedírtelas por el camino.

Mantén pulsada <kbd>⌥</kbd> en el menú contextual para ver :ui[submodule.quickFetch]{1="vendor/charts"} y :ui[submodule.quickUpdate]{1="vendor/charts"}. Se saltan el diálogo y usan las opciones de la última vez. Lo mismo hacen :ui[menu.fetchAllSubmodules] y :ui[menu.updateAllSubmodules] en la barra de menús.

Actualizar solo está disponible cuando hay algo que hacer: no se ha hecho checkout del submódulo, o se ha hecho checkout de un commit distinto.

### Actualizar después de otras operaciones {#auto-update}

Hacer checkout, hacer pull, fusionar y otras operaciones pueden cambiar el puntero de un submódulo con checkout hecho. Después, Spooky pregunta si quieres actualizar esos submódulos. Marca :ui[submodule.autoUpdate.always] para actualizarlos al instante de ahí en adelante. Puedes volver a desactivarlo con :ui[settings.autoUpdateSubmodules] en :ui[app.name > settings.title] › :ui[settings.general]. Consulta [Operaciones](/guide/settings/general/#operations).

### Inicializar y sincronizar {#initialize}

- **Inicializar** copia los ajustes del submódulo de `.gitmodules` a la configuración de tu repositorio. Actualízalo después para hacer checkout de él.
- **Sincronizar** sirve para cuando la URL de `.gitmodules` ha cambiado. Hace que la URL de la configuración de tu repositorio, y la del repositorio del propio submódulo, coincidan con la nueva.

Las dos están en el menú contextual, y en una nota de la página :ui[submodule.page.general] cuando hacen falta.

## Hacer checkout de otra revisión {#checkout}

Haz clic derecho en un submódulo con checkout hecho y elige una rama o una etiqueta del submódulo en :ui[submodule.checkoutRevision]. La actual tiene una marca.

Si hay cambios dentro del submódulo que estorban, el checkout falla. Spooky no ofrece guardarlos en un stash. Los stashes de tu repositorio no abarcan el submódulo.

El puntero de tu repositorio no se mueve hasta que haces commit del nuevo commit del submódulo.

## Mover, renombrar y eliminar {#manage}

Las tres opciones están en el menú contextual:

- **Mover** cambia la ruta del submódulo. Marca :ui[submodule.move.rename] para renombrarlo también con la nueva ruta.
- **Renombrar** cambia su nombre. `.gitmodules` y tu configuración se refieren al submódulo por este nombre. La carpeta se queda donde está.
- **Eliminar** quita el submódulo de tu repositorio. Marca :ui[submodule.delete.keepWorkingTree] para quitar solo su configuración y conservar sus archivos. Si tiene cambios dentro, Spooky pregunta antes de eliminarlo de todos modos con :ui[submodule.forceDelete.submit].

Estas operaciones cambian `.gitmodules` y el índice de tu repositorio. Haz commit de los cambios para que los demás también los reciban.

Después de una eliminación, el directorio de Git del submódulo se queda dentro de la carpeta `.git` de tu repositorio. Al añadirlo de nuevo se puede reutilizar.

### Reparar un submódulo {#repair}

Cuando la configuración de un submódulo está incompleta, sus detalles dicen :ui[submodule.invalid], con dos botones. :ui[submodule.repair.submit] restaura lo que falta: la entrada de `.gitmodules`, el puntero o el repositorio con checkout hecho. Si Spooky no encuentra la URL del submódulo en ningún sitio, elimínalo y añádelo de nuevo.

## Deshacer {#undo}

Puedes deshacer añadir, mover, renombrar y eliminar un submódulo, hacer checkout de otra revisión en él y cambiar su URL o sus opciones. Consulta [Deshacer y recuperar](/guide/work/undo/).

Inicializar, sincronizar y reparar no se pueden deshacer. Después de una de estas operaciones, las anteriores tampoco se pueden deshacer ya.

Hacer fetch y actualizar no se registran, igual que hacer fetch y pull en el repositorio. Las operaciones anteriores a ellos se pueden seguir deshaciendo.

:::note[Repositorios de servidor]
Todo esto se ejecuta en el servidor. Cuando añades un submódulo, eliges su carpeta en el servidor.
:::

## Consulta también

- [Fetch, pull y push](/guide/branches/sync/)
- [Worktrees](/guide/advanced/worktrees/)
- [Deshacer y recuperar](/guide/work/undo/)
