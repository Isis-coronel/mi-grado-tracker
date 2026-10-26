# Mi grado

Aplicación nativa en SwiftUI para organizar el seguimiento del Grado Superior en Automatización y Robótica Industrial. Tiene destinos para Mac y iPhone.

## Probar en un Mac

1. Instala Xcode y macOS 14 o posterior.
2. Abre `GradoTracker.xcodeproj`.
3. En la barra superior, selecciona el esquema `MiGrado` y el destino `My Mac`.
4. Pulsa **Run** (▶).

No hace falta publicar la app ni instalarla desde el App Store para ejecutarla desde Xcode en un Mac.

## Probar en iPhone

El proyecto también admite iOS 17 o posterior. Conecta el iPhone al Mac, selecciónalo como destino en Xcode y configura la firma de la app en **Signing & Capabilities** con una cuenta Apple. Para ejecutar en un dispositivo físico, Xcode puede pedir que el iPhone esté desbloqueado y que autorices el Mac.

## Mi día: seguir el plan y ver tu progreso

**Mi día** usa el día de la semana del Mac o iPhone y muestra únicamente las dos asignaturas programadas para ese día:

| Día | Primera hora | Segunda hora |
| --- | --- | --- |
| Lunes | Sistemas eléctricos, neumáticos e hidráulicos | Itinerario Personal para la Empleabilidad I |
| Martes | Sistemas secuenciales programables | Ampliación de Itinerario Personal para la Empleabilidad |
| Miércoles | Sistemas de medida y regulación | Documentación técnica |
| Jueves | Sistemas de potencia | Informática industrial |

En cada asignatura aparece **la siguiente tarea obligatoria pendiente**, en el orden de la temporalización. Abre ese recurso en UNIVERSAE. Al terminar, pulsa **Marcar como hecha y mostrar la siguiente**: el checklist y el progreso se actualizan y la pantalla te propone la próxima tarea de esa asignatura. Cuando ya no queden tareas obligatorias, mostrará el material opcional que falte.

El viernes se reserva para pendientes y apuntes; **Mi día** enseña los dos pendientes más antiguos que queden hasta la semana actual. El sábado y el domingo aparecen como días libres.

Debajo del plan diario se mantiene un resumen del progreso total y de la racha. La barra de progreso compara dos cantidades:

- **Progreso real**: tareas que has marcado como completadas.
- **Marca vertical**: tareas que la temporalización del curso ya preveía terminar.

La referencia se calcula con las semanas de las temporalizaciones incluidas en el curso. Durante una semana activa, la meta incluye las tareas de las semanas anteriores; las tareas de la semana actual entran en la meta cuando esa semana termina. Así no se consideran atrasadas antes de acabar la semana. Las semanas de descanso mantienen la última meta alcanzada.

El estado compara tus tareas completadas con esa meta:

- **Por delante**: has completado más tareas de las previstas hasta ahora.
- **Al día**: has completado exactamente las tareas previstas.
- **Atrasada**: te faltan tareas para alcanzar la referencia. La etiqueta también indica cuántas.

Las barras muestran tu avance real con un color y la marca vertical señala la meta temporal. En la pantalla **Asignaturas**, toca el nombre de una asignatura para desplegar sus unidades y checklist. Toca una tarea para marcarla o desmarcarla; al hacerlo se actualizan la barra, el estado y el total del grado.

La **racha de estudio** cuenta los días consecutivos en los que marcas al menos una tarea. Si hoy todavía no has marcado ninguna, se conserva la racha de ayer; se interrumpe al pasar un día completo sin actividad. La app registra la actividad desde esta versión. Las marcas anteriores se conservan, pero la versión previa no guardaba fechas de actividad, así que no se inventa una racha pasada.

## Otras pantallas

- **Calendario**: consulta las 34 semanas del curso, su rango de fechas, el número de tareas y las autoevaluaciones.
- **Plan**: muestra la rotación semanal recomendada de asignaturas y permite exportar o importar una copia del progreso.
- El checklist conserva la asignatura, unidad, semana y duración estimada de cada tarea.

## Datos y copia de seguridad

El progreso y los días de actividad se guardan localmente en cada dispositivo. La app no los envía a ningún servidor y no sincroniza automáticamente Mac y iPhone. En **Plan → Copia de progreso**, exporta el archivo JSON en un dispositivo e impórtalo en el otro. El archivo incluye las tareas completadas y el historial de días de la racha. También se pueden importar copias antiguas que solo contienen las tareas completadas; en ellas no hay fechas con las que reconstruir una racha previa.

El repositorio incluye el código de la app y los datos de temporalización necesarios para calcular la referencia. No incluye el historial personal de tareas ni las copias de progreso.
