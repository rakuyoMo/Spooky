---
title: "Cuentas de alojamiento"
description: "Conecta cuentas de GitHub, GitLab.com y GitLab autogestionado, y descubre dónde se guardan sus tokens y para qué se usan."
---

Añade tu cuenta de GitHub o de GitLab para trabajar con pull requests y merge requests en Spooky. Git también usa la cuenta para iniciar sesión en los remotos HTTPS de ese servicio, así que no se te pide nombre de usuario ni contraseña.

## Añadir una cuenta {#add}

Abre :ui[app.name > settings.title] y haz clic en :ui[settings.accounts]. Haz clic en el botón de añadir que hay debajo de la lista, y elige dónde está la cuenta:

| Selecciona | Para | Inicia sesión con |
|---|---|---|
| :ui[accounts.add.github] | github.com | Tu navegador, o un token de acceso personal |
| :ui[accounts.add.gitlab] | GitLab.com | Un token de acceso personal |
| :ui[accounts.add.gitlabSelfManaged] | GitLab en tu propio servidor | Un token de acceso personal, o un nombre de usuario y una contraseña |

::screenshot[La hoja para añadir una cuenta de GitLab autogestionado. El host es https://gitlab.example.com, y el método de autenticación es nombre de usuario y contraseña.]{name="hosting-add-account" frame="dialog" markers="79.2,64 83.3,56.3"}

1. El host
2. El método de autenticación

Mientras Spooky comprueba la cuenta, en la parte inferior del diálogo aparece :ui[accounts.validating]. :ui[action.cancel] detiene la comprobación y deja el diálogo abierto, para que puedas corregir lo que has introducido. Si la comprobación falla, un mensaje dice por qué, y lo que has introducido sigue ahí.

Cada cuenta aparece en la lista con su servicio, su instancia y su nombre de usuario. Puedes añadir más de una cuenta del mismo servicio.

### GitHub {#github}

Con :ui[accounts.authentication.oauth] elegido junto a :ui[accounts.authentication], haz clic en :ui[accounts.add.submit]:

1. Spooky muestra un código de un solo uso, lo copia y abre GitHub en tu navegador.
2. Pega ahí el código y autoriza a Spooky. Si entretanto has copiado otra cosa, haz clic en :ui[accounts.copyCode] para volver a copiarlo.
3. Cuando has autorizado a Spooky, el diálogo se cierra y la cuenta está en la lista.

Si el código caduca o deniegas el acceso en el navegador, vuelve a empezar para obtener un código nuevo.

Para usar un token, elige :ui[accounts.authentication.token] junto a :ui[accounts.authentication]. El token necesita los ámbitos `repo` y `read:org`.

### GitLab.com {#gitlab-com}

Pega un token de acceso personal con el ámbito `api`.

### GitLab autogestionado {#self-managed}

Junto a :ui[accounts.host], introduce la dirección de tu servidor de GitLab. Incluye el puerto y la ruta si los tiene, por ejemplo `https://example.com:8443/gitlab`. Después elige cómo iniciar sesión:

- :ui[accounts.authentication.token]: un token con el ámbito `api`.
- :ui[accounts.authentication.password]: Spooky usa la contraseña solo para obtener un token, y no guarda la contraseña.

Iniciar sesión con nombre de usuario y contraseña solo funciona cuando se cumple todo esto:

- El servidor ejecuta GitLab 18.11 o anterior. GitLab 19.0 y posteriores ya no cambian una contraseña por un token.
- El servidor no exige credenciales de aplicación OAuth. GitLab 13.9 las exige siempre, y GitLab 17.8 o posterior se puede configurar para exigirlas.
- El servidor permite Git por HTTPS con contraseña.
- Tu cuenta tiene una contraseña de GitLab o de LDAP, y no usa autenticación de dos factores ni inicia sesión solo mediante inicio de sesión único.

El token que obtienes así caduca, y Spooky lo renueva por su cuenta. Si GitLab deja de renovarlo, la cuenta se marca como pendiente de volver a autenticar.

Spooky necesita GitLab 9.0 o posterior. El servidor tiene que ser accesible desde tu Mac, y tu Mac tiene que confiar en su certificado. Si no confía, marca el certificado como de confianza en **Acceso a Llaveros**.

## Gestionar las cuentas {#manage}

Todas las ventanas comparten las mismas cuentas. En :ui[app.name > settings.title] › :ui[settings.accounts]:

- Para volver a autenticar una cuenta, selecciónala y haz clic en :ui[accounts.reauthenticate] debajo de la lista. Vuelve a iniciar sesión o introduce un token nuevo. Tiene que ser el mismo usuario. Para iniciar sesión como otra persona, añade una cuenta nueva.
- Para eliminar una cuenta, selecciónala, haz clic en el botón de eliminar que hay debajo de la lista y confirma. Spooky borra su token de tu llavero.

Una cuenta marcada como :ui[accounts.needsReauthentication] tiene un token que el servicio ya no acepta, por ejemplo porque ha caducado o se ha revocado. Vuelve a autenticarla para usarla de nuevo.

Spooky aplica el cambio enseguida. Una lista de pull requests o merge requests abierta se vuelve a cargar sin reabrir la ventana.

## Para qué se usan las cuentas {#uses}

Una cuenta sirve para los remotos de su servicio:

- La lista de [pull requests y merge requests](/guide/hosting/pull-requests/)
- Los números de incidencia después de `#` en los mensajes de commit. Consulta [Autocompletar](/guide/work/commit/#autocomplete).
- El estado de las pull requests y merge requests en la [revisión de ramas](/guide/branches/review/)
- [Publicar un repositorio](#publish) en el servicio
- [Iniciar sesión en los remotos HTTPS](#git)

## Qué cuenta usa un remoto {#remotes}

Spooky compara la dirección de cada remoto con la instancia de cada cuenta: github.com, GitLab.com o tu propio servidor de GitLab.

- **Una cuenta en esa instancia**: Spooky la usa.
- **Varias cuentas en esa instancia**: la lista de pull requests te pide que elijas una. Spooky recuerda tu elección para ese remoto.
- **Ninguna cuenta todavía**: con github.com y GitLab.com, la lista lo indica y ofrece :ui[pullRequests.openAccounts].
- **La dirección no coincide**: por ejemplo, cuando el remoto usa un alias de host de `~/.ssh/config`. La lista muestra una nota con un botón :ui[pullRequests.associate]. Si el remoto pertenece a una de tus cuentas, haz clic en él y elige la cuenta y el proyecto.

Las direcciones HTTPS y SSH del mismo proyecto corresponden a la misma cuenta.

## Iniciar sesión en los remotos HTTPS {#git}

Cuando un remoto HTTPS pertenece a una de tus cuentas, Git inicia sesión con el token de la cuenta. Eso incluye clonar, hacer fetch, pull y push, y el fetch automático.

- Los remotos SSH siguen usando tus claves SSH. Las cuentas no los cambian.
- Para estas direcciones, Spooky responde en lugar de cualquier gestor de credenciales que tengas configurado en Git, como el del llavero de macOS. Esos gestores no ven ni guardan el token.
- Si tienes varias cuentas en la misma instancia y no has elegido una para el remoto, Git te pide nombre de usuario y contraseña como siempre.

Si Git rechaza el token, ese comando falla. A partir de ahí, Git te pide nombre de usuario y contraseña en los remotos de esa cuenta, y el diálogo dice que no se aceptó el token de la cuenta. Vuelve a autenticar la cuenta para iniciar sesión otra vez con ella.

:::note[Repositorios de servidor]
Git en el servidor también inicia sesión con el token. Se lo pide a Spooky en tu Mac cada vez que lo necesita. El token no se guarda en el servidor.
:::

## Dónde se guardan los tokens {#storage}

- La lista de cuentas está en las preferencias de Spooky, sin los tokens.
- Los tokens están en tu llavero, en ítems llamados `com.rakuyo.spooky.hosting.<address>`.
- Si inicias sesión en un GitLab autogestionado con nombre de usuario y contraseña, Spooky conserva los tokens que recibe a cambio. No conserva la contraseña.

Los tokens no entran en los registros de :ui[activity.title] ni en los registros de Spooky.

## Adónde van las solicitudes {#network}

Spooky se comunica con el servicio desde tu Mac, incluso con los repositorios de servidor:

- GitHub: `github.com` mientras autorizas en el navegador, y `api.github.com` para todo lo demás.
- GitLab: `gitlab.com`, o la dirección de tu propio GitLab.

Lo hace cuando añades o vuelves a autenticar una cuenta, y cuando usas aquello para lo que sirve la cuenta: la lista de pull requests y merge requests y lo que haces en ella, los números de incidencia después de `#`, el estado en la revisión de ramas y la publicación de un repositorio. Las cuentas con sesión iniciada con nombre de usuario y contraseña también renuevan ahí sus tokens.

Cada una de estas solicitudes aparece en la página :ui[activity.service] de la ventana :ui[activity.title].

Las imágenes de los usuarios de GitHub y GitLab vienen de las direcciones que dan esos servicios. Las imágenes descargadas solo se quedan en memoria, y desaparecen cuando sales de Spooky.

Git, por su parte, se conecta al remoto desde donde está el repositorio. Con un repositorio de servidor, es el servidor. Consulta [Datos y privacidad](/reference/data-privacy/#network).

## Publicar un repositorio {#publish}

Para crear un repositorio en GitHub o GitLab a partir del que tienes abierto, selecciona :ui[menu.repository > publish.menu] en la barra de menús. También puedes hacer clic derecho en :ui[workspace.title] en la barra lateral y seleccionar :ui[workspace.publishMenu] en el menú. Si el repositorio aún no tiene ningún remoto, :ui[sync.push] abre también este diálogo. Necesitas al menos una cuenta.

| Campo | Qué hace |
|---|---|
| :ui[publish.remote] | El nombre del nuevo remoto. Empieza como `origin`, o como `origin-2` si el repositorio ya tiene un `origin`. |
| :ui[pullRequests.account] | Dónde crear el repositorio: en tu propio usuario, o en una organización o grupo al que perteneces |
| :ui[publish.name] | El nombre en el servicio. Empieza como el nombre de la carpeta del repositorio. |
| :ui[pullRequests.description] | Opcional |
| :ui[publish.visibility] | :ui[publish.visibility.private] o :ui[publish.visibility.public]. GitLab tiene además :ui[publish.visibility.internal]. |
| :ui[publish.target] | La dirección HTTPS que usará el remoto |

Cuando haces clic en :ui[publish.submit], Spooky:

1. Crea un repositorio vacío en el servicio.
2. Lo añade como remoto, con la dirección HTTPS.
3. Hace push de todas las ramas y etiquetas locales. Las ramas sin upstream empiezan a seguir a su nueva rama remota. Las que ya tienen uno lo conservan.

Si ya existe un repositorio con ese nombre, Spooky lo indica y no lo sobrescribe. Elige otro nombre. Si el push falla, el nuevo remoto y el repositorio del servicio se quedan, así que puedes volver a hacer push.

La publicación no se puede deshacer con <kbd>⌘Z</kbd>, y las operaciones anteriores tampoco se pueden deshacer ya.

## Consulta también

- [Pull requests y merge requests](/guide/hosting/pull-requests/)
- [Solicitudes de contraseña y de frase de contraseña](/guide/server/connection/#prompts)
- [Datos y privacidad](/reference/data-privacy/)
