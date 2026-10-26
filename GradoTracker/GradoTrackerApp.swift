import SwiftUI
import UniformTypeIdentifiers

enum AppStyle {
    static let canvas = Color(red: 0.93, green: 0.95, blue: 0.97)
    static let navy = Color(red: 0.07, green: 0.15, blue: 0.23)
    static let teal = Color(red: 0.00, green: 0.72, blue: 0.75)
    static let yellow = Color(red: 1.00, green: 0.82, blue: 0.00)
    static let pink = Color(red: 0.95, green: 0.10, blue: 0.62)
    static let slate = Color(red: 0.37, green: 0.46, blue: 0.56)
}

@main
struct GradoTrackerApp: App {
    @StateObject private var store = GradeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(AppStyle.teal)
        }
    }
}

struct CourseData: Decodable {
    let weeks: [CourseWeek]
    let subjects: [CourseSubject]
}

struct CourseWeek: Decodable, Identifiable {
    let n: Int
    let s: String
    let e: String
    let l: String
    var sp: String?
    var id: Int { n }
}

struct CourseSubject: Decodable, Identifiable {
    let code: String
    let name: String
    let abbr: String
    let weight: String
    let units: [CourseUnit]
    let tasks: [CourseTask]
    var id: String { code }
}

struct CourseUnit: Decodable, Identifiable {
    let number: Int
    let title: String
    let topics: [String]
    var id: Int { number }
}

struct CourseTask: Decodable, Identifiable {
    let id: String
    let week: Int
    let unit: Int
    let type: String
    let title: String
    let minutes: Int
    let optional: Bool
}

final class GradeStore: ObservableObject {
    @Published private(set) var course: CourseData
    @Published var completed: Set<String> = [] { didSet { save() } }

    private let storageKey = "universae-arbi-v3"

    init() {
        if let url = Bundle.main.url(forResource: "course", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(CourseData.self, from: data) {
            course = decoded
        } else {
            course = CourseData(weeks: [], subjects: [])
        }
        if let values = UserDefaults.standard.stringArray(forKey: storageKey) {
            completed = Set(values)
        }
    }

    var totalTasks: Int { course.subjects.reduce(0) { $0 + $1.tasks.count } }
    var completedCount: Int { completed.count }
    var progress: Double { totalTasks == 0 ? 0 : Double(completedCount) / Double(totalTasks) }

    func isComplete(_ task: CourseTask) -> Bool { completed.contains(task.id) }

    func toggle(_ task: CourseTask) {
        if completed.contains(task.id) { completed.remove(task.id) }
        else { completed.insert(task.id) }
    }

    func completedCount(for subject: CourseSubject) -> Int {
        subject.tasks.filter { completed.contains($0.id) }.count
    }

    func restoreProgress(from data: Data) throws {
        let ids = try JSONDecoder().decode([String].self, from: data)
        let validIDs = Set(course.subjects.flatMap(\.tasks).map(\.id))
        completed = Set(ids.filter { validIDs.contains($0) })
    }

    var backupDocument: ProgressBackup {
        ProgressBackup(data: (try? JSONEncoder().encode(Array(completed).sorted())) ?? Data("[]".utf8))
    }

    private func save() {
        UserDefaults.standard.set(Array(completed), forKey: storageKey)
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case today = "Mi día"
    case subjects = "Asignaturas"
    case calendar = "Calendario"
    case plan = "Plan"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .subjects: "books.vertical"
        case .calendar: "calendar"
        case .plan: "list.bullet.rectangle"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: GradeStore
    @State private var selection: AppSection? = .today
    @State private var macPath: [String] = []

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        selection = section
                        macPath.removeAll()
                    } label: {
                        Label(section.rawValue, systemImage: section.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(selection == section ? AppStyle.navy : AppStyle.slate)
                    .background(selection == section ? AppStyle.teal : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
            .navigationTitle("Mi grado")
        } detail: {
            NavigationStack(path: $macPath) {
                destination.navigationDestination(for: String.self) { code in
                    subjectDestination(for: code)
                }
            }
            .onChange(of: selection) { macPath = [] }
        }
        #else
        TabView(selection: Binding(get: { selection ?? .today }, set: { selection = $0 })) {
            ForEach(AppSection.allCases) { section in
                NavigationStack {
                    view(for: section).navigationDestination(for: String.self) { code in
                        subjectDestination(for: code)
                    }
                }
                    .tabItem { Label(section.rawValue, systemImage: section.symbol) }
                    .tag(section)
            }
        }
        #endif
    }

    @ViewBuilder private var destination: some View {
        view(for: selection ?? .today)
    }

    @ViewBuilder private func view(for section: AppSection) -> some View {
        switch section {
        case .today: TodayView()
        case .subjects: SubjectsView()
        case .calendar: CalendarView()
        case .plan: PlanView()
        }
    }

    @ViewBuilder private func subjectDestination(for code: String) -> some View {
        if let subject = store.course.subjects.first(where: { $0.code == code }) {
            SubjectDetailView(subject: subject)
        } else {
            ContentUnavailableView("Asignatura no encontrada", systemImage: "books.vertical")
        }
    }
}

struct TodayView: View {
    @EnvironmentObject private var store: GradeStore
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("UNIVERSAE · AUTOMATIZACIÓN Y ROBÓTICA", systemImage: "square.fill")
                            .font(.caption.bold()).tracking(0.5).foregroundStyle(AppStyle.navy)
                        Text("Tu grado, a tu ritmo")
                            .font(.largeTitle.bold()).foregroundStyle(AppStyle.navy)
                        Text("Curso 2026–2027 · sigue avanzando cada día")
                            .foregroundStyle(AppStyle.slate)
                    }
                    Spacer(minLength: 8)
                    Text("\(store.completedCount) de \(store.totalTasks)")
                        .font(.headline.bold()).monospacedDigit()
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(AppStyle.yellow, in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(AppStyle.navy)
                }

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("PROGRESO DEL GRADO", systemImage: "chart.bar.fill")
                            .font(.caption.bold()).foregroundStyle(.white.opacity(0.72))
                        Text(store.progress.formatted(.percent.precision(.fractionLength(0))))
                            .font(.system(size: 38, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        ProgressView(value: store.progress).tint(AppStyle.teal)
                        Text("\(store.completedCount) tareas completadas · \(max(0, store.totalTasks - store.completedCount)) por hacer")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.78))
                    }
                    Spacer(minLength: 16)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 34, weight: .bold)).foregroundStyle(AppStyle.yellow)
                        .padding(16).background(.white.opacity(0.08), in: Circle())
                }
                .padding(20)
                .background(AppStyle.navy, in: RoundedRectangle(cornerRadius: 5))
                .overlay(alignment: .bottomTrailing) {
                    Rectangle().fill(AppStyle.pink).frame(width: 9, height: 9).offset(x: 4, y: 4)
                }

                HStack(spacing: 12) {
                    MetricCard(title: "Tareas hechas", value: "\(store.completedCount)", symbol: "checkmark.circle.fill", color: AppStyle.teal)
                    MetricCard(title: "Asignaturas", value: "\(store.course.subjects.count)", symbol: "books.vertical.fill", color: AppStyle.yellow)
                    MetricCard(title: "Semanas", value: "\(store.course.weeks.count)", symbol: "calendar", color: AppStyle.pink)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Tus asignaturas").font(.title2.bold()).foregroundStyle(AppStyle.navy)
                        Spacer()
                        Text("\(store.course.subjects.count) materias").font(.caption.bold()).foregroundStyle(AppStyle.slate)
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.course.subjects) { subject in
                            NavigationLink(value: subject.id) {
                                SubjectCard(subject: subject, done: store.completedCount(for: subject))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppStyle.canvas)
        .navigationTitle("Mi día")
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    var color: Color = AppStyle.teal
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol).font(.caption.bold()).foregroundStyle(AppStyle.slate)
            Text(value).font(.title.bold()).monospacedDigit().foregroundStyle(AppStyle.navy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 4))
        .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 5) }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppStyle.navy, lineWidth: 1.5))
    }
}

struct SubjectCard: View {
    let subject: CourseSubject
    let done: Int
    private var fraction: Double { subject.tasks.isEmpty ? 0 : Double(done) / Double(subject.tasks.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(subject.abbr.uppercased())
                .font(.caption.bold()).tracking(0.4).foregroundStyle(AppStyle.slate)
            Text(subject.name).font(.headline.bold()).foregroundStyle(AppStyle.navy).multilineTextAlignment(.leading).lineLimit(3)
            ProgressView(value: fraction).tint(AppStyle.pink)
            Text("\(done) de \(subject.tasks.count) tareas")
                .font(.caption).foregroundStyle(AppStyle.slate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppStyle.navy, lineWidth: 1.5))
        .contentShape(Rectangle())
    }
}

struct SubjectsView: View {
    @EnvironmentObject private var store: GradeStore
    var body: some View {
        List(store.course.subjects) { subject in
            NavigationLink(value: subject.id) {
                SubjectCard(subject: subject, done: store.completedCount(for: subject))
                    .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppStyle.canvas)
        .navigationTitle("Asignaturas")
    }
}

struct SubjectDetailView: View {
    @EnvironmentObject private var store: GradeStore
    let subject: CourseSubject

    var body: some View {
        List {
            Section {
                ProgressView(value: subject.tasks.isEmpty ? 0 : Double(store.completedCount(for: subject)) / Double(subject.tasks.count))
                Text("\(store.completedCount(for: subject)) de \(subject.tasks.count) tareas completadas")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(subject.units) { unit in
                Section("Unidad \(unit.number) · \(unit.title)") {
                    ForEach(subject.tasks.filter { $0.unit == unit.number }) { task in
                        TaskRow(task: task)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppStyle.canvas)
        .navigationTitle(subject.abbr)
    }
}

struct TaskRow: View {
    @EnvironmentObject private var store: GradeStore
    let task: CourseTask

    var body: some View {
        Button { store.toggle(task) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: store.isComplete(task) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(store.isComplete(task) ? AppStyle.teal : AppStyle.slate)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .foregroundStyle(store.isComplete(task) ? .secondary : .primary)
                        .strikethrough(store.isComplete(task))
                    Text("\(task.typeName) · Semana \(task.week) · \(task.minutes) min\(task.optional ? " · opcional" : "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension CourseTask {
    var typeName: String {
        ["T":"Temario", "VC":"Vídeo clase", "VE":"Vídeo explicativo", "CI":"Clase interactiva",
         "IN":"Infografía", "E360":"Entorno 360", "AR":"Realidad aumentada", "SIM":"Simulador",
         "LAB":"Laboratorio", "S":"Síntesis", "A":"Autoevaluación", "EJ":"Ejercicios",
         "D":"Destrezas", "VOC":"Vocabulario"][type] ?? type
    }
}

struct CalendarView: View {
    @EnvironmentObject private var store: GradeStore
    var body: some View {
        List(store.course.weeks) { week in
            let tasks = store.course.subjects.flatMap(\.tasks).filter { $0.week == week.n }
            let done = tasks.filter(store.isComplete).count
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Semana \(week.n)").font(.headline.bold()).foregroundStyle(AppStyle.navy)
                    Spacer()
                    Text(week.l).foregroundStyle(AppStyle.slate)
                }
                if let special = week.sp {
                    Text(special).font(.subheadline.bold()).foregroundStyle(AppStyle.pink)
                }
                ProgressView(value: tasks.isEmpty ? 0 : Double(done) / Double(tasks.count)).tint(AppStyle.teal)
                Text("\(done) de \(tasks.count) tareas · \(tasks.filter { $0.type == "A" }.count) autoevaluaciones")
                    .font(.caption).foregroundStyle(AppStyle.slate)
            }
            .padding(.vertical, 5)
        }
        .scrollContentBackground(.hidden)
        .background(AppStyle.canvas)
        .navigationTitle("Calendario del curso")
    }
}

struct PlanView: View {
    @EnvironmentObject private var store: GradeStore
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var importMessage: String?

    var body: some View {
        List {
            Section("Rotación semanal") {
                planRow("Lunes", "Sistemas eléctricos, neumáticos e hidráulicos", "Itinerario Personal para la Empleabilidad I")
                planRow("Martes", "Sistemas secuenciales programables", "Ampliación de IPE")
                planRow("Miércoles", "Sistemas de medida y regulación", "Documentación técnica")
                planRow("Jueves", "Sistemas de potencia", "Informática industrial")
                LabeledContent("Viernes", value: "Pendientes y apuntes")
            }
            Section("Ritmo recomendado") {
                Label("2 horas al día", systemImage: "clock")
                Label("Dos asignaturas: una fuerte y una ligera", systemImage: "books.vertical")
                Label("Inglés se trabaja aparte", systemImage: "character.book.closed")
            }
            Section("Sobre los datos") {
                Text("El progreso se guarda en este dispositivo. Para llevarlo de Mac a iPhone añadiremos sincronización con iCloud o una copia de seguridad compartida.")
                    .foregroundStyle(.secondary)
            }
            Section("Copia de progreso") {
                Button { showingExporter = true } label: {
                    Label("Exportar progreso", systemImage: "square.and.arrow.up")
                }
                Button { showingImporter = true } label: {
                    Label("Importar progreso", systemImage: "square.and.arrow.down")
                }
                Text("También puedes pegar aquí el archivo JSON exportado desde tu tracking actual; las tareas mantienen sus identificadores originales.")
                    .font(.caption).foregroundStyle(.secondary)
                if let importMessage { Text(importMessage).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppStyle.canvas)
        .navigationTitle("Tu plan")
        .fileExporter(isPresented: $showingExporter, document: store.backupDocument, contentType: .json, defaultFilename: "mi-grado-progreso") { result in
            if case .failure(let error) = result { importMessage = "No se pudo exportar: \(error.localizedDescription)" }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                try store.restoreProgress(from: Data(contentsOf: url))
                importMessage = "Progreso importado correctamente."
            } catch {
                importMessage = "No se pudo importar ese archivo JSON."
            }
        }
    }

    private func planRow(_ day: String, _ first: String, _ second: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(day).font(.headline)
            Text("1.ª hora · \(first)")
            Text("2.ª hora · \(second)").foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

struct ProgressBackup: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data("[]".utf8)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
