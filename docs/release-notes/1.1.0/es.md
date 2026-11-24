### Novedades

- Nueva página **Hosts SSH** en los ajustes: consulta, añade, edita y elimina los alias de host de ~/.ssh/config. Haz doble clic en un alias o pulsa Retorno para editarlo; Spooky solo cambia las líneas que editas, y las demás opciones y los comentarios se quedan como están
- La lista de pull requests y merge requests puede pasar de **Abiertas** a **Todas** para mostrar también las solicitudes cerradas y las fusionadas
- Las etiquetas de las solicitudes aparecen en la lista y en **Conversación**
- Nueva vista **CI/CD** en los detalles de una solicitud: el estado general y el resultado de cada comprobación o trabajo, que se actualiza sola mientras haya algo en espera o en curso; cada fila de la lista también muestra el estado de CI/CD

### Mejoras

- Los repositorios de servidor se conectan más rápido, y los comandos de Git, la lectura y escritura de archivos y las cancelaciones también van más rápido, sobre todo en redes con mucha latencia; además, una conexión caída se detecta antes
- Al pegar varias líneas en **Asunto del commit**, la primera se queda en el asunto y el resto pasa a **Descripción detallada**
- En la ventana **Repositorios**, la tecla Retorno ahora cambia el nombre del marcador o grupo seleccionado en lugar de abrir el repositorio, y Esc cancela; para abrir un repositorio, haz doble clic. Hacer clic en el nombre de una fila seleccionada ya no inicia el cambio de nombre
- La barra de herramientas predeterminada de la ventana del repositorio incluye ahora **Finder**, **Terminal**, **Push forzado** y **Crear rama**; **Acciones rápidas**, **Sincronizar** y **Fusionar** / **Hacer rebase** se añaden desde **Personalizar barra de herramientas…** cuando haga falta. Para pasar del todo a la nueva disposición, arrastra allí el conjunto predeterminado a la barra
- Al eliminar marcadores, la casilla de la papelera aparece atenuada para un repositorio de servidor cuya carpeta ya no está en el servidor, y solo se elimina el marcador
- Al volver a abrir un repositorio de GitLab, Spooky habla de merge requests desde el principio, sin esperar a leer los remotos
- GitLab elimina la referencia a la rama de origen de una merge request 14 días después de cerrarla o fusionarla; si después intentas hacer fetch de sus commits, verás **Los commits ya no están disponibles**
- Cuando un comando de Git, como cambiar de rama o añadir al stage, falla porque no encuentra git-lfs, el error se titula ahora **Git LFS no está disponible** y explica cómo configurar PATH en un repositorio local o de servidor
- Las versiones antiguas del script de ayuda en ~/.spooky/bin de un servidor se eliminan tras 30 días sin usarse
- Términos y puntuación más coherentes en la interfaz de todos los idiomas

### Correcciones

- Escribir un archivo en un repositorio de servidor ya no daña el original si se corta la conexión o se cancela la escritura
- Una breve pausa de la red ya no interrumpe la conexión con un repositorio de servidor ni los comandos que se están ejecutando
- Después de cancelar la escritura de un archivo en un repositorio de servidor, Spooky ya no muestra la conexión como activa mientras rechaza las escrituras siguientes
- Los archivos que Git crea en un repositorio de servidor toman los permisos de la umask del inicio de sesión, igual que cuando ejecutas Git tú mismo por SSH
- Las contraseñas incluidas en las URL de los remotos ya no aparecen en los registros de actividad ni en los mensajes de error
- Dos repositorios de servidor cuyas rutas parecen iguales pero difieren en los bytes ya no comparten conexión
- Al cambiar el icono de la app varias veces seguidas, se aplica el último grupo elegido
- El elemento **Clonar** de la barra de herramientas se puede mover y quitar, y siempre aparece en **Personalizar barra de herramientas…**
- Al hacer pull, los resúmenes de actividad ya no muestran el resultado sin procesar del fetch de Git
