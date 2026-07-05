# HourTracker — App de control de horas (iOS · SwiftUI)

Aplicación para cuantificar y gestionar horas de trabajo por **cliente/departamento** y **proyecto**, pensada para autónomos y freelancers. Datos 100% locales, gráficos con Apple Charts.

---

## Requisitos

- **Xcode 15+**
- **iOS 17+** (se usan SwiftData, Swift Charts `SectorMark` y `ContentUnavailableView`, todos disponibles a partir de iOS 17)

## Cómo abrirlo en Xcode

Los archivos están organizados pero **no incluyen el archivo `.xcodeproj`** (que es binario y se genera mejor desde Xcode). Para montarlo:

1. En Xcode: **File ▸ New ▸ Project… ▸ iOS ▸ App**.
2. Nombre del producto: `HourTracker`. Interface: **SwiftUI**. Storage: **SwiftData** (o None; ya se configura por código). Lenguaje: **Swift**.
3. Borra los archivos `ContentView.swift` y el `…App.swift` que crea la plantilla.
4. Arrastra a Xcode la carpeta `HourTracker/` de este proyecto (la que contiene `HourTrackerApp.swift` y las subcarpetas `Models`, `Utilities`, `Components`, `Views`). Marca **"Copy items if needed"** y **"Create groups"**.
5. Compila y ejecuta (⌘R).

> El idioma de la interfaz y los formatos de fecha/número están fijados a `es_ES` y la semana empieza en **lunes**.

---

## Arquitectura

Patrón **MV (Model + View) con SwiftData**, que es el enfoque recomendado por Apple para SwiftData: las vistas observan los datos directamente con `@Query`, y toda la lógica de cálculo se aísla en funciones puras (`HoursCalculator`) fáciles de testear.

```
HourTracker/
├─ HourTrackerApp.swift        → punto de entrada + ModelContainer (persistencia local)
├─ Models/                     → modelos SwiftData (@Model)
│   ├─ Client.swift            → Cliente / Departamento
│   ├─ Project.swift           → Proyecto (pertenece a un Client)
│   ├─ TimeEntry.swift         → Registro diario de horas
│   └─ AppSettings.swift       → Configuración global (horas semanales totales)
├─ Utilities/
│   ├─ Color+Hex.swift         → Color(hex:) + paleta de colores
│   ├─ Date+Helpers.swift      → calendario (lunes), periodos, formateadores
│   └─ HoursCalculator.swift   → LÓGICA DE CÁLCULO (totales, desgloses, progreso, evolución)
├─ Components/                 → componentes REUTILIZABLES
│   ├─ SummaryCard.swift       → tarjeta de resumen
│   ├─ HoursProgressBar.swift  → barra de progreso (avisa si se supera el presupuesto)
│   ├─ ProgressRing.swift      → anillo de progreso del dashboard
│   ├─ ColorSelector.swift     → selector de color desde paleta
│   ├─ CommonComponents.swift  → EmptyState, ColorDot, BreakdownRow
│   └─ ChartComponents.swift   → gráficos reutilizables (circular, barras, comparativa, evolución)
└─ Views/
    ├─ RootView.swift          → TabView principal
    ├─ Dashboard/              → resumen semanal (inicio)
    ├─ Week/                   → vista semanal navegable
    ├─ TimeEntry/              → registro + historial filtrable
    ├─ Clients/                → CRUD de clientes
    ├─ Projects/               → CRUD de proyectos
    ├─ Settings/               → hub de ajustes + configuración de horas
    └─ Charts/                 → gráficos y estadísticas
```

## Modelo de datos y relaciones

```
AppSettings (1)  ─ horas semanales totales

Client (1) ──< Project (N)        un cliente tiene varios proyectos
Client (1) ──< TimeEntry (N)      registros del cliente
Project (1) ──< TimeEntry (N)     registros del proyecto
```

- Al borrar un **Client** se eliminan en cascada sus proyectos y registros (`deleteRule: .cascade`).
- `TimeEntry.client` y `TimeEntry.project` son opcionales para que el historial sea robusto.
- Los colores se guardan como HEX (`colorHex`) elegidos de una paleta cerrada → estética consistente y sin conversiones frágiles.

## Flujo de navegación

`TabView` con 5 pestañas:

1. **Inicio** — anillo de progreso semanal + tarjetas (asignadas/trabajadas/restantes) + desglose por cliente + botón "Registrar horas".
2. **Semana** — navegación entre semanas (◀ ▶), progreso y desglose por cliente y proyecto.
3. **Registros** — historial agrupado por día, con filtros por cliente/proyecto; tocar para editar, deslizar para borrar.
4. **Gráficos** — selector de periodo (semana/mes/año) y dimensión (cliente/proyecto): circular, barras, asignadas vs. trabajadas y evolución.
5. **Ajustes** — clientes, proyectos y configuración de horas semanales.

El registro y los formularios se presentan como hojas modales (`.sheet`).

## Lógica de cálculo (`HoursCalculator`)

Funciones puras, sin dependencia de la UI:

- `total(_:)` — suma de horas de un conjunto de registros.
- `entries(_:in:)` — filtra registros por intervalo `[inicio, fin)` (semana/mes/año).
- `worked(_:in:containing:)` — horas trabajadas en el periodo de una fecha.
- `byClient(_:)` / `byProject(_:)` — desgloses para gráficos.
- `evolution(_:period:count:)` — serie temporal para el gráfico de líneas.
- `progress(assigned:worked:)` — calcula restantes, exceso (`overflow`), fracción 0–1 y bandera `isOver`.

Reglas implementadas:
- Las horas se suman por día, semana, mes y año.
- Filtrables por cliente y proyecto.
- Las horas trabajadas se comparan con las asignadas; **si se supera el presupuesto, la UI lo marca en rojo** (barra, anillo y tarjeta de exceso).
- Si faltan horas, se muestra cuántas quedan ("Faltan X h").

## Diseño visual

- Estilo nativo iOS limpio: fondos agrupados, tarjetas redondeadas (`RoundedRectangle` continuo), tipografía del sistema.
- Color identificativo por cliente/proyecto presente en listas, gráficos y barras.
- Componentes visuales claros: anillo de progreso, barras, tarjetas-resumen, estados vacíos con llamada a la acción.
- Soporte automático de **modo claro/oscuro** (uso de colores semánticos del sistema).

## Notas

- La app crea automáticamente el registro de `AppSettings` en el primer arranque (40 h por defecto).
- Para empezar: crea un cliente → un proyecto → registra horas → revisa Semana y Gráficos.
