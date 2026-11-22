---
title: "Cola de operaciones y actividad"
description: "Descubre cómo Spooky pone en cola las operaciones de escritura, síguelas y cancélalas en el área de actividad de la barra lateral y en la ventana Actividad, y recibe notificaciones del sistema."
---

Spooky cambia un repositorio operación a operación. Si empiezas algo mientras se ejecuta otra operación, la tuya espera su turno en lugar de ser rechazada. La carga del estado, del historial y de los diffs no espera.

## Cómo se ponen en cola las operaciones {#queue}

Cuando no hay nada en ejecución en el repositorio, una operación empieza al instante. Si no, entra en la cola del repositorio, y las operaciones se ejecutan en el orden en que las empezaste. Todas las ventanas que muestran el repositorio comparten la misma cola.

Esto abarca todo lo que cambia el repositorio, lo empieces donde lo empieces: los menús, la barra de herramientas, los menús contextuales, las acciones rápidas, arrastrar y soltar, los dobles clics, los diálogos, la lista de archivos y el área de commit.

- Las opciones de menú y los botones siguen disponibles mientras el repositorio está ocupado. Un diálogo se cierra cuando haces clic en su botón, como siempre.
- Si una operación te pide confirmación, como eliminar una rama o hacer un push forzado, la pide cuando haces clic. No vuelve a pedirla cuando le llega el turno.
- Las preguntas que dependen del repositorio en ese momento, como si guardar en un stash los cambios que estorban, aparecen cuando le llega el turno.

Mientras se ejecuta una operación que cambia la copia de trabajo o el índice, la lista de archivos aparece atenuada, aunque hayas empezado la operación en otra ventana. Otras operaciones, como hacer fetch y push, dejan la lista de archivos como está, y lo que hagas en ella entra en la cola.

Un commit que está en espera mantiene bloqueados su mensaje y sus opciones hasta que se ejecuta.

## Cuando le llega el turno {#turn}

Cuando la operación anterior termina y la ventana se ha actualizado, Spooky comprueba la siguiente con el repositorio tal como está ahora. Usa las mismas reglas que deciden si la opción de menú está disponible. Si la operación ya no tiene sentido, por ejemplo porque la rama sobre la que actúa ya no existe, no se ejecuta. Su registro dice :ui[activity.skipped], con el motivo.

Si una operación falla, todo lo que está en cola detrás de ella se cancela, para que nada se ejecute sobre el fallo. Sus registros dicen qué operación falló. Si detienes tú una operación en ejecución, solo se detiene esa, y las demás siguen.

Las operaciones en cola también se cancelan cuando:

- Se pierde la conexión con un repositorio de servidor. No se ejecutan cuando vuelves a conectar.
- Cierras la ventana, o abres otro repositorio en ella. Solo se cancelan las operaciones empezadas desde esa ventana.
- Sales de Spooky.

## Deshacer y rehacer {#undo}

Deshacer y rehacer no se ponen en cola. Mientras una operación que has empezado está en ejecución o en espera, no están disponibles, y el menú dice :ui[undo.reason.busy]. Consulta [Cuando deshacer está bloqueado](/guide/work/undo/#blocked).

## Fetch automático {#auto-fetch}

El [fetch automático](/guide/branches/sync/#auto-fetch) solo empieza cuando no hay nada en ejecución ni en espera en el repositorio. Si empiezas cualquier cosa mientras está haciendo fetch, incluidos deshacer y rehacer, se detiene al instante y se ejecuta tu operación. Su registro dice :ui[activity.cancelled], y a qué operación cedió el paso.

## El área de actividad {#activity-area}

La parte inferior de la barra lateral muestra, para el repositorio de la ventana:

- Los fetch, pull, push y otras operaciones que conectan con un remoto, mientras se ejecutan y durante unos segundos después de terminar. La más reciente está arriba.
- Debajo, las operaciones que esperan en la cola, con la siguiente arriba. En lugar de la salida de Git, muestran :ui[activity.waitingDetail] hasta que les llega el turno.

Cada fila tiene una barra de progreso, un botón de detener y la última línea de la salida de Git. Se muestran hasta tres filas a la vez. Desplázate para ver más.

- Haz clic en el botón de detener de una fila en espera para sacarla de la cola. No se ejecuta nada, y la fila dice que la operación se canceló.
- Haz clic en el botón de detener de una fila en ejecución para detener la operación.
- Haz clic en cualquier otra parte de una fila para abrir la ventana :ui[activity.title].

Las operaciones que no conectan con un remoto salen del área cuando empiezan. Su progreso se muestra en la propia ventana, por ejemplo en la copia de trabajo o en el área de commit.

## La ventana Actividad {#activity-window}

Selecciona :ui[menu.window > activity.title] (<kbd>⌃⌘0</kbd>). La ventana tiene registros de todos los repositorios, en tres páginas que se eligen en la barra de herramientas:

| Página | Qué muestra | Cuánto se conservan los registros |
|---|---|---|
| :ui[activity.remote] | Los fetch, pull, push y otras operaciones que conectan con un remoto | 7 días, guardados en tu Mac |
| :ui[activity.repository] | Otras operaciones de Git, y las cargas que empiezas tú, como cargar commits | Los últimos 100, hasta que sales de la app |
| :ui[activity.service] | Las solicitudes a GitHub y GitLab | Hasta que sales de la app |

::screenshot[La ventana Actividad en la página Remoto. La lista tiene registros de fetch, pull y push de un repositorio. El push está seleccionado, y su registro completo está a la derecha.]{name="advanced-activity" frame="window" markers="57.6,10 32.8,4.6 93.8,4.6"}

1. Las páginas: :ui[activity.remote], :ui[activity.repository] y :ui[activity.service]
2. :ui[activity.clear]
3. El campo de búsqueda

Las cargas que Spooky hace por su cuenta para mantener una ventana al día no aparecen.

Selecciona un registro para ver su registro completo a la derecha. Puedes seleccionar y copiar el texto.

- Las operaciones en espera también aparecen aquí, como :ui[activity.waiting], con un botón de detener.
- :ui[activity.clear] elimina los registros terminados de la página actual. Los que están en ejecución se quedan.
- El campo de búsqueda filtra la página actual por nombre de repositorio y por texto del registro.

Las contraseñas y los tokens se dejan fuera de los registros.

## Notificaciones del sistema {#notifications}

Spooky envía una notificación cuando:

- Termina una clonación. Muestra la dirección del remoto, sin ningún nombre de usuario ni contraseña, y dónde se clonó el repositorio. Consulta [Clonar un repositorio](/guide/repositories/manager/#clone).
- Se archivan ramas automáticamente. Muestra cuántas. Consulta [Archivar automáticamente](/guide/branches/review/#auto-archive).

Spooky no pide permiso, así que al principio macOS las entrega de forma silenciosa en el **centro de notificaciones**. Para elegir cómo aparecen, selecciona **menú Apple › Ajustes del Sistema**, haz clic en **Notificaciones** en la barra lateral y después en **Spooky**. Al hacer clic en una notificación, Spooky pasa a primer plano.

:::note[Repositorios de servidor]
Cada repositorio de servidor tiene su propia cola, como uno local. Detener una operación, o que un fetch automático ceda el paso, termina también el proceso de Git en el servidor.
:::

## Consulta también

- [Fetch, pull y push](/guide/branches/sync/)
- [Deshacer y recuperar](/guide/work/undo/)
- [Estado de la conexión y reconexión](/guide/server/connection/)
