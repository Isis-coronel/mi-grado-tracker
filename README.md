# Mi grado

Aplicación nativa en SwiftUI para macOS e iOS que ayuda a seguir el Grado Superior en Automatización y Robótica Industrial. La temporalización del curso se incluye como datos de referencia; el progreso personal se guarda en el dispositivo.

## Ejecutarla en Xcode

1. Instala Xcode y abre `GradoTracker.xcodeproj`.
2. Selecciona el esquema `MiGrado` y el destino **My Mac**.
3. Pulsa **Run** (▶). Se requiere macOS 14 o posterior.

Para probarla en iPhone, conecta y selecciona el dispositivo en Xcode, y configura la firma en **Signing & Capabilities**. Se requiere iOS 17 o posterior.

## Mi día: qué abrir a continuación

La tira semanal deja elegir un día y cambiar de semana. **Volver a hoy** restaura la fecha actual. El plan habitual tiene dos asignaturas de lunes a jueves:

| Día | Primera hora | Segunda hora |
| --- | --- | --- |
| Lunes | Sistemas eléctricos, neumáticos e hidráulicos | Itinerario Personal para la Empleabilidad I |
| Martes | Sistemas secuenciales programables | Ampliación de Itinerario Personal para la Empleabilidad |
| Miércoles | Sistemas de medida y regulación | Documentación técnica |
| Jueves | Sistemas de potencia | Informática industrial |

Cada tarjeta propone la siguiente tarea pendiente de la asignatura, en el orden de la temporalización. Abre ese recurso en UNIVERSAE y marca la tarea al terminar; la app muestra la siguiente. El viernes se reserva para pendientes y apuntes. Sábado y domingo son libres, salvo que el plan se haya desplazado al congelar días. El 15 de septiembre está reservado a Inglés y la rotación empieza el 16.

Las tarjetas superiores resumen los días hasta los exámenes presenciales (19 de mayo de 2027), la próxima autoevaluación pendiente y las tareas completadas frente a la meta. La meta se distribuye según la parte transcurrida de la semana activa. En las asignaturas, la barra compara el progreso real con esa meta. El estado puede ser **Por delante**, **Al día**, **N por hacer** (menos de una semana de trabajo de esa asignatura) o **N atrasadas** (una semana o más). Las asignaturas con más retraso aparecen primero.

La racha cuenta únicamente los días en que marcas tareas completadas. Los fines de semana y los huecos entre semanas lectivas se omiten; se toleran hasta dos días lectivos seguidos sin completar tareas. Al tercero se rompe la racha. Las acciones de apuntes, clases y autoevaluaciones no cuentan como día de estudio por sí solas. Se permiten dos congeladores por semana lectiva: congelar un día protege la racha y desplaza las clases restantes un día, incluso hasta el sábado.

## Asignaturas y autoevaluaciones

Abre una asignatura para ver sus unidades, el avance de cada una y las tareas asociadas. El checklist es compartido con **Mi día**. Las filas muestran tipo de recurso, unidad, duración, semana y fecha límite; una tarea pendiente vencida aparece en rojo.

Al marcar una autoevaluación, puedes guardar el número de intento, la nota y la dificultad, o saltar el registro del intento. Debajo de cada autoevaluación están sus intentos anteriores; puedes añadir o quitar el último y ajustar su dificultad. Las marcas de dificultad difícil se resumen en la tarjeta de la asignatura. Una unidad queda lista para apuntes del viernes cuando todas sus tareas están completadas y tiene al menos un intento registrado de autoevaluación.

## Calendario

Muestra las 34 semanas, sus fechas, tareas y autoevaluaciones, y el avance completado. La semana actual está resaltada; las semanas con cuatro o más autoevaluaciones llevan un aviso. Los huecos entre rangos lectivos se consideran pausas para el cálculo de la racha.

## Plan

Incluye la rotación semanal, el significado de los estados, cifras orientativas del curso (203 horas de material, 10 horas semanales y aproximadamente 320 horas hasta el examen) y opciones para exportar, importar o reiniciar el progreso. El cálculo de 115 horas de margen es una estimación fija; estas cifras no se recalculan al cambiar el ritmo.

## Clases en directo e historial

En **Directos**, registra asignatura, fecha, temas y notas opcionales. Las clases aparecen agrupadas por asignatura, de más reciente a más antigua, y se pueden borrar.

**Historial** es la caja negra de solo lectura: guarda acciones con fecha y hora (marcas y desmarcas, autoevaluaciones, apuntes, clases y congeladores) y permite copiar el registro completo.

## Datos, privacidad y copias

Los datos personales del tracker se guardan localmente en cada dispositivo y no se envían a un servidor. Mac e iPhone no se sincronizan automáticamente. En **Plan → Copia de progreso**, exporta un JSON en un dispositivo y luego impórtalo en el otro. La copia incluye tareas, intentos, apuntes, clases, historial, días de racha y congeladores. **Reiniciar progreso** borra esos datos locales.

El repositorio contiene el código y los datos de temporalización necesarios para usar la app. No contiene el historial personal ni las copias de progreso.
