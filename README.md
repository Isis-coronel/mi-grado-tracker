# Mi grado

App para macOS e iOS con contenedor Swift y WebKit. Carga la interfaz y la lógica del tracker original para conservar su aspecto y comportamiento. El HTML, CSS y JavaScript se incluyen en la app; no necesita conexión a internet.

## Abrir en Xcode

1. Abre `GradoTracker.xcodeproj`.
2. Selecciona el esquema `MiGrado` y el destino **My Mac**.
3. Pulsa **Run**. Requiere macOS 14 o posterior.

Para iPhone, conecta el dispositivo, selecciónalo como destino y configura la firma en **Signing & Capabilities**. Requiere iOS 17 o posterior.

## Qué incluye

- **Mi día:** racha, congeladores, indicadores de urgencia, navegación semanal y las dos asignaturas del día en tarjetas separadas. Cada tarjeta muestra el progreso, la meta, la siguiente tarea y su checklist. Si la asignatura va al día, aparecen las seis tareas siguientes; si tiene retraso, aparecen las tareas vencidas.
- **Asignaturas:** nueve asignaturas desplegables por unidades, con avance y checklist compartido con Mi día. Las autoevaluaciones permiten registrar nota, intentos y dificultad.
- **Calendario:** 34 semanas, tareas, autoevaluaciones, pausas y semanas intensas.
- **Plan:** rotación semanal, explicación del semáforo y copia de progreso.
- **Directos:** registro de asignatura, fecha, temas y notas.
- **Historial:** caja negra de acciones con opción de copiar.

Las casillas, la racha, los intentos, apuntes, clases, congeladores e historial se guardan en el almacenamiento local de WebKit de cada dispositivo. No se sincronizan automáticamente entre Mac y iPhone. Usa **Plan → Exportar** en un dispositivo y **Plan → Importar** en el otro para transferir el progreso.

## Privacidad

El archivo original contenía un historial de progreso precargado. Se ha quitado del proyecto público; la app comienza sin datos personales y conserva las funciones de exportación e importación. El repositorio contiene el tracker y sus datos curriculares, pero no el progreso personal.
