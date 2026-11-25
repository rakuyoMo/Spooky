### Novedades

- Cuando la ventana del repositorio es demasiado estrecha para tres columnas, cambia a un diseño para ventanas estrechas: una fila bajo la barra de herramientas sustituye a la barra lateral y permite cambiar entre **Copia de trabajo**, **Historial** y **Stashes**, y la lista queda encima de los detalles. Haz clic en **Barra lateral** al principio de la fila para abrir la barra lateral completa encima de la vista. Ensancha la ventana y vuelven las tres columnas con la anchura que tenían; la vista en la que estás, tu selección y el mensaje de commit que estás escribiendo se mantienen
- En una ventana estrecha, los botones que no caben en la barra de herramientas pasan al menú », mientras que **Hacer fetch**, **Hacer pull** y **Hacer push** se quedan en la barra de herramientas
- En la vista **CI/CD** de los detalles de una solicitud, una comprobación o un trabajo que tiene registro se puede desplegar para mostrar el registro debajo de su fila. Los trabajos de GitHub Actions tienen registro cuando terminan; se puede desplegar cualquier trabajo de un pipeline de GitLab y, mientras un trabajo está en ejecución, su registro se actualiza junto con el estado
- Puedes añadir y quitar las etiquetas de una solicitud en **Conversación**: haz clic en la × que hay tras el nombre de una etiqueta para quitarla, en **Añadir** para elegir una de las etiquetas del proyecto, o usa **Nueva etiqueta…** para crear una y añadirla a la solicitud

### Mejoras

- La lista de pull requests y merge requests muestra ahora el estado de cada solicitud con un icono delante del título, en lugar del texto que había detrás: verde en una solicitud abierta, gris en un borrador, rojo en una cerrada y morado en una fusionada

### Correcciones

- macOS ya no vuelve a pedir la contraseña de tu llavero después de cada actualización de Spooky cuando Spooky lee el token de una cuenta o las credenciales guardadas en el llavero. Tras instalar esta versión, la pide una vez más por cada elemento guardado
- Después de cambiar un alias en la página **Hosts SSH** de los ajustes, los repositorios de ese host guardados en los marcadores ya no fallan al conectarse con el alias antiguo; sus ajustes y las credenciales guardadas en el llavero pasan también al alias nuevo
