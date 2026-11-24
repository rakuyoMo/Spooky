---
title: "Solución de problemas"
description: "Soluciona problemas habituales como conexiones fallidas, un Git desfasado, los permisos y el PATH del servidor, y descubre cómo informar de un problema."
---

Cada problema de esta página empieza por lo que ves, y después explica por qué pasa y qué hacer. Muchos errores de Spooky muestran además la salida original de Git o de SSH, que a menudo señala la causa exacta.

## No se puede conectar a un servidor {#connect}

Un problema de conexión aparece en uno de estos sitios:

- El diálogo :ui[remote.form.title] sigue abierto y dice qué hay que corregir. Consulta [Cuando la comprobación falla](/guide/server/add/#results) para cada caso.
- Al abrir un repositorio de servidor se muestra :ui[missing.unreachable.title]{1="driftwood-server"}. Consulta [Sin conexión](/guide/server/connection/#offline).
- En un repositorio de servidor abierto, la franja de la parte superior de la lista se pone amarilla e indica el motivo. Consulta [Estado de la conexión](/guide/server/connection/#status).

Primero, prueba el mismo inicio de sesión fuera de Spooky. Ejecuta esto en Terminal, con tu propio alias de host:

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

Si falla, el problema está entre tu Mac y el servidor. Consulta [Probar cómo se conecta Spooky](/guide/server/prepare-ssh/#test) para saber qué significa cada tipo de salida. Si funciona en Terminal pero Spooky sigue sin poder iniciar sesión, puede que Spooky esté usando otro agente SSH. Consulta [Agente SSH](/guide/settings/integration/#ssh-agent).

El motivo que muestra Spooky te dice dónde mirar:

| Motivo | Qué hacer |
|---|---|
| :ui[remoteError.authentication] | El servidor no acepta tu clave, o tu Mac no puede desbloquearla. Después de reiniciar, vuelve a cargar la clave, como en [Después de reiniciar tu Mac](/guide/server/prepare-ssh/#after-restart). Una cuenta que solo puede iniciar sesión con contraseña no sirve. |
| :ui[remoteError.unknownHostKey] | Tu Mac aún no conoce el servidor. Conéctate una vez en Terminal y comprueba la huella, como en [Conectarte una vez](/guide/server/prepare-ssh/#fingerprint). Spooky nunca acepta una huella por ti. |
| :ui[remoteError.changedHostKey] | No te conectes todavía. Confirma antes el cambio con el propietario del servidor. |
| :ui[remoteError.unavailable] | Comprueba el alias de host y tu red. Spooky vuelve a intentarlo 5 segundos después de cada intento fallido. Para intentarlo enseguida, haz clic en :ui[action.reconnect] en la franja. Consulta [Desconexiones y reconexión](/guide/server/connection/#reconnect). |
| :ui[remoteError.deployment] | Al servidor le falta algo que Spooky necesita: el reenvío de sockets Unix, `/usr/bin/perl`, o permiso de escritura en `~/.spooky/bin` y `/tmp`. Consulta [Servidores](/reference/requirements/#servers). |

Si en el servidor falta Git o es demasiado antiguo, sigue leyendo.

## Git es demasiado antiguo {#git-version}

Spooky necesita Git 2.41.0 o posterior, tanto en tu Mac como en los servidores.

### En tu Mac {#mac-git}

Cuando abres un repositorio local, Spooky puede mostrar uno de estos mensajes:

- :ui[error.version], con la salida de Git debajo. El programa de Git que usa Spooky es anterior a la versión 2.41.0. Elige uno más reciente junto a :ui[settings.gitProgram] en :ui[app.name > settings.title] › :ui[settings.gitConfig], o actualiza Xcode o las Command Line Tools.
- :ui[error.gitProgram], con la ruta debajo. El programa de Git que elegiste ya no está ahí, por ejemplo porque lo desinstalaste. Elige otro en el mismo sitio.

El menú solo muestra los programas de Git que son lo bastante recientes. Consulta [Programa de Git](/guide/settings/identity/#git-program).

### En un servidor {#server-git}

La conexión falla con :ui[remoteError.gitVersion]. Actualiza Git en el servidor a la versión 2.41.0 o posterior.

Si ya hay un Git más reciente instalado ahí, los inicios de sesión SSH encuentran antes uno más antiguo. Pon la carpeta del Git más reciente por delante de las demás en `PATH`, como en [No se encuentra Git en el servidor](#server-path).

## No se encuentra Git en el servidor {#server-path}

La conexión falla con :ui[remoteError.gitUnavailable]. O bien, cuando compruebas el servidor en :ui[app.name > settings.title] › :ui[settings.environment], muestra :ui[settings.environment.server.noGit].

Si Git no está instalado en el servidor, instala Git 2.41.0 o posterior. Si lo está, la causa suele ser el `PATH`. Spooky ejecuta los comandos en el servidor por SSH, sin un shell interactivo. Ese shell lee menos archivos de arranque. Un `PATH` que hayas definido en `~/.zshrc` o `~/.bash_profile` puede no aplicarse.

Para solucionarlo:

1. Inicia sesión en el servidor en Terminal y ejecuta `command -v git`. Muestra dónde está Git, por ejemplo `/opt/homebrew/bin/git`.
2. Compáralo con el `PATH` que recibe Spooky. La salida del error lo incluye, y también la comprobación de [Comprobar un servidor](/guide/settings/general/#server-check).
3. Añade la carpeta de Git al `PATH` en un archivo de arranque que lean los shells no interactivos. Ejecuta `echo $SHELL` en el servidor para ver qué shell usas.
   - zsh: `~/.zshenv`
   - bash: `~/.bashrc`, por encima de cualquier línea que salga antes de tiempo cuando el shell no es interactivo

   Por ejemplo:

   ```sh
   export PATH="/opt/homebrew/bin:$PATH"
   ```

4. Vuelve a hacer clic en :ui[settings.environment.server.check], o ejecuta la prueba de [No se puede conectar a un servidor](#connect). Después vuelve a conectarte.

Git LFS y los programas que ejecutan tus hooks se encuentran mediante el mismo `PATH`. Si funcionan en Terminal pero no desde Spooky, por ejemplo cuando un comando falla con :ui[hostError.lfsUnavailable], añade sus carpetas de la misma manera.

## Problemas de permisos {#permissions}

| Lo que ves | Por qué, y qué hacer |
|---|---|
| :ui[remoteError.pathPermission] | Tu usuario en el servidor no puede abrir o leer la carpeta del repositorio. Pide acceso al propietario del servidor, o elige una carpeta que sea tuya. |
| :ui[remoteError.diskAccess] | El servidor es un Mac, y el repositorio está en una carpeta que macOS protege, como Documentos. Activa el acceso total al disco para los usuarios remotos, como en [Usar un Mac como servidor](/guide/server/prepare-ssh/#mac-server), o mueve el repositorio. |
| :ui[error.ownership] | La carpeta del repositorio en este Mac pertenece a otro usuario. Git se niega a trabajar en ella. Cambia el propietario de la carpeta para que seas tú. Si confías en su propietario, puedes ejecutar en su lugar el comando `git config --global --add safe.directory` que sugiere la salida de Git. |
| :ui[error.terminal] | Los detalles de debajo del título dicen qué ha fallado. A menudo la app de terminal elegida junto a :ui[settings.terminal] ya no está instalada, o no permitiste que Spooky controlara Terminal o iTerm. Consulta [Terminal](/guide/settings/integration/#terminal). |
| :ui[appIcon.writeFailed] | Spooky guarda el icono dentro de `Spooky.app`. Tu usuario tiene que poder escribir en ella. En el Finder, selecciona Spooky, selecciona **Archivo › Obtener información** y comprueba que tienes **Leer y escribir** en **Compartir y permisos**. |

:::note[Repositorios de servidor]
En un servidor, una carpeta que pertenece a otro usuario falla con :ui[remoteError.notWorkingTree], y la salida de Git menciona la propiedad. Pregunta al propietario del servidor, o ejecuta el comando `safe.directory` en el servidor.
:::

## Informar de un problema {#report}

Selecciona :ui[menu.help > help.support] para abrir las incidencias de Spooky en GitHub. Busca ahí tu problema, o abre una incidencia nueva. Di qué hiciste, qué esperabas y qué pasó. Si Spooky mostró un error, incluye su título y la salida original.

Un informe de diagnóstico ayuda a ver qué pasó. Selecciona :ui[menu.help > help.diagnosticReport] y elige dónde guardarlo. Spooky guarda un archivo de texto y lo muestra en el Finder. No envía el informe a ningún sitio. Abre el archivo y léelo antes de compartirlo. Consulta [Informes de diagnóstico](/reference/data-privacy/#diagnostic-reports) para saber qué contiene.

Si Spooky se cerró inesperadamente la última vez, pregunta en el siguiente arranque: :ui[crash.title]. Cuando haces clic en :ui[crash.report], se abre en tu navegador la página de una nueva incidencia en GitHub, con un resumen del fallo ya rellenado. La incidencia solo se crea cuando la envías en el navegador. Consulta [Informes de fallos](/reference/data-privacy/#crash-reports).

## Consulta también

- [Preparar SSH](/guide/server/prepare-ssh/)
- [Estado de la conexión y reconexión](/guide/server/connection/)
- [Requisitos del sistema](/reference/requirements/)
- [Datos y privacidad](/reference/data-privacy/)
