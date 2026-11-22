---
title: "Fetch, pull y push"
description: "Haz fetch, pull y push, publica una rama por primera vez, sincroniza, haz push forzado y haz fetch automáticamente."
---

Estas operaciones intercambian commits con los [remotos](/guide/branches/tags-remotes/#remotes):

- Fetch descarga los commits nuevos de un remoto. Tus ramas y la copia de trabajo se quedan como están.
- Pull hace fetch de una rama remota y trae sus commits a la rama en la que estás.
- Push envía tus commits a una rama remota.

La barra de herramientas tiene :ui[sync.fetch], :ui[sync.pull] y :ui[sync.push] uno junto al otro, y :ui[sync.sync] a su lado. Las mismas operaciones están en el menú :ui[menu.repository].

Fetch, pull, push y la sincronización no se registran en el historial de deshacer, así que no se pueden deshacer. Publicar una rama sí se puede deshacer.

:::note[Repositorios de servidor]
A los remotos se accede desde el servidor, con la red y las claves SSH del servidor. Cuando un remoto pide una contraseña, Spooky te la pide a ti. Consulta [Solicitudes de contraseña y de frase de contraseña](/guide/server/connection/#prompts).
:::

## Fetch {#fetch}

1. Haz clic en :ui[sync.fetch] en la barra de herramientas, o selecciona :ui[menu.repository > sync.fetchMenu] (<kbd>⇧⌘F</kbd>). Para hacer fetch de un solo remoto, haz clic derecho en él en la barra lateral y selecciona :ui[remote.fetchMenu]{1="origin"} en el menú.
2. Elige el remoto en :ui[sync.remote], o selecciona :ui[sync.allRemotes].
3. Ajusta las opciones:
   - :ui[sync.prune] quita las ramas remotas que se eliminaron en el remoto. Al principio está activado.
   - :ui[sync.fetchSubmodules] hace fetch también de los commits nuevos de los submódulos que tienen checkout.
   - :ui[sync.allTags] hace fetch también de todas las etiquetas del remoto.
4. Haz clic en :ui[sync.fetch].

Spooky recuerda todas las opciones menos :ui[sync.allTags].

Después de un fetch, las ramas remotas de la barra lateral están al día, y ↓ en una rama local cuenta los commits de los que puedes hacer pull.

:ui[menu.repository > sync.fetchAll] hace fetch de todos los remotos enseguida, sin el diálogo. Se salta los remotos que tienen :ui[remote.skipFetchAll] en sus [ajustes](/guide/branches/tags-remotes/#remote-settings).

## Pull {#pull}

1. Haz clic en :ui[sync.pull] en la barra de herramientas, o selecciona :ui[menu.repository > sync.pullMenu] (<kbd>⇧⌘P</kbd>). Para hacer pull de una rama remota concreta, haz clic derecho en ella y selecciona :ui[branch.pullMenu]{1="origin/main"} en el menú.
2. Elige la rama en :ui[sync.remoteBranch]. Al principio es el [upstream](/guide/branches/branches/#track) de la rama en la que estás.
3. Selecciona :ui[sync.rebase] para poner tus commits encima de los descargados, en lugar de unir los dos con un commit de fusión. Spooky recuerda esta elección.
4. Debajo de las opciones, una previsión dice si el pull va a dar conflictos. Consulta [Consultar los conflictos antes](/guide/branches/merge-rebase/#preview).
5. Ajusta las opciones:
   - :ui[merge.verify] detiene el pull salvo que el commit descargado tenga una firma de confianza. Spooky lo recuerda.
   - :ui[sync.skipHooks] omite esta vez los hooks de Git del repositorio.
6. Haz clic en :ui[sync.pull].

Para un pull, tus archivos con seguimiento tienen que estar sin cambios. Si no lo están, Spooky te ofrece guardar antes los cambios en un stash. Consulta [Stash automático](/guide/work/stash/#auto-stash). Los archivos nuevos solo estorban cuando el pull los sobrescribiría.

Si el pull da conflictos, Spooky cambia a la copia de trabajo y muestra un aviso. Consulta [Resolver conflictos](/guide/work/conflicts/#banner).

## Push {#push}

1. Haz clic en :ui[sync.push] en la barra de herramientas, o selecciona :ui[menu.repository > sync.pushMenu] (<kbd>⇧⌘U</kbd>).
2. Elige la rama remota en :ui[sync.destination]. Al principio es el upstream de la rama en la que estás.
3. Ajusta las opciones:
   - :ui[sync.pushAllTags] hace push también de todas las etiquetas locales.
   - :ui[sync.forcePush] sobrescribe la rama remota cuando un push normal no puede. Consulta [Push forzado](#force-push).
   - :ui[sync.pushSubmodules] se ocupa de los commits de submódulos a los que hace referencia este push. Elige entre :ui[sync.pushSubmodules.onDemand] y :ui[sync.pushSubmodules.check].
   - :ui[sync.skipHooks] omite esta vez los hooks de Git del repositorio.
4. Haz clic en :ui[sync.pushHead].

Spooky recuerda las opciones de etiquetas y de submódulos.

Si la rama en la que estás aún no sigue a ninguna rama remota, :ui[sync.push] abre el diálogo de publicación. Consulta [Publicar una rama](#publish). Si el repositorio no tiene ningún remoto, abre el diálogo para publicar el repositorio. Consulta [Publicar un repositorio](/guide/hosting/accounts/#publish).

Si otra persona hizo push antes a la rama remota, el remoto rechaza tu push. Haz pull de sus commits y vuelve a hacer push.

Para hacer push de una rama en la que no estás, arrástrala sobre una rama remota en la barra lateral. El diálogo :ui[sync.pushBranch] hace push de ella ahí. Es un push sencillo, sin opciones, y no cambia a qué sigue la rama.

## Publicar una rama {#publish}

Una rama nueva solo existe en tu repositorio hasta que la publicas, que es crearla en un remoto.

1. Selecciona :ui[menu.repository > sync.publishMenu], o haz clic derecho en la rama y selecciona :ui[branch.publishMenu]{1="feature/station-map"} en el menú. También puedes arrastrar la rama sobre un remoto en la barra lateral.
2. Revisa :ui[branch.local] y :ui[sync.remote]. :ui[branch.name] es el nombre en el remoto, al principio el mismo que el nombre local.
3. :ui[sync.setUpstream] hace que tu rama siga a la nueva rama remota, de modo que los pull y push posteriores vayan ahí. Al principio está activado.
4. Selecciona :ui[sync.skipHooks] para omitir los hooks de Git del repositorio.
5. Haz clic en :ui[sync.publish].

Para dar marcha atrás, selecciona :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

## Sincronizar {#sync}

La sincronización hace fetch, pull y push de la rama en la que estás, uno detrás de otro.

1. Haz clic en :ui[sync.sync] en la barra de herramientas, o selecciona :ui[menu.repository > sync.syncMenu] (<kbd>⇧⌘Y</kbd>).
2. Elige la rama en :ui[sync.remoteBranch]. Al principio es el upstream de la rama en la que estás.
3. Selecciona :ui[sync.rebase] si quieres. La previsión de debajo dice si el pull va a dar conflictos.
4. Ajusta las opciones: :ui[merge.verify], :ui[sync.pushAllTags], :ui[sync.pushSubmodules] y :ui[sync.skipHooks] funcionan igual que en pull y push.
5. Haz clic en :ui[sync.syncHead].

Igual que con pull, Spooky te ofrece guardar antes en un stash los cambios de los archivos con seguimiento.

Si un paso falla, Spooky se detiene ahí y te dice en qué paso se ha detenido y qué pasos se han hecho. En :ui[activity.title], el pull y el push tienen cada uno su registro.

## Hacer push a otro sitio {#push-to}

Para hacer push de una rama, etiqueta o commit a cualquier rama o referencia de un remoto:

1. Selecciona :ui[menu.repository > sync.pushToMenu], o haz clic derecho en una rama y selecciona :ui[branch.pushToMenu]{1="main"} en el menú. Las etiquetas también tienen :ui[tag.pushToMenu]{1="v0.4.0"} en su menú.
2. Elige de qué hacer push en :ui[sync.revision], y el remoto en :ui[sync.remote].
3. En :ui[sync.refSpec], escribe adónde va: un nombre de rama nuevo o existente, o una referencia completa como `refs/tags/v0.4.0`.
4. Haz clic en :ui[sync.pushRevision].

Con una rama, el diálogo empieza con la rama remota a la que sigue. Con una etiqueta, empieza con `refs/tags/` y el nombre de la etiqueta.

## Push forzado {#force-push}

Después de reescribir commits de los que ya habías hecho push, por ejemplo al enmendar o hacer rebase, un push normal se rechaza: la rama remota tiene commits que tu rama ya no tiene. Un push forzado sustituye la rama remota por la tuya.

Spooky solo hace push forzado con lease. El push solo sale adelante si la rama remota sigue donde estaba la última vez que hiciste fetch. Si alguien hizo push entretanto, Git lo rechaza y no se sobrescribe nada. Spooky nunca recurre a un push forzado sin protección.

1. Selecciona :ui[menu.repository > sync.forcePushMenu] (<kbd>⌃⌘U</kbd>), o haz clic derecho en una rama local y selecciónalo en el menú.
2. Elige la rama local en :ui[branch.target], y la rama remota en :ui[sync.destination].
3. Lee la comparación que hay debajo. Dice cuántos commits añade el push a la rama remota y cuántos sobrescribe. Después:
   - Una línea verde significa que la rama remota está en la versión que tenía tu rama antes de que la reescribieras. Es el caso habitual.
   - Una línea amarilla significa que la rama remota está en otro punto, o tiene commits que tu rama nunca tuvo. Comprueba que de verdad quieres sobrescribirlos.
   - Si las dos ramas están en el mismo commit, no hay nada de lo que hacer push.
4. Haz clic en :ui[sync.forcePush].

::screenshot[El diálogo de push forzado con lease. La rama local es feature/units-toggle y la rama remota es origin/feature/units-toggle. Debajo, una línea con una marca de verificación verde dice que la rama remota está en la versión que tenía esta rama antes de reescribirse.]{name="branches-force-push" frame="dialog" markers="16.4,64.8"}

1. La comparación

La opción :ui[sync.forcePush] del diálogo de push usa la misma protección.

:::tip
Selecciona :ui[menu.view > menu.customizeToolbar] para añadir :ui[toolbar.forcePush] y :ui[toolbar.pushTo] a la barra de herramientas.
:::

## Versiones rápidas {#quick}

Mantén pulsada <kbd>⌥</kbd>, y :ui[sync.fetch], :ui[sync.pull], :ui[sync.push] y :ui[sync.sync] de la barra de herramientas se convierten en :ui[sync.quickFetch], :ui[sync.quickPull], :ui[sync.quickPush] y :ui[sync.quickSync]. Los ítems de menú cambian de la misma manera, por ejemplo :ui[sync.quickPushMenu].

Una versión rápida se ejecuta enseguida, sin el diálogo:

- Trabaja con el upstream de la rama en la que estás.
- Usa las opciones que elegiste la última vez en el diálogo. :ui[sync.skipHooks] nunca se conserva.
- :ui[sync.quickFetch] hace fetch del remoto al que sigue la rama actual. Hace fetch de todos los remotos cuando la última vez elegiste :ui[sync.allRemotes], o cuando la rama no sigue a nada.
- Si la rama en la que estás no sigue a ninguna rama remota, :ui[sync.quickPush] y :ui[sync.quickSync] te lo dicen.

Los menús contextuales también tienen versiones rápidas, como :ui[sync.quickFetchNamed]{1="origin"} para un remoto y :ui[sync.quickPullNamed]{1="origin/main"} para una rama remota.

## Hacer fetch automáticamente {#auto-fetch}

Spooky puede hacer fetch en segundo plano, para que las ramas remotas y los contadores ↓ estén al día. Elige cada cuánto en :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.autoFetch]: :ui[settings.autoFetch.never], cada 5, 10 o 30 minutos, o :ui[settings.autoFetch.hour]. Al principio es cada 30 minutos. Consulta [Operaciones](/guide/settings/general/#operations).

- Spooky busca los remotos a los que les toca unos 10 segundos después de abrirse un repositorio, y después cada pocos minutos. A un remoto le toca cuando nunca se ha hecho fetch de él, o cuando ha pasado el intervalo desde su último fetch.
- Solo hace fetch mientras la ventana muestra el repositorio y no hay ningún diálogo abierto. Sigue haciéndolo mientras Spooky está en segundo plano.
- Solo empieza cuando no hay nada más en marcha en el repositorio. Si inicias algo mientras hace fetch, se detiene y deja pasar lo tuyo. :ui[activity.title] anota por qué operación se detuvo.
- Nunca pide contraseñas. Si falla, el error solo aparece en :ui[activity.title].
- Usa las opciones de poda y de submódulos que elegiste la última vez en el diálogo de fetch, y se salta los remotos que tienen :ui[remote.skipFetchAll].
- En un repositorio local, se salta los remotos que son rutas de tu Mac, y no hace fetch mientras el Mac no tiene conexión.

## Consulta también

- [Fusionar y hacer rebase](/guide/branches/merge-rebase/)
- [Ramas](/guide/branches/branches/)
- [Cola de operaciones y actividad](/guide/advanced/queue-activity/)
- [Stashes](/guide/work/stash/)
