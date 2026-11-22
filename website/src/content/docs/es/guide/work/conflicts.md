---
title: "Resolver conflictos"
description: "Resuelve los conflictos de una fusión, un rebase u otra operación en curso con el asistente de conflictos o con una herramienta de fusión externa, y después continúa o aborta."
---

Un conflicto ocurre cuando los dos lados han cambiado la misma parte de un archivo y Git no sabe qué cambio conservar. Una fusión, un rebase, un cherry-pick o un revert se detienen en ese punto, y lo mismo pasa al aplicar un stash. Tú decides qué entra en cada archivo y después terminas la operación.

::screenshot[La copia de trabajo durante una fusión de “feature/units-toggle” en “main”. Un aviso amarillo en la parte superior de la columna central indica 1 conflicto sin resolver y 0 resueltos, y tiene un botón Abortar. En la lista de archivos, src/units.ts está marcado como en conflicto. A la derecha, dos tarjetas muestran la versión de units.ts de cada rama, con flechas que apuntan hacia abajo a un cuadro de resultado vacío y un botón para elegir la herramienta de fusión.]{name="conflict" frame="window" markers="24,18 47,58.7 76,37 76,73 85.5,86"}

1. El aviso muestra qué está en curso y cuántos conflictos quedan.
2. Un archivo en conflicto. Selecciónalo para abrir el asistente de conflictos.
3. Las dos versiones del archivo, una de cada lado.
4. El resultado: cómo quedará el archivo.
5. El botón que resuelve el archivo o abre una herramienta de fusión.

## Operaciones en curso {#banner}

Mientras hay una fusión, un rebase, un cherry-pick o un revert en curso, aparece un aviso en la parte superior de la copia de trabajo:

- El título dice qué está pasando, por ejemplo :ui[conflict.title.merge]{1="feature/units-toggle" 2="main"}.
- Debajo está el número de conflictos sin resolver. Cuando la operación se ha detenido en un conflicto, le sigue entre paréntesis el número de archivos resueltos.
- Una indicación breve dice qué hacer a continuación. Durante un rebase o una serie de commits, una barra de progreso muestra en qué paso estás.
- :ui[working.onlyConflicts] reduce la lista de archivos a los de este conflicto. Los archivos que has resuelto siguen en la lista. Spooky recuerda la elección para todos los repositorios.
- :ui[working.abort] cancela la operación. Consulta [Continuar o abortar](#continue).

El área de commit permanece oculta hasta que se resuelven todos los conflictos.

## Usar el asistente de conflictos {#wizard}

Selecciona un archivo en conflicto en la copia de trabajo. El asistente de conflictos se abre a la derecha, con una tarjeta para cada lado, como :ui[conflict.version]{1="main"}. Cada tarjeta muestra el archivo, lo que ese lado hizo con él (por ejemplo :ui[conflict.change.modified]) y el commit del que procede.

Para conservar un lado:

1. Haz clic en su tarjeta. El cuadro de resultado muestra esa versión.
2. Haz clic en :ui[conflict.resolveUsing]{1="main"}.

Spooky escribe esa versión en el archivo y lo añade al stage. El archivo cuenta como resuelto. Si ese lado eliminó el archivo, el archivo se elimina.

Para combinar los dos lados, haz clic en las dos tarjetas y después en el botón que hay bajo el cuadro de resultado. Abre una herramienta de fusión, como se describe en [Fusionar en otra app](#merge-tool).

Si ya has editado el archivo por tu cuenta, por ejemplo en un editor de texto, el cuadro de resultado muestra :ui[conflict.result]. Haz clic en :ui[conflict.resolveCurrent] para añadir el archivo al stage tal como está. El asistente vuelve a leer el archivo cuando regresas a Spooky.

El botón “…” de una tarjeta abre un menú para esa versión:

- :ui[conflict.open]{1="main"} o abrirla con otra app
- :ui[conflict.export]{1="main"}
- :ui[conflict.compareOther]{1="feature/units-toggle"}
- :ui[conflict.compareBase]

## Fusionar en otra app {#merge-tool}

Una herramienta de fusión muestra las dos versiones una junto a otra y te deja elegir los cambios línea a línea. Trabaja con un archivo cada vez, cuando los dos lados tienen el archivo.

1. En el asistente de conflictos, haz clic en :ui[externalTool.chooseMergeTool] y elige una app. Después de la primera vez, el botón dice :ui[externalTool.mergeIn]{1="FileMerge"}.
2. Fusiona el archivo en esa app, guarda el resultado y ciérrala.

Spooky escribe el resultado en el archivo y lo marca como resuelto. Si la app no guardó ningún resultado, Spooky dice :ui[externalTool.noResult], y el conflicto sigue ahí.

FileMerge funciona de forma algo distinta. Spooky muestra :ui[externalTool.finishMerge]{1="FileMerge"} mientras está abierto. Guarda el resultado en FileMerge y haz clic en :ui[externalTool.done].

Spooky es compatible con Araxis Merge, Beyond Compare, DeltaWalker, FileMerge, Kaleidoscope, P4Merge y Visual Studio Code. Para cambiar de app, cambia :ui[externalTool.mergeTool] en :ui[app.name > settings.title] › :ui[settings.gitConfig]. Activa ahí :ui[externalTool.keepBackups] para conservar el archivo como estaba antes de la fusión, por ejemplo como `src/units.ts.orig`. Consulta [Herramientas de comparación y de fusión](/guide/settings/integration/#diff-merge-tools).

Si el archivo se modificó en otro sitio mientras fusionabas, Spooky pregunta antes de sobrescribirlo.

:::note[Repositorios de servidor]
La herramienta de fusión recibe copias de las versiones en una carpeta temporal de este Mac. Spooky escribe el resultado en el servidor y después marca el archivo como resuelto. La carpeta se elimina cuando cierras el repositorio.
:::

## Otras formas de resolver {#other-ways}

Haz clic derecho en uno o varios archivos en conflicto:

- :ui[conflict.menu.resolve]
  - :ui[conflict.markResolved.one]{1="src/units.ts"} añade el archivo al stage tal como está ahora. Marcar su casilla hace lo mismo.
  - :ui[conflict.resolveUsingVersion]{1="main"} conserva un lado, como el asistente.
- :ui[conflict.menu.restore]
  - :ui[conflict.restoreUnmerged.one]{1="src/units.ts"} recupera el conflicto, incluso en un archivo que ya habías resuelto.
  - :ui[conflict.restoreVersion]{1="main"} y :ui[conflict.restoreAncestor] ponen una versión en el archivo. El archivo sigue sin resolver.

:::caution
Restaurar sobrescribe el archivo de la copia de trabajo sin preguntar. Se pierden las ediciones que le hayas hecho.
:::

Cuando la aplicación de un stash o de un parche se detiene por conflictos, no hay ninguna operación que continuar o abortar, ni ningún aviso. El asistente llama al lado entrante :ui[conflict.version.applied]. Una vez resueltos los archivos, los cambios están en la copia de trabajo como cualesquiera otros.

## Continuar o abortar {#continue}

Cuando todos los conflictos están resueltos, el área de commit vuelve a aparecer, con el mensaje que Git preparó para la operación.

- **Una fusión, o el cherry-pick o el revert de un solo commit**: revisa el mensaje y haz clic en :ui[working.commit].
- **Un rebase, o el cherry-pick o el revert de varios commits**: revisa el mensaje y haz clic en :ui[working.continue]. Spooky hace commit de este paso y pasa al siguiente, que puede volver a detenerse en un conflicto.
- **Un paso de rebase que se detiene para editar un commit**: haz tus commits y haz clic en :ui[working.endEditing] en el aviso.

A veces no queda nada de lo que hacer commit, por ejemplo cuando conservaste la versión que ya estaba ahí. Cuando haces clic en :ui[working.commit] o :ui[working.continue] en ese caso, Spooky pregunta :ui[commit.empty.title] Haz clic en :ui[commit.empty.use] para crear un commit vacío. El otro botón aborta la fusión, u omite el paso en un rebase o una serie. En un rebase o una serie, también puedes hacer clic en :ui[working.skip] en el aviso.

Para desistir, haz clic en :ui[working.abort] en el aviso. El repositorio vuelve a como estaba antes de que empezara la operación.

:::caution
Abortar se ejecuta al instante, sin preguntar, y no se puede deshacer. Los conflictos que hayas resuelto se pierden.
:::

## Consulta también

- [Revisar y añadir cambios al stage](/guide/work/diff/)
- [Stashes](/guide/work/stash/)
- [Deshacer y recuperar](/guide/work/undo/)
