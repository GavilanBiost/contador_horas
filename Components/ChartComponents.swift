import SwiftUI
import Charts

// MARK: - Gráfico circular (donut)

/// Gráfico circular reutilizable a partir de un desglose de horas.
struct HoursPieChart: View {
    let data: [HoursBreakdown]

    var body: some View {
        if data.isEmpty {
            placeholder
        } else {
            Chart(data) { item in
                SectorMark(
                    angle: .value("Horas", item.hours),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(by: .value("Categoría", item.name))
            }
            .chartForegroundStyleScale(domain: data.map(\.name), range: data.map { Color(hex: $0.colorHex) })
            .chartLegend(position: .bottom, alignment: .center, spacing: 12)
            .frame(height: 260)
        }
    }

    private var placeholder: some View {
        Text("Sin datos en este periodo")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(height: 260)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Gráfico de barras

/// Gráfico de barras horizontales reutilizable.
struct HoursBarChart: View {
    let data: [HoursBreakdown]

    var body: some View {
        if data.isEmpty {
            Text("Sin datos en este periodo")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
        } else {
            Chart(data) { item in
                BarMark(
                    x: .value("Horas", item.hours),
                    y: .value("Categoría", item.name)
                )
                .cornerRadius(6)
                .foregroundStyle(Color(hex: item.colorHex))
                .annotation(position: .trailing) {
                    Text(Formatters.hours(item.hours))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis { AxisMarks(position: .bottom) }
            .frame(height: max(CGFloat(data.count) * 44, 120))
        }
    }
}

// MARK: - Gráfico comparativo (asignadas vs trabajadas)

/// Compara horas asignadas con horas trabajadas en barras agrupadas.
struct AssignedVsWorkedChart: View {
    let assigned: Double
    let worked: Double

    private var rows: [(label: String, value: Double, color: Color)] {
        [("Asignadas", assigned, .gray), ("Trabajadas", worked, worked > assigned ? .red : .accentColor)]
    }

    var body: some View {
        Chart(rows, id: \.label) { row in
            BarMark(
                x: .value("Tipo", row.label),
                y: .value("Horas", row.value)
            )
            .cornerRadius(8)
            .foregroundStyle(row.color)
            .annotation(position: .top) {
                Text(Formatters.hours(row.value))
                    .font(.caption.weight(.semibold))
            }
        }
        .frame(height: 200)
    }
}

// MARK: - Gráfico de evolución (línea)

/// Evolución de horas trabajadas a lo largo del tiempo.
struct EvolutionChart: View {
    let points: [EvolutionPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Periodo", point.label),
                y: .value("Horas", point.hours)
            )
            .interpolationMethod(.catmullRom)
            .symbol(.circle)

            AreaMark(
                x: .value("Periodo", point.label),
                y: .value("Horas", point.hours)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(LinearGradient(
                colors: [Color.accentColor.opacity(0.3), .clear],
                startPoint: .top, endPoint: .bottom
            ))
        }
        .frame(height: 220)
    }
}

// MARK: - Contenedor de gráfico con título

/// Tarjeta que envuelve cualquier gráfico con un título consistente.
struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
