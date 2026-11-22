---
title: "Pull requests y merge requests"
description: "Consulta, crea y comenta pull requests en GitHub y merge requests en GitLab, haz checkout de ellas, fusiónalas y ciérralas."
---

Spooky muestra las pull requests abiertas en GitHub y las merge requests abiertas en GitLab del remoto de un repositorio. Puedes leerlas y comentarlas, hacer checkout de ellas, fusionarlas y crear otras nuevas, sin salir de la ventana del repositorio.

Hace falta una [cuenta de alojamiento](/guide/hosting/accounts/) para el remoto. Cuando el remoto está en GitLab, la barra lateral, los menús y los diálogos dicen merge request en lugar de pull request.

## Abrir la lista {#list}

Haz clic en :ui[pr.title] en la barra lateral, o selecciona :ui[menu.view > pr.show.menu] (<kbd>⌘4</kbd>).

Elige un remoto en el menú de la parte superior de la lista. Cada fila muestra:

- El título, marcado con :ui[pullRequests.state.draft] en los borradores
- El número, el autor y cuándo se abrió
- La rama de origen y la rama a la que va. En una solicitud desde un fork, la rama de origen va con su proyecto.

Desplázate hasta el final para cargar más. Las solicitudes cerradas y las fusionadas no aparecen.

Si la lista no se puede cargar, dice por qué. Las solicitudes que ya había cargado siguen debajo. Cuando el token de la cuenta se rechaza o le falta un ámbito, puedes hacer clic en :ui[accounts.reauthenticate] ahí mismo.

Cuando la lista no sabe qué cuenta usar, consulta [Qué cuenta usa un remoto](/guide/hosting/accounts/#remotes).

## Leer una solicitud {#details}

Selecciona una solicitud para verla a la derecha. Arriba puedes cambiar entre tres vistas:

- :ui[pullRequests.conversation]: el título y el estado, la descripción, los comentarios y los commits agrupados por día, del más antiguo al más reciente.
- :ui[pullRequests.commits]: los commits de la solicitud. La barra de encima muestra los colaboradores y cuántos commits hay.
- :ui[pullRequests.changeset]: lo que cambia la solicitud, comparado con el punto en el que se separó su rama de origen.

En la conversación, haz doble clic en un commit o pulsa <kbd>Retorno</kbd> para abrirlo. Haz clic derecho en un commit para copiar su hash. Haz clic en un enlace del texto para abrirlo.

:ui[pullRequests.commits] y :ui[pullRequests.changeset] necesitan que los commits de la solicitud estén en tu repositorio. Si aún no están, haz clic en :ui[pullRequests.fetch]. Spooky los trae del remoto sin cambiar tus ramas.

## Crear una solicitud {#create}

La rama de origen ya tiene que estar en un remoto. Haz antes push de ella, y después haz una de estas cosas:

- Haz clic en el botón de añadir de la parte superior de la lista.
- Selecciona :ui[menu.repository > pr.create.menu] (<kbd>⌃⌘P</kbd>).
- Haz clic derecho en una rama de la barra lateral y selecciona :ui[pr.forBranch.create]{1="feature/units-toggle"} en el menú. Si la rama ya tiene una solicitud abierta, el ítem es :ui[pr.forBranch.show]{1="feature/units-toggle"}.

En el diálogo:

1. Junto a :ui[pullRequests.source] y :ui[pullRequests.target], elige un remoto y una rama de ese remoto. El origen empieza siendo la rama en la que hiciste clic derecho o la rama actual, y el destino, la rama predeterminada del remoto. Solo aparecen los remotos de la misma instancia que la cuenta. Un origen en otro proyecto crea una solicitud desde un fork.
2. El título empieza siendo el nombre de la rama de origen. La descripción es opcional.
3. Haz clic en :ui[pr.create.submit].

El origen y el destino no pueden ser la misma rama.

## Comentar {#discuss}

Para añadir un comentario, haz clic en :ui[pullRequests.addComment] al final de la conversación, o pulsa <kbd>⌘S</kbd>.

En tus propios comentarios, usa :ui[pullRequests.comment.edit] y :ui[pullRequests.comment.delete] en el comentario, o haz clic derecho en él. Hacer doble clic en tu comentario también lo abre para editarlo. Eliminar un comentario no se puede deshacer.

En GitLab, también puedes responder a cualquier comentario con :ui[pullRequests.comment.reply]. La respuesta entra en la misma discusión en GitLab.

En tu propia solicitud, también puedes:

- Cambiar la descripción: haz clic en :ui[pullRequests.edit] junto a ella, o haz clic derecho en ella y selecciona :ui[pullRequests.editDescription.menu] en el menú.
- Cambiar el título, la descripción y la rama de destino: haz doble clic en la solicitud en la lista, o haz clic derecho en ella y selecciona :ui[pr.edit.menu]{1="#12"} en el menú. El origen y el proyecto de destino se quedan como están.

## Hacer checkout de una solicitud {#checkout}

Para trabajar con el código de una solicitud, haz clic en :ui[pullRequests.checkout] en la parte inferior de los detalles, o haz clic derecho en la solicitud y selecciona :ui[pr.checkout.menu]{1="#12"} en el menú.

Introduce un nombre para la rama local y haz clic en :ui[pullRequests.checkout]. El nombre empieza siendo el de la rama de origen. En una solicitud desde un fork, es `pullrequests/<author>/<branch>`.

Spooky trae primero los commits de la solicitud, y después hace checkout de la rama:

- Si una rama local con ese nombre ya apunta a ellos, Spooky hace checkout de ella.
- Si apunta a otro sitio, el diálogo lo indica. Elige otro nombre.
- En los demás casos, Spooky crea la rama. En una solicitud del mismo proyecto, la rama sigue a la rama de origen del remoto, siempre que esté en el mismo commit.

Cuando tienes cambios en archivos con seguimiento, Spooky pregunta si quieres guardarlos antes en un stash. Consulta [Stash automático](/guide/work/stash/#auto-stash).

El checkout no está disponible cuando la rama local que sigue a la rama de origen tiene commits de los que no has hecho push. Tampoco está disponible cuando esa rama es la rama actual y ya está en el commit de la solicitud.

## Fusionar una solicitud {#merge}

Haz clic en :ui[pullRequests.merge] en la parte inferior de los detalles. La fusión se hace en el servicio de alojamiento. No se puede deshacer.

- **GitHub**: elige un :ui[pullRequests.mergeType] entre los que permite el repositorio: :ui[pullRequests.method.merge], :ui[pullRequests.method.rebase] o :ui[pullRequests.method.squash]. Spooky elige el que usaste la última vez.
- **GitLab**: el diálogo muestra la :ui[pullRequests.mergeStrategy] del proyecto. Selecciona :ui[pullRequests.squash] para hacer squash. La opción no aparece cuando el proyecto no permite el squash. Se queda activada cuando el proyecto lo exige.

:ui[pullRequests.deleteBranch] elimina la rama de origen en el servicio. Empieza con el valor del ajuste del proyecto.

Si la solicitud no se puede fusionar, el diálogo dice por qué. Por ejemplo, es un borrador, tiene conflictos, tu cuenta no tiene permiso para fusionar, o el servicio todavía lo está comprobando.

Después de la fusión, Spooky hace fetch del remoto para poner al día sus ramas.

## Cerrar una solicitud {#close}

Haz clic en :ui[pullRequests.close] en la parte inferior de los detalles, y confirma. Para volver a abrirla, ve al servicio de alojamiento.

:::note[Repositorios de servidor]
La lista y todo lo que haces en el servicio salen de tu Mac. Traer los commits de una solicitud, hacer checkout de ella y el fetch posterior a una fusión se ejecutan en el servidor. También las comparaciones de :ui[pullRequests.commits] y :ui[pullRequests.changeset].
:::

Cada solicitud enviada al servicio aparece en la página :ui[activity.service] de la ventana :ui[activity.title].

## Consulta también

- [Cuentas de alojamiento](/guide/hosting/accounts/)
- [Ramas](/guide/branches/branches/)
- [Revisión de ramas](/guide/branches/review/)
