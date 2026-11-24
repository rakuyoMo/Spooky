---
title: "Hacer commit de los cambios"
description: "Escribe el asunto y la descripción de un commit, usa el autocompletado, enmienda el último commit y elige la identidad y la firma de un commit."
---

Un commit guarda los cambios del stage en el historial del repositorio, junto con un mensaje. Añade primero los cambios al stage, como se describe en [Revisar y añadir cambios al stage](/guide/work/diff/). Después escribe el mensaje en el área de commit, en la parte superior de la copia de trabajo.

## Escribir el mensaje {#write}

El mensaje tiene dos partes:

- :ui[working.subject] es una línea corta que resume el cambio. Pulsa <kbd>Retorno</kbd> o <kbd>Tab</kbd> para pasar a la descripción. Si pegas varias líneas aquí, la primera se queda en el asunto. El resto va al final de la descripción.
- :ui[working.body] es opcional. Úsala para explicar qué ha cambiado y por qué.

::screenshot[El área de commit, expandida. El asunto dice Add a units toggle, con una descripción de dos líneas debajo. En la parte inferior de la descripción están los botones de fijar y de ajuste de línea. Debajo están las casillas Enmendar y Firmar (Signed-off-by), con el nombre, el correo y la imagen del autor a la derecha. Los botones Añadir todo al stage y Hacer commit están abajo.]{name="work-commit-area" frame="closeup" markers="62,12 24,56 94.6,69.1"}

1. :ui[working.subject]
2. El botón de fijar y el botón de ajuste de línea
3. La imagen del autor

El área de commit se expande mientras escribes en cualquiera de los dos campos, y sigue abierta mientras la descripción tenga texto. Para tenerla siempre abierta, haz clic en el botón de fijar, en la parte inferior de la descripción. Arrastra el borde inferior de la descripción para hacerla más alta o más baja.

Cuando empiezas a escribir, el número del final del asunto cuenta los caracteres que te quedan. Los caracteres que pasan del límite se resaltan.

El otro botón de la parte inferior de la descripción cambia entre dos formas de ajustar las líneas:

- :ui[editor.softWrap] ajusta las líneas al borde del campo.
- :ui[editor.hardWrap] usa un tipo de letra de ancho fijo y no ajusta las líneas. Una guía marca el límite de caracteres, y las líneas más largas se resaltan. Para partir el párrafo actual en el límite, selecciona :ui[menu.edit > commit.reformatParagraph] (<kbd>⇧⌘W</kbd>).

Estas opciones están en :ui[app.name > settings.title] › :ui[settings.editor]:

| Ajuste | Valor predeterminado |
|---|---|
| :ui[editor.showsCounter] | Activado |
| :ui[editor.subjectLimit] | 50 |
| :ui[editor.wrapping] | :ui[editor.softWrap] |
| :ui[editor.bodyLimit] | 72. Puedes cambiarlo cuando está elegido :ui[editor.hardWrap]. |
| :ui[editor.showsGuide] | Activado. Se usa con :ui[editor.hardWrap]. |
| :ui[editor.warnsComments] | Activado. Consulta [Comentarios en el mensaje](#comments). |
| :ui[editor.stripsComments] | Desactivado. Disponible cuando el aviso está desactivado. |
| :ui[editor.completesIssues] | Activado. Consulta [Autocompletar](#autocomplete). |

Consulta [Editor](/guide/settings/appearance/#editor).

## Hacer commit {#commit}

Cuando el mensaje esté listo, haz clic en :ui[working.commit], o pulsa <kbd>⌘↩</kbd> mientras escribes en el mensaje. El botón sigue atenuado hasta que el asunto tiene texto y hay cambios en el stage.

Para saltar al asunto desde cualquier lugar de la ventana, selecciona :ui[workspace.title > working.commitMenu] (<kbd>⇧⌘C</kbd>).

Dos casillas que hay bajo la descripción cambian el commit:

- :ui[commit.signOff] añade al final del mensaje una línea `Signed-off-by` con tu nombre y tu correo. La casilla se queda como la dejaste, en todos los repositorios.
- :ui[commit.skipHooks] hace commit sin ejecutar los hooks `pre-commit` y `commit-msg` del repositorio. Solo aparece cuando el repositorio tiene esos hooks, y se desactiva de nuevo después de cada commit.

Si el commit falla, tu mensaje se queda en el área de commit. Para deshacer un commit que acabas de hacer, selecciona :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>). Consulta [Deshacer y recuperar](/guide/work/undo/).

### Comentarios en el mensaje {#comments}

Las líneas que empiezan por `#` cuentan como comentarios en Git, salvo que hayas definido otro carácter de comentario. Spooky hace commit del mensaje tal como lo escribiste, así que pregunta antes cuando el mensaje tiene líneas así: :ui[commit.comments]

- :ui[commit.removeComments] hace commit sin esas líneas.
- :ui[commit.keepComments] hace commit con ellas tal como están.

Marca :ui[commit.doNotAskAgain] para conservar tu elección la próxima vez. Para recuperar la pregunta, activa :ui[editor.warnsComments] en :ui[app.name > settings.title] › :ui[settings.editor]. Consulta [Editor](/guide/settings/appearance/#editor).

Si el mensaje no tiene más que comentarios, Spooky pregunta :ui[commit.commentsOnly] Haz clic en :ui[commit.keepCommentsAndCommit] para hacer commit con ellos de todos modos.

## Autocompletar {#autocomplete}

Escribe una de estas cosas en el asunto o en la descripción, y Spooky muestra las coincidencias a medida que sigues escribiendo:

| Escribe | Para insertar |
|---|---|
| `c:` | El hash corto de uno de los últimos 100 commits. Escribe parte del hash, del asunto o del autor. |
| `\` | La ruta de un archivo que está en el stage |
| `#` | El número de una incidencia abierta en GitHub o GitLab |
| `fixup!` o `squash!` al principio del asunto | El asunto de un commit anterior, para marcar este commit como una corrección de aquel |

::screenshot[El asunto del commit después de escribir c:. Una lista debajo muestra los commits recientes, cada uno con el autor, la fecha, el hash corto y el asunto. El primero está seleccionado.]{name="work-commit-completion" frame="closeup"}

Pulsa <kbd>↑</kbd> o <kbd>↓</kbd> para elegir una coincidencia, <kbd>Retorno</kbd> para insertarla y <kbd>Esc</kbd> para cerrar la lista.

Los números de incidencia necesitan una [cuenta de alojamiento](/guide/hosting/accounts/) para el remoto del repositorio, y :ui[editor.completesIssues] activado en :ui[app.name > settings.title] › :ui[settings.editor]. Consulta [Editor](/guide/settings/appearance/#editor). Un commit marcado con `fixup!` o `squash!` se puede incorporar más adelante a su destino, como se describe en [Reescribir el historial](/guide/history/rewrite/).

## Enmendar el último commit {#amend}

Enmendar sustituye el último commit por uno nuevo. Úsalo para corregir el mensaje o para añadir cambios que olvidaste.

1. Marca :ui[working.amend] bajo la descripción. Spooky rellena el mensaje del último commit, y la casilla muestra el hash corto de ese commit.
2. Edita el mensaje y añade al stage los cambios que deban entrar.
3. Haz clic en :ui[working.amend].

Desmarca la casilla para volver al mensaje que estabas escribiendo antes.

Para enmendar rápido, mantén pulsada <kbd>⌥</kbd> mientras no se esté editando ninguno de los campos del mensaje. El área de commit pasa a enmendar el último commit hasta que sueltas la tecla. Haz clic en :ui[working.amend] mientras mantienes pulsada la tecla, o pulsa <kbd>⌥⌘↩</kbd>. El commit conserva su mensaje e incorpora los cambios del stage.

:::caution
Si ya hiciste push del último commit, enmendarlo lo hace distinto del que hay en el remoto. Para hacer push de él hará falta un push forzado. Consulta [Push forzado](/guide/branches/sync/#force-push).
:::

Para cambiar un commit más antiguo, consulta [Reescribir el historial](/guide/history/rewrite/).

## Elegir quién hace el commit {#identity}

El nombre y el correo que hay a la derecha de las casillas se registran en el commit como su autor. Vienen de los ajustes `user.name` y `user.email` de Git. La imagen que hay junto a ellos se busca por la dirección de correo. Consulta [Datos y privacidad](/reference/data-privacy/).

Para hacer commit como otra persona, por ejemplo con tu correo del trabajo, usa un perfil de usuario:

1. Haz clic en la imagen. Un menú muestra tus perfiles, con una marca junto al que está en uso.
2. Elige un perfil.
3. Comprueba qué ajustes va a escribir Spooky y haz clic en :ui[profiles.apply.submit].

El nombre, el correo y la clave de firma del perfil se guardan en los ajustes de Git de este repositorio, así que los demás repositorios no se ven afectados.

Si la identidad actual aún no es un perfil, el menú ofrece :ui[profiles.addCurrent]{1="alex@example.com"} para guardarla como tal. Para configurar los perfiles, selecciona :ui[profiles.manage] en el mismo menú. Consulta [Perfiles de usuario](/guide/settings/identity/#profiles).

:::note[Repositorios de servidor]
El perfil se guarda en los ajustes del repositorio en el servidor. Otras herramientas que hacen commit en el mismo repositorio del servidor también lo usan.
:::

## Firmar commits {#signing}

Un commit firmado lleva la prueba de que viene del propietario de una clave. Spooky funciona con claves SSH y OpenPGP.

Deja el puntero sobre la imagen del área de commit para ver si el próximo commit irá firmado, y con qué clave.

- **Para todos los repositorios**: activa :ui[gitConfig.signCommits] y elige :ui[gitConfig.signingKey] en :ui[app.name > settings.title] › :ui[settings.gitConfig]. Consulta [Firma](/guide/settings/identity/#signing).
- **Para un repositorio**: haz clic en :ui[repositorySettings.title] en la barra lateral. En :ui[repositorySettings.signing], configura :ui[repositorySettings.signCommits] y :ui[repositorySettings.signingKey]. Consulta [Ajustes del repositorio](/guide/settings/identity/#repository).

Si la clave necesita una frase de contraseña, Spooky la pide en un diálogo :ui[signing.unlock].

## Consulta también

- [Revisar y añadir cambios al stage](/guide/work/diff/)
- [Deshacer y recuperar](/guide/work/undo/)
- [Perfiles de usuario y configuración de Git](/guide/settings/identity/)
