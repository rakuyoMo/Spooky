---
title: "Estado de la conexión y reconexión"
description: "Entiende el estado de la conexión, las solicitudes de contraseña y de frase de contraseña, las desconexiones y la reconexión, y qué puedes seguir viendo sin conexión."
---

Un repositorio de servidor depende de su conexión SSH. Esta página explica cómo saber si está conectado, qué significan las preguntas del servidor y qué ocurre cuando se corta la conexión.

## Estado de la conexión {#status}

En un repositorio de servidor, una franja en la parte superior de cada lista muestra el alias de host y el estado de la conexión. La encontrarás en la copia de trabajo, el historial, los stashes, el reflog, el historial del archivo y la lista de archivos de un commit.

| Estado | Qué significa |
|---|---|
| :ui[connection.connecting] | Spooky está abriendo la conexión. |
| :ui[connection.connected] | La conexión funciona. |
| :ui[connection.reconnecting] | La conexión se ha cortado, y Spooky lo está intentando de nuevo. |
| :ui[connection.unavailable] | El último intento ha fallado. Spooky lo intenta de nuevo 5 segundos después. |

Mientras el repositorio no está conectado, la franja se vuelve amarilla y muestra más cosas:

- Una nota que dice que Spooky muestra la última instantánea correcta, y que las escrituras están desactivadas hasta que se recupere la conexión.
- El motivo, como :ui[remoteError.unavailable]. Haz clic en él para ver la salida original de SSH.
- Un botón :ui[action.reconnect], mientras el estado es :ui[connection.unavailable].

::screenshot[La parte superior de la copia de trabajo de un repositorio de servidor que ha perdido la conexión. Una franja indica que spooky-test no está disponible, con un botón para reconectar. Debajo, una nota dice que Spooky muestra la última instantánea correcta y que las escrituras están desactivadas hasta que se recupere la conexión. Una línea contraída indica que la conexión con el servidor no está disponible.]{name="server-unavailable" frame="closeup"}

## Solicitudes de contraseña y de frase de contraseña {#prompts}

Spooky inicia sesión en el servidor sin preguntar nada. Aun así, el Git del servidor a veces necesita una respuesta, por ejemplo una contraseña cuando haces push a un remoto por HTTPS. Spooky pasa la pregunta a tu Mac y la muestra en un diálogo:

| Diálogo | Cuándo aparece |
|---|---|
| :ui[callback.username.title], :ui[callback.password.title] | Un remoto pregunta quién eres. Suele ocurrir con los remotos a los que se accede por HTTPS. |
| :ui[callback.privateKey.title] | La clave SSH que el servidor usa para un remoto está protegida con una frase de contraseña. |
| :ui[signing.unlock] | Git necesita la frase de contraseña de la clave de firma del servidor para firmar un commit o una etiqueta. |
| :ui[callback.editor] | Git quiere que edites un texto, como un mensaje. |

La primera línea del diálogo nombra el servidor. Un diálogo de clave privada muestra además la ruta de la clave en el servidor.

Para un nombre de usuario o una contraseña, selecciona :ui[callback.saveKeychain] para conservar la respuesta. La próxima vez que el Git de ese servidor pregunte, Spooky responde desde el llavero. Si has añadido una cuenta de GitHub o GitLab, Spooky responde primero con esa cuenta. Consulta [Cuentas de alojamiento](/guide/hosting/accounts/).

Algunas cosas que conviene saber:

- Cada diálogo espera 2 minutos. Si no respondes a tiempo, Git no recibe respuesta y el comando falla.
- El fetch automático nunca pregunta. Solo usa las cuentas y las respuestas guardadas en el llavero. Si no bastan, se cancela.
- Los diálogos de frase de contraseña para el Git del servidor necesitan OpenSSH 8.4 o posterior en el servidor.

## Desconexiones y reconexión {#reconnect}

Cuando se corta la conexión, Spooky se reconecta por su cuenta. Tras cada intento fallido, el estado muestra :ui[connection.unavailable]. Spooky lo intenta de nuevo 5 segundos después. Para intentarlo en el momento, haz clic en :ui[action.reconnect]. Cuando la conexión vuelve, Spooky recarga el repositorio.

Los cambios que hiciste no se repiten tras una desconexión:

- Las operaciones que esperaban en la cola del repositorio se cancelan. No se ejecutan tras la reconexión. Inícialas de nuevo si aún las necesitas.
- Una operación que estaba en curso cuando se cortó la conexión no se reintenta. Tras la reconexión, Spooky comprueba la rama, el número de cambios, el bloqueo del índice y si hay una fusión o un rebase en curso.

Esa comprobación aparece en el diálogo :ui[recovery.title]. Te dice si la operación llegó a empezar y si el commit actual se ha movido. Mira el resultado antes de intentar la operación de nuevo.

## Sin conexión {#offline}

Puedes seguir viendo lo último que leyó Spooky: las listas, el archivo seleccionado y sus cambios. Todo lo que modifica el repositorio deja de estar disponible hasta que vuelve la conexión.

Si no se puede acceder al servidor al abrir un repositorio, la ventana muestra :ui[missing.unreachable.title]{1="driftwood-server"} con la salida de SSH. Haz clic en :ui[action.refresh] para intentarlo de nuevo, o en :ui[action.close] para volver a la ventana Repositorios.

:::tip
Ejecuta `ssh -o BatchMode=yes driftwood-server git --version` en Terminal, con tu propio alias de host. Si falla, el problema está entre tu Mac y el servidor, no en Spooky. Consulta [Probar cómo se conecta Spooky](/guide/server/prepare-ssh/#test).
:::

## Consulta también

- [Preparar SSH](/guide/server/prepare-ssh/)
- [Añadir repositorio de servidor](/guide/server/add/)
- [Cómo funcionan los repositorios de servidor](/guide/server/overview/)
