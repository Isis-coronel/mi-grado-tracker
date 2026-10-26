# Mi grado

Aplicación nativa SwiftUI para seguir el grado de Automatización y Robótica Industrial. Incluye destinos para Mac y iPhone.

## Probar en un Mac

1. Instala Xcode y macOS 14 o posterior.
2. Abre `GradoTracker.xcodeproj`.
3. En la barra superior, selecciona el esquema `MiGrado` y el destino `My Mac`.
4. Pulsa **Run** (▶).

No hace falta publicar la app ni instalarla desde el App Store para ejecutarla desde Xcode en un Mac.

## Probar en iPhone

El proyecto también admite iOS 17 o posterior. Para instalarlo en un iPhone, conecta el dispositivo al Mac, selecciónalo como destino en Xcode y configura la firma con una cuenta Apple en **Signing & Capabilities**.

## Incluye

- 34 semanas, 9 asignaturas y 761 tareas importadas del tracking original.
- Vistas de Mi día, Asignaturas, Calendario y Plan.
- Marcar tareas y consultar el progreso por asignatura y semana.
- Guardado local del progreso y copia de seguridad JSON mediante Importar/Exportar.
- Interfaz con paleta azul marino, turquesa, amarillo y fucsia.

## Datos y sincronización

El progreso se guarda localmente en cada dispositivo. No hay sincronización automática entre Mac y iPhone; se puede transferir mediante la copia JSON desde Plan.
