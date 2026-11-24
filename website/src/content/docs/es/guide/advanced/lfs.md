---
title: "Git LFS"
description: "Activa Git LFS, sigue archivos y patrones, y haz fetch, pull y push de contenido LFS."
---

Git LFS mantiene los archivos grandes fuera del historial del repositorio. El repositorio guarda un pequeño archivo puntero por cada uno. El contenido va a un almacén LFS en el remoto.

Spooky ejecuta Git LFS en la máquina donde está el repositorio.

## Qué necesitas {#requirements}

Git LFS 2.9.0 o posterior, en el `PATH` que usa Git en la máquina donde está el repositorio.

Para comprobarlo, haz clic en :ui[repositorySettings.title] bajo :ui[workspace.group] en la barra lateral. La sección :ui[repositorySettings.lfs] muestra la :ui[lfs.version] de Git LFS. Consulta [Git LFS, archivos ignorados y excluidos](/guide/settings/identity/#repository-files).

Si no se encuentra Git LFS o es demasiado antiguo, una nota explica ahí cómo solucionarlo:

- **En tu Mac**: instala o actualiza Git LFS. Si está instalado pero no se encuentra, abre :ui[app.name > settings.title] › :ui[settings.environment]. Marca :ui[settings.environment.loginShell], o añade `PATH` como variable personalizada. Consulta [Variables en este Mac](/guide/settings/general/#local-variables).
- **En un servidor**: instala o actualiza Git LFS allí. Añade su carpeta al `PATH` de las sesiones SSH no interactivas, por ejemplo en `~/.zshenv`.

Mientras falte Git LFS, los botones de esa sección que lo necesitan no están disponibles.

En un repositorio que usa Git LFS, otras operaciones, como cambiar de rama o añadir al stage, pueden fallar por el mismo motivo. Spooky muestra entonces :ui[hostError.lfsUnavailable] con las mismas indicaciones.

## Activar Git LFS {#enable}

En la sección :ui[repositorySettings.lfs] de los ajustes del repositorio, haz clic en :ui[lfs.enable]. Esto configura Git LFS solo para este repositorio. No cambia tu configuración global de Git. Consulta [Git LFS, archivos ignorados y excluidos](/guide/settings/identity/#repository-files).

Spooky considera que un repositorio usa Git LFS cuando Git tiene configurados los filtros de Git LFS y el repositorio tiene los hooks de Git LFS. Hasta entonces, la sección solo ofrece :ui[lfs.enable]. Las opciones del menú LFS tampoco están disponibles.

Cuando clones un repositorio que usa Git LFS, marca :ui[clone.lfs]. Consulta [Clonar un repositorio](/guide/repositories/manager/#clone).

Después de actualizar Git LFS, selecciona :ui[menu.repository > lfs.menu > lfs.menu.update] en la barra de menús para actualizar los hooks de Git LFS del repositorio.

## Seguir archivos {#track}

Los archivos que coinciden con un patrón de seguimiento se guardan con Git LFS. Los patrones van a `.gitattributes`, en la raíz del repositorio. Todos los que usan el repositorio los reciben. El cambio en `.gitattributes` aparece en la copia de trabajo. Haz commit de él como de los demás cambios.

Para añadir un patrón, haz clic en :ui[lfs.createPattern] en los ajustes del repositorio, o selecciona :ui[menu.repository > lfs.menu > lfs.menu.track] en la barra de menús. Escribe un patrón como `*.psd` y haz clic en :ui[files.pattern.save].

::screenshot[La sección Git LFS de los ajustes de un repositorio. Muestra la versión de Git LFS instalada y dos patrones de seguimiento, *.psd y *.mp4. La fila de *.psd muestra el botón de quitar que aparece cuando el puntero está sobre un patrón.]{name="advanced-lfs-settings" frame="window" markers="34.5,24 90,35.6 49.8,34.4"}

1. La versión de Git LFS instalada
2. El botón que quita un patrón
3. :ui[lfs.createPattern]

También puedes hacer clic derecho en archivos de la copia de trabajo y elegir en :ui[lfs.menu]:

- :ui[lfs.trackFile]: sigue solo los archivos seleccionados, con sus rutas exactas. Con varios archivos, indica cuántos son.
- :ui[lfs.trackType.single]{1="psd"}: sigue todos los archivos con la misma extensión. Con varios archivos, es :ui[lfs.trackType]. Abarca cada una de sus extensiones.
- :ui[lfs.createPattern.menu]: escribe tú un patrón, partiendo de la ruta del primer archivo seleccionado.

Para una carpeta, solo está disponible :ui[lfs.createPattern.menu].

### Dejar de seguir un patrón {#untrack}

En los ajustes del repositorio, haz clic en :ui[lfs.remove] junto a un patrón y confirma. El patrón sale de `.gitattributes`. Los archivos que ya están guardados con Git LFS se quedan como están.

Si Git LFS no puede quitar un patrón, Spooky dice cuáles quedan. Quítalos a mano con :ui[repositorySettings.openInEditor] junto a :ui[repositorySettings.lfs.patterns]. Consulta [Git LFS, archivos ignorados y excluidos](/guide/settings/identity/#repository-files).

## Hacer fetch, pull y push de contenido LFS {#transfer}

Con Git LFS configurado, Git normalmente descarga el contenido LFS al hacer checkout de los archivos. Sube el contenido cuando haces push. Para hacerlo tú, elige en :ui[menu.repository > lfs.menu] en la barra de menús:

| Opción | Qué hace |
|---|---|
| :ui[lfs.menu.fetch] | Descarga el contenido LFS que necesita el checkout actual. La copia de trabajo no cambia. |
| :ui[lfs.menu.pull] | Lo descarga y sustituye los archivos puntero de la copia de trabajo por el contenido. |
| :ui[lfs.menu.push] | Sube el contenido LFS usado por todas las ramas y etiquetas locales que el remoto aún no tiene. |

Elige un remoto en el diálogo. Empieza con el remoto del upstream de la rama actual, o con el primer remoto si no hay upstream. El progreso aparece en el [área de actividad](/guide/advanced/queue-activity/#activity-area), en la parte inferior de la barra lateral.

## Deshacer {#undo}

Puedes deshacer la activación de Git LFS, la adición de un patrón de seguimiento y su eliminación. Consulta [Deshacer y recuperar](/guide/work/undo/).

La actualización de los hooks no se puede deshacer. Las operaciones anteriores a ella tampoco se pueden deshacer ya.

Hacer fetch, pull y push de contenido LFS no se registra, igual que hacer fetch, pull y push en el repositorio. Las operaciones anteriores a ellos se pueden seguir deshaciendo.

:::note[Repositorios de servidor]
Git LFS se ejecuta en el servidor. El contenido LFS viaja entre el servidor y el remoto. Tu Mac no necesita Git LFS para un repositorio de servidor.
:::

## Consulta también

- [Requisitos del sistema](/reference/requirements/#optional)
- [Submódulos](/guide/advanced/submodules/)
- [La ventana Repositorios](/guide/repositories/manager/)
