---
title: "Datos y privacidad"
description: "Descubre qué guarda Spooky y dónde, a qué direcciones de red se conecta, y qué contienen los informes de fallos y de diagnóstico."
---

No existe ninguna cuenta de Spooky, y Spooky no recoge datos de uso. Esta página recoge qué guarda, dónde lo guarda y a qué direcciones se conecta.

## En tu Mac {#mac}

| Qué | Dónde |
|---|---|
| Los ajustes, la lista de repositorios, los perfiles de usuario, la lista de cuentas de alojamiento y las ubicaciones de los repositorios de servidor en este Mac | Las preferencias de Spooky, `com.rakuyo.spooky` |
| Los temas, un archivo `.spookytheme` cada uno | `~/Library/Application Support/Spooky/Themes/` |
| Pequeñas carpetas `.spookyrepo` que permiten que los repositorios de servidor aparezcan entre los documentos recientes | `~/Library/Application Support/Spooky/Locations/` |
| Los registros de las operaciones con remotos de :ui[activity.title], como fetch, pull y push, que se conservan 7 días | `~/Library/Application Support/Spooky/Activity/` |
| Aquello con lo que compara :ui[activity.title] para contar los cambios, un archivo por repositorio | `~/Library/Application Support/Spooky/Baselines/` |
| Los nombres de usuario y las contraseñas que guardaste para Git en un servidor | El llavero, en ítems llamados `com.rakuyo.spooky.remote.<host alias>` |
| Los tokens de las cuentas de alojamiento | El llavero, en ítems llamados `com.rakuyo.spooky.hosting.<address>` |
| Las cachés y las cookies que macOS conserva para las solicitudes de red de Spooky | `~/Library/Caches/com.rakuyo.spooky/`, y los ítems de `~/Library/HTTPStorages/` cuyo nombre empieza por `com.rakuyo.spooky` |
| Los archivos de conexión de los repositorios de servidor | Carpetas `/tmp/spooky-*`, que se eliminan cuando se cierra la conexión |
| Las copias de los archivos que abres en Vista Rápida o en otras apps | Carpetas temporales `spooky-files-*`, que se eliminan cuando se cierra el repositorio |

Si inicias sesión en un GitLab autogestionado con nombre de usuario y contraseña, Spooky conserva los tokens que recibe a cambio. No conserva la contraseña.

Para eliminar todo esto, consulta [Desinstalar](/guide/start/install/#uninstall).

## En los servidores {#servers}

Aparte del propio repositorio, Spooky escribe en dos sitios de un servidor:

- `~/.spooky/bin/`, en tu carpeta de inicio: un pequeño script que Spooky ejecuta por SSH, más unos enlaces a él para las solicitudes y la firma. Se queda ahí para la siguiente conexión. Elimina la carpeta para quitarlo.
- `/tmp/spooky-*`: archivos de la conexión actual. Se eliminan cuando se cierra la conexión.

Cuando Spooky busca la [ubicación en este Mac](/guide/server/local-location/#automatic) de un repositorio, pone un momento un archivo vacío en la carpeta de Git del repositorio. Lo elimina justo después de la comprobación.

Cuando Git en un servidor pide una contraseña, Spooky envía la respuesta desde tu Mac por la conexión SSH, solo al comando de Git que la pidió. Git en el servidor no la guarda, porque Spooky desactiva los gestores de credenciales de Git en sus comandos.

## En los repositorios {#repositories}

Spooky guarda algunas cosas en la propia configuración de Git del repositorio, como entradas `branch.<name>.spooky-*`:

- Qué ramas están fijadas o archivadas
- La rama padre de cada rama
- Las marcas que usa el archivado automático

Estas entradas se van con la rama cuando la renombras, y desaparecen cuando la eliminas. Los ajustes de Git que cambias en :ui[repositorySettings.title] del repositorio, como la firma, van a la misma configuración. Consulta [Ajustes del repositorio](/guide/settings/identity/#repository).

De la configuración de Git no se hace push, así que nada de esto llega a tus remotos. En un repositorio de servidor, se guarda en el servidor.

## Conexiones de red {#network}

| Spooky se conecta a | Cuándo |
|---|---|
| Tus servidores, por SSH | Mientras hay un repositorio de servidor abierto. Spooky usa el alias de host de `~/.ssh/config`. Un montaje SMB se conecta además al servicio de compartir archivos del servidor. |
| Tus remotos de Git | Cuando haces fetch, pull o push, o clonas, y durante el fetch automático. En un repositorio de servidor, Git se conecta desde el servidor, no desde tu Mac. |
| `github.com` y `api.github.com`, o la dirección de tu GitLab | Cuando añades o vuelves a autenticar una cuenta de alojamiento, y cuando usas una función que necesita una: las pull requests y merge requests, el autocompletado de números de incidencia, el estado en la revisión de ramas y la publicación de un repositorio. Estas solicitudes salen de tu Mac. Consulta [Adónde van las solicitudes](/guide/hosting/accounts/#network). |
| `gravatar.com` | Para mostrar las imágenes de los autores de los commits |
| `github.com`, por las versiones de Spooky | Para buscar actualizaciones |

El fetch automático se ejecuta cada 30 minutos de forma predeterminada. Para cambiarlo, abre :ui[app.name > settings.title], haz clic en :ui[settings.general] y elige una opción junto a :ui[settings.autoFetch]. Selecciona :ui[settings.autoFetch.never] para hacer fetch solo cuando tú lo pidas. Consulta [Operaciones](/guide/settings/general/#operations).

Para la imagen del autor de un commit, Gravatar recibe un hash de la dirección de correo del autor, no la dirección. Las imágenes descargadas solo se quedan en memoria, y desaparecen cuando sales de Spooky. Las imágenes de los usuarios de GitHub y GitLab vienen de esos servicios. No hay ningún ajuste para desactivar las imágenes.

Spooky busca actualizaciones una vez al día de forma predeterminada. Para que no lo haga, desactiva :ui[updates.automaticChecks] en :ui[app.name > settings.title] › :ui[settings.updates]. Consulta [Mantener Spooky actualizado](/guide/start/install/#updates).

Los ítems del menú :ui[menu.help], como :ui[help.help] y :ui[help.support], abren páginas web en tu navegador.

## Informes de fallos {#crash-reports}

Si Spooky se cerró inesperadamente la última vez, lee el informe de fallos que macOS guardó en tu Mac. En el siguiente arranque pregunta: :ui[crash.title].

- Haz clic en :ui[crash.report] para abrir en tu navegador la página de una nueva incidencia en GitHub, rellenada con un resumen del fallo.
- Haz clic en :ui[crash.dontReport] para omitirlo. Spooky no vuelve a preguntar por ese fallo.

El resumen incluye la versión y la compilación de Spooky, la versión de macOS, el tipo de fallo y hasta 30 líneas de la pila de llamadas del hilo que falló. Antes de que salga de tu Mac, Spooky sustituye por marcadores tu carpeta de inicio, tu nombre de usuario, las direcciones de correo, las direcciones IP, los tokens y las contraseñas de las direcciones web.

El resumen forma parte de la dirección web de la página. GitHub lo recibe en cuanto se abre la página. La incidencia solo se crea cuando la envías en el navegador. Antes puedes editar el texto, o cerrar la página.

Para saltarte la pregunta la próxima vez, selecciona :ui[settings.crashReports.always] en el diálogo. A partir de entonces, Spooky abre la página de la incidencia directamente. La misma opción está en :ui[app.name > settings.title] › :ui[settings.integration].

## Informes de diagnóstico {#diagnostic-reports}

Cuando informas de un problema, un informe de diagnóstico ayuda a ver qué pasó. Selecciona :ui[menu.help > help.diagnosticReport] y elige dónde guardarlo. Spooky guarda un archivo de texto y lo muestra en el Finder. No envía el informe a ningún sitio.

El informe contiene:

- La versión y la compilación de Spooky, la versión de macOS y tus tres primeros idiomas preferidos
- El programa de Git de este Mac y su versión
- Los ajustes que afectan a cómo se ejecuta Spooky, como la apariencia, el canal de actualizaciones, la app de terminal, las herramientas de comparación y de fusión, el agente SSH, el programa de Git y si se leen las variables de entorno del shell de inicio de sesión
- Cuántos repositorios locales y de servidor tienes
- Los nombres, las horas y los resultados de las últimas 20 operaciones
- El registro de Spooky de la última hora de la ejecución actual, hasta 500 líneas

No contiene rutas de repositorios, alias de host, contraseñas ni valores de variables de entorno. Spooky sustituye por marcadores tu carpeta de inicio, tu nombre de usuario, las direcciones de correo, las direcciones IP y los tokens, igual que en los informes de fallos. Abre el archivo y léelo antes de compartirlo.

El registro de Spooky anota los cambios de conexión, y cuándo empiezan, terminan o fallan las operaciones. No registra los argumentos ni la salida de los comandos, los mensajes de commit, las contraseñas ni los tokens.

## Consulta también

- [Instalar Spooky](/guide/start/install/)
- [Cómo funcionan los repositorios de servidor](/guide/server/overview/)
- [Cuentas de alojamiento](/guide/hosting/accounts/)
- [Requisitos del sistema](/reference/requirements/)
