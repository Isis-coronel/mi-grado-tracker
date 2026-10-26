import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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

enum StudyDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy = "Cómodo", medium = "Regular", hard = "Difícil"
    var id: String { rawValue }
    var symbol: String { self == .easy ? "🟢" : self == .medium ? "💛" : "🏮" }
}

struct AssessmentAttempt: Codable, Identifiable {
    var id = UUID().uuidString
    var taskID: String
    var date: Date
    var grade: String
    var difficulty: StudyDifficulty
}

struct LiveClassRecord: Codable, Identifiable {
    var id = UUID().uuidString
    var subjectCode: String
    var date: Date
    var topics: String
    var notes: String
}

struct TrackerEvent: Codable, Identifiable {
    var id = UUID().uuidString
    var date: Date
    var message: String
}

struct TrackerExtras: Codable {
    var attempts: [AssessmentAttempt] = []
    var notes: [String: String] = [:]
    var liveClasses: [LiveClassRecord] = []
    var events: [TrackerEvent] = []
    var frozenDays: Set<String> = []
}

final class GradeStore: ObservableObject {
    @Published private(set) var course: CourseData
    @Published var completed: Set<String> = [] { didSet { save() } }
    @Published private(set) var studyDays: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(studyDays), forKey: studyDaysKey) }
    }
    @Published private(set) var attempts: [AssessmentAttempt] = [] { didSet { saveExtras() } }
    @Published private(set) var unitNotes: [String: String] = [:] { didSet { saveExtras() } }
    @Published private(set) var liveClasses: [LiveClassRecord] = [] { didSet { saveExtras() } }
    @Published private(set) var events: [TrackerEvent] = [] { didSet { saveExtras() } }
    @Published private(set) var frozenDays: Set<String> = [] { didSet { saveExtras() } }

    private let storageKey = "universae-arbi-v3"
    private let studyDaysKey = "universae-arbi-study-days-v1"
    private let extrasKey = "universae-arbi-swift-extras-v1"

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
        studyDays = Set(UserDefaults.standard.stringArray(forKey: studyDaysKey) ?? [])
        if let data = UserDefaults.standard.data(forKey: extrasKey),
           let extras = try? JSONDecoder().decode(TrackerExtras.self, from: data) {
            attempts = extras.attempts
            unitNotes = extras.notes
            liveClasses = extras.liveClasses
            events = extras.events
            frozenDays = extras.frozenDays
        }
    }

    var totalTasks: Int { course.subjects.reduce(0) { $0 + $1.tasks.count } }
    var completedCount: Int { completed.count }
    var progress: Double { totalTasks == 0 ? 0 : Double(completedCount) / Double(totalTasks) }
    var currentCourseWeek: Int {
        let today = Calendar.current.startOfDay(for: Date())
        if let activeWeek = course.weeks.first(where: { week in
            guard let start = date(from: week.s), let end = date(from: week.e) else { return false }
            return today >= start && today <= end
        }) {
            return activeWeek.n
        }
        return course.weeks.last(where: { week in
            guard let end = date(from: week.e) else { return false }
            return end < today
        })?.n ?? 1
    }
    func courseWeek(containing selectedDate: Date) -> CourseWeek? {
        let day = Calendar.current.startOfDay(for: selectedDate)
        if let match = course.weeks.first(where: { week in
            guard let start = date(from: week.s), let end = date(from: week.e) else { return false }
            return day >= start && day <= end
        }) { return match }
        return course.weeks.last(where: { week in
            guard let end = date(from: week.e) else { return false }
            return end < day
        })
    }
    var referenceWeek: Int {
        let today = Calendar.current.startOfDay(for: Date())
        if let activeWeek = course.weeks.first(where: { week in
            guard let start = date(from: week.s), let end = date(from: week.e) else { return false }
            return today >= start && today <= end
        }) {
            return max(0, activeWeek.n - 1)
        }
        return course.weeks.last(where: { week in
            guard let end = date(from: week.e) else { return false }
            return end < today
        })?.n ?? 0
    }
    var expectedTaskCount: Int { expectedTaskCount(for: nil) }
    var currentStreak: Int { streakLength(from: Date()) }
    var didStudyToday: Bool { studyDays.contains(dateKey(for: Date())) }
    var missedLectiveDays: Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date())
        if didStudyToday { return 0 }
        if isLective(day), let previous = calendar.date(byAdding: .day, value: -1, to: day) { day = previous }
        var missed = 0
        while missed <= 2 {
            if isFrozen(day) { }
            else if isLective(day) {
                if studyDays.contains(dateKey(for: day)) { break }
                missed += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return missed
    }
    var remainingStreakGrace: Int { max(0, 2 - missedLectiveDays) }
    var bestStreak: Int {
        let dates = studyDays.compactMap { date(from: $0) }.filter(isLective).sorted()
        guard !dates.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for index in 1..<dates.count {
            let missed = missedLectives(from: dates[index - 1], to: dates[index])
            if missed <= 2 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    private func missedLectives(from earlier: Date, to later: Date) -> Int {
        var count = 0
        var day = Calendar.current.date(byAdding: .day, value: 1, to: earlier) ?? later
        while day < later {
            if isLective(day) && !isFrozen(day) && !studyDays.contains(dateKey(for: day)) { count += 1 }
            day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? later
        }
        return count
    }

    func expectedTaskCount(for subject: CourseSubject?) -> Int {
        let tasks = subject?.tasks ?? course.subjects.flatMap(\.tasks)
        let active = course.weeks.first(where: { $0.n == currentCourseWeek })
        let fraction: Double
        if let active, let start = date(from: active.s), let end = date(from: active.e) {
            let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
            let elapsed = min(Double(days + 1), max(0, Double(Calendar.current.dateComponents([.day], from: start, to: Calendar.current.startOfDay(for: Date())).day ?? 0)))
            fraction = min(1, elapsed / Double(days + 1))
        } else { fraction = 1 }
        return tasks.filter { $0.week < currentCourseWeek }.count + Int((Double(tasks.filter { $0.week == currentCourseWeek }.count) * fraction).rounded(.down))
    }

    func standing(done: Int, expected: Int, subject: CourseSubject? = nil) -> ProgressStanding {
        if done > expected { return .ahead(done - expected) }
        if done < expected {
            let gap = expected - done
            let weeklyLoad = max(1, (subject?.tasks.count ?? totalTasks) / max(course.weeks.count, 1))
            return gap < weeklyLoad ? .catchingUp(gap) : .behind(gap)
        }
        return .onTrack
    }

    func isComplete(_ task: CourseTask) -> Bool { completed.contains(task.id) }

    func toggle(_ task: CourseTask) {
        if completed.contains(task.id) { completed.remove(task.id); record("Desmarcada: \(task.title)") }
        else {
            completed.insert(task.id)
            studyDays.insert(dateKey(for: Date()))
            record("Completada: \(task.title)")
        }
    }

    func complete(_ task: CourseTask, grade: String? = nil, difficulty: StudyDifficulty? = nil) {
        if !completed.contains(task.id) {
            completed.insert(task.id)
            studyDays.insert(dateKey(for: Date()))
            record("Completada: \(task.title)")
        }
        if let difficulty {
            let attempt = AssessmentAttempt(taskID: task.id, date: Date(), grade: grade ?? "", difficulty: difficulty)
            attempts.append(attempt)
            record("Autoevaluación: \(task.title) · intento \(attempts.filter { $0.taskID == task.id }.count) · nota \(attempt.grade.isEmpty ? "—" : attempt.grade) · \(difficulty.symbol)")
        }
    }

    func attempts(for task: CourseTask) -> [AssessmentAttempt] { attempts.filter { $0.taskID == task.id }.sorted { $0.date < $1.date } }
    func noteKey(subject: CourseSubject, unit: CourseUnit) -> String { "\(subject.code)-U\(unit.number)" }
    func saveNote(_ text: String, subject: CourseSubject, unit: CourseUnit) {
        let key = noteKey(subject: subject, unit: unit)
        unitNotes[key] = text
        record("Apuntes actualizados: \(subject.abbr), unidad \(unit.number)")
    }
    func addLiveClass(_ item: LiveClassRecord) {
        liveClasses.append(item)
        let subject = course.subjects.first(where: { $0.code == item.subjectCode })?.abbr ?? item.subjectCode
        record("Clase en directo: \(subject) · \(item.topics)")
    }
    func deleteLiveClass(_ item: LiveClassRecord) {
        liveClasses.removeAll { $0.id == item.id }
        record("Clase en directo borrada")
    }
    func addAttempt(_ task: CourseTask, grade: String, difficulty: StudyDifficulty) {
        attempts.append(AssessmentAttempt(taskID: task.id, date: Date(), grade: grade, difficulty: difficulty))
        record("Autoevaluación: \(task.title) · intento \(attempts(for: task).count) · nota \(grade.isEmpty ? "—" : grade) · \(difficulty.symbol)")
    }
    func removeLastAttempt(_ task: CourseTask) {
        guard let last = attempts(for: task).last else { return }
        attempts.removeAll { $0.id == last.id }
        record("Eliminado último intento: \(task.title)")
    }
    func setDifficulty(_ difficulty: StudyDifficulty, task: CourseTask) {
        if let last = attempts(for: task).last, let index = attempts.firstIndex(where: { $0.id == last.id }) {
            attempts[index].difficulty = difficulty
        } else { attempts.append(AssessmentAttempt(taskID: task.id, date: Date(), grade: "", difficulty: difficulty)) }
        record("Dificultad de autoevaluación: \(task.title) · \(difficulty.symbol)")
    }
    func record(_ message: String) { events.insert(TrackerEvent(date: Date(), message: message), at: 0) }
    func freezeToday() {
        let key = dateKey(for: Date())
        frozenDays.insert(key)
        record("Día congelado; el plan restante se desplaza un día")
    }
    func isFrozen(_ date: Date) -> Bool { frozenDays.contains(dateKey(for: date)) }
    var freezesThisWeek: Int {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return frozenDays.compactMap(date(from:)).filter { interval.contains($0) }.count
    }
    func isLective(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        guard weekday != 1 && weekday != 7 else { return false }
        let day = Calendar.current.startOfDay(for: date)
        let key = dateKey(for: day)
        if key == "2026-10-12" || key == "2026-12-07" || (key >= "2026-12-23" && key <= "2027-01-06") || (key >= "2027-03-19" && key <= "2027-04-04") { return false }
        let spans = course.weeks.compactMap { week -> (Date, Date)? in
            guard let start = self.date(from: week.s), let end = self.date(from: week.e) else { return nil }
            return (start, end)
        }.sorted { $0.0 < $1.0 }
        guard let first = spans.first, let last = spans.last, day >= first.0, day <= last.1 else { return false }
        if spans.contains(where: { day >= $0.0 && day <= $0.1 }) { return true }
        return false
    }

    func completedCount(for subject: CourseSubject) -> Int {
        subject.tasks.filter { completed.contains($0.id) }.count
    }

    func nextTask(for subject: CourseSubject, throughWeek: Int? = nil) -> CourseTask? {
        let eligibleTasks = subject.tasks.filter { task in
            throughWeek.map { task.week <= $0 } ?? true
        }
        return eligibleTasks.first { !isComplete($0) && !$0.optional }
            ?? eligibleTasks.first { !isComplete($0) }
    }

    var catchUpAssignments: [DailyAssignment] {
        course.subjects
            .compactMap { subject -> (CourseSubject, Int)? in
                let count = overdueTasks(for: subject).count
                return count > 0 ? (subject, count) : nil
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.name < rhs.0.name
            }
            .map { DailyAssignment(period: "\($0.1) tareas atrasadas", subjectCode: $0.0.code) }
    }

    func overdueTasks(for subject: CourseSubject) -> [CourseTask] {
        subject.tasks.filter { task in
            guard !isComplete(task), let week = course.weeks.first(where: { $0.n == task.week }), let end = date(from: week.e) else { return false }
            return Calendar.current.startOfDay(for: Date()) > end
        }
    }

    func assignments(for targetDate: Date) -> [DailyAssignment] {
        if isFrozen(targetDate) { return [] }
        let iso = dateKey(for: targetDate)
        if iso < "2026-09-16" {
            if iso == "2026-09-15" { return [DailyAssignment(period: "Inglés · preparación", subjectCode: "ELAR25")] }
            return []
        }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: targetDate)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: targetDate)?.start ?? targetDate
        let frozenBefore = frozenDays.compactMap(date(from:)).filter { $0 >= weekStart && $0 < calendar.startOfDay(for: targetDate) }.count
        let targetIndex = weekday == 1 ? 6 : weekday - 2
        let planIndex = targetIndex - frozenBefore
        if (0...3).contains(planIndex) { return WeeklyStudyPlan.assignments(forWeekday: planIndex + 2) }
        if weekday == 6 && frozenBefore == 0 { return catchUpAssignments }
        return []
    }

    func restoreProgress(from data: Data) throws {
        let validIDs = Set(course.subjects.flatMap(\.tasks).map(\.id))
        if let snapshot = try? JSONDecoder().decode(ProgressSnapshot.self, from: data) {
            completed = Set(snapshot.completed.filter { validIDs.contains($0) })
            studyDays = Set(snapshot.studyDays)
            if let extras = snapshot.extras {
                attempts = extras.attempts; unitNotes = extras.notes; liveClasses = extras.liveClasses
                events = extras.events; frozenDays = extras.frozenDays
            }
        } else {
            // Backward compatibility with exports created before streak history was added.
            let ids = try JSONDecoder().decode([String].self, from: data)
            completed = Set(ids.filter { validIDs.contains($0) })
            studyDays = []
        }
    }

    var backupDocument: ProgressBackup {
        let extras = TrackerExtras(attempts: attempts, notes: unitNotes, liveClasses: liveClasses, events: events, frozenDays: frozenDays)
        let snapshot = ProgressSnapshot(completed: Array(completed).sorted(), studyDays: Array(studyDays).sorted(), extras: extras)
        return ProgressBackup(data: (try? JSONEncoder().encode(snapshot)) ?? Data("{}".utf8))
    }

    func resetProgress() {
        completed = []; studyDays = []; attempts = []; unitNotes = [:]; liveClasses = []; events = []; frozenDays = []
        record("Progreso reiniciado")
    }

    private func save() {
        UserDefaults.standard.set(Array(completed), forKey: storageKey)
    }

    private func saveExtras() {
        let value = TrackerExtras(attempts: attempts, notes: unitNotes, liveClasses: liveClasses, events: events, frozenDays: frozenDays)
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: extrasKey) }
    }

    private func streakLength(from now: Date) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: now)
        if !studyDays.contains(dateKey(for: day)) || !isLective(day) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = previous
        }
        var length = 0
        var missedLective = 0
        while true {
            if isLective(day) && studyDays.contains(dateKey(for: day)) { length += 1; missedLective = 0 }
            else if isFrozen(day) { }
            else if isLective(day) { missedLective += 1; if missedLective > 2 { break } }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return length
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func date(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value).map { Calendar.current.startOfDay(for: $0) }
    }
}

enum ProgressStanding {
    case ahead(Int)
    case onTrack
    case catchingUp(Int)
    case behind(Int)

    var title: String {
        switch self {
        case .ahead: "Por delante"
        case .onTrack: "Al día"
        case .catchingUp(let count): "\(count) por hacer"
        case .behind(let count): "\(count) atrasadas"
        }
    }

    var detail: String {
        switch self {
        case .ahead(let count): "\(count) tareas por delante de la temporalización"
        case .onTrack: "Has completado lo previsto hasta ahora"
        case .catchingUp(let count): "Te quedan \(count) tareas por hacer; menos de una semana de trabajo"
        case .behind(let count): "Te faltan \(count) tareas para alcanzar el ritmo previsto"
        }
    }

    var color: Color {
        switch self {
        case .ahead: AppStyle.pink
        case .onTrack: AppStyle.teal
        case .catchingUp: AppStyle.yellow
        case .behind: .red
        }
    }

    var symbol: String {
        switch self {
        case .ahead: "arrow.up.right"
        case .onTrack: "checkmark"
        case .catchingUp: "exclamationmark.circle"
        case .behind: "arrow.down.right"
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case today = "Mi día"
    case subjects = "Asignaturas"
    case calendar = "Calendario"
    case plan = "Plan"
    case live = "Directos"
    case history = "Historial"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .subjects: "books.vertical"
        case .calendar: "calendar"
        case .plan: "list.bullet.rectangle"
        case .live: "video"
        case .history: "clock.arrow.circlepath"
        }
    }
}

struct DailyAssignment: Identifiable {
    let period: String
    let subjectCode: String
    var id: String { subjectCode }
}

enum WeeklyStudyPlan {
    static func assignments(forWeekday weekday: Int) -> [DailyAssignment] {
        switch weekday {
        case 2: [
            DailyAssignment(period: "Primera hora · fuerte", subjectCode: "ELAR01"),
            DailyAssignment(period: "Segunda hora · ligera", subjectCode: "ELAR18")
        ]
        case 3: [
            DailyAssignment(period: "Primera hora · fuerte", subjectCode: "ELAR02"),
            DailyAssignment(period: "Segunda hora · ligera", subjectCode: "ELAR23")
        ]
        case 4: [
            DailyAssignment(period: "Primera hora · fuerte", subjectCode: "ELAR03"),
            DailyAssignment(period: "Segunda hora · ligera", subjectCode: "ELAR05")
        ]
        case 5: [
            DailyAssignment(period: "Primera hora · fuerte", subjectCode: "ELAR04"),
            DailyAssignment(period: "Segunda hora · ligera", subjectCode: "ELAR07")
        ]
        default: []
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
        case .live: LiveClassesView()
        case .history: HistoryView()
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
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var confirmFreeze = false

    private var weekday: Int { Calendar.current.component(.weekday, from: selectedDate) }
    private var isFriday: Bool { weekday == 6 }
    private var isWeekend: Bool { weekday == 1 || weekday == 7 }
    private var assignments: [DailyAssignment] { store.assignments(for: selectedDate) }
    private var todayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE d 'de' MMMM"
        let value = formatter.string(from: selectedDate)
        return "\(value.prefix(1).uppercased())\(value.dropFirst())"
    }
    private var courseWeekTitle: String {
        guard let week = store.courseWeek(containing: selectedDate) else {
            return "Semana del curso"
        }
        return "Semana \(week.n) de \(store.course.weeks.count) · \(week.l)"
    }
    private var dailyHeading: String {
        if dateKey(selectedDate) < "2026-09-16" { return Calendar.current.isDate(selectedDate, inSameDayAs: dateForISO("2026-09-15")) ? "Inglés" : "El plan aún no empieza" }
        if isFriday { return "Pendientes y apuntes" }
        if store.isFrozen(selectedDate) { return "Día congelado" }
        if isWeekend { return "Día libre" }
        return "Lo siguiente que tienes que abrir"
    }
    private var dailyDescription: String {
        if dateKey(selectedDate) < "2026-09-16" { return Calendar.current.isDate(selectedDate, inSameDayAs: dateForISO("2026-09-15")) ? "Día dedicado a Inglés antes de comenzar la rotación semanal." : "La rotación del curso empieza el 16 de septiembre." }
        if isFriday { return "Viernes de repaso: aparecen primero las asignaturas con más tareas vencidas." }
        if store.isFrozen(selectedDate) { return "La racha queda protegida y las clases restantes pasan al siguiente día." }
        if isWeekend { return "Hoy no hay asignaturas programadas en tu plan. Descansa." }
        return "Abre el recurso indicado en UNIVERSAE: primero la primera hora y después la segunda. Al marcar una tarea, aparecerá la siguiente."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("UNIVERSAE · AUTOMATIZACIÓN Y ROBÓTICA", systemImage: "square.fill")
                            .font(.caption.bold()).tracking(0.5).foregroundStyle(AppStyle.navy)
                        Text(todayTitle).font(.largeTitle.bold()).foregroundStyle(AppStyle.navy)
                        Text(courseWeekTitle).foregroundStyle(AppStyle.slate)
                    }
                    Spacer(minLength: 8)
                    Text("\(store.completedCount) de \(store.totalTasks)")
                        .font(.headline.bold()).monospacedDigit()
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(AppStyle.yellow, in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(AppStyle.navy)
                }

                HStack(spacing: 6) {
                    Button { selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate } label: { Image(systemName: "chevron.left") }
                    ForEach(weekDates, id: \.self) { date in
                        Button { selectedDate = date } label: {
                            VStack(spacing: 3) {
                                Text(date.formatted(.dateTime.weekday(.narrow))).font(.caption.bold())
                                Text(date.formatted(.dateTime.day())).font(.headline)
                                Text(dayShortLabel(date)).font(.system(size: 8)).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity).padding(5)
                            .background(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? AppStyle.teal : Color.white, in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppStyle.navy, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                    Button { selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate } label: { Image(systemName: "chevron.right") }
                }
                if !Calendar.current.isDateInToday(selectedDate) { Button("Volver a hoy") { selectedDate = Calendar.current.startOfDay(for: Date()) }.font(.caption) }

                HStack(spacing: 8) {
                    MetricCard(title: "EXÁMENES PRESENCIALES", value: "\(daysUntilExam) días", symbol: "calendar", color: AppStyle.yellow)
                    MetricCard(title: "SIGUIENTE AUTOEVALUACIÓN", value: nextAssessmentCountdown, symbol: "checkmark.seal", color: (nextAssessmentDays ?? 99) < 7 ? .red : AppStyle.pink)
                    MetricCard(title: "HECHAS / PREVISTAS", value: "\(store.completedCount)/\(store.expectedTaskCount)", symbol: "chart.bar", color: store.completedCount < store.expectedTaskCount ? .red : AppStyle.teal)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(dailyHeading).font(.title2.bold()).foregroundStyle(AppStyle.navy)
                        Spacer()
                    }
                    Text(dailyDescription).font(.subheadline).foregroundStyle(AppStyle.slate)

                    if assignments.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: isFriday ? "checkmark.circle" : "sun.max")
                                .font(.title2).foregroundStyle(AppStyle.teal)
                            Text(store.isFrozen(selectedDate) ? "Día congelado" : isFriday ? "No quedan pendientes prioritarios" : "Hoy toca descansar")
                                .font(.headline.bold()).foregroundStyle(AppStyle.navy)
                            Text(isFriday
                                ? "Las tareas de las semanas terminadas están al día."
                                : "El sábado y el domingo no hay asignaturas en la rotación semanal.")
                                .font(.subheadline).foregroundStyle(AppStyle.slate)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppStyle.navy, lineWidth: 1.5))
                    } else {
                        VStack(spacing: 12) {
                            ForEach(assignments) { assignment in
                                if let subject = store.course.subjects.first(where: { $0.code == assignment.subjectCode }) {
                                    DailyAssignmentCard(assignment: assignment, subject: subject)
                                }
                            }
                        }
                    }
                }

                if isFriday { FridayNotesView() }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("PROGRESO DEL GRADO", systemImage: "chart.bar.fill")
                            .font(.caption.bold()).foregroundStyle(AppStyle.slate)
                        Text("\(store.completedCount) de \(store.totalTasks) · \(store.progress.formatted(.percent.precision(.fractionLength(0))))")
                            .font(.headline.bold()).foregroundStyle(AppStyle.navy)
                        ProgressComparisonBar(
                            actual: store.progress,
                            expected: store.totalTasks == 0 ? 0 : Double(store.expectedTaskCount) / Double(store.totalTasks),
                            color: store.standing(done: store.completedCount, expected: store.expectedTaskCount).color
                        )
                        Text("La marca vertical señala la meta de la temporalización.")
                            .font(.caption).foregroundStyle(AppStyle.slate)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppStyle.navy, lineWidth: 1.5))

                    VStack(alignment: .leading, spacing: 8) {
                        Label("RACHA", systemImage: "flame.fill")
                            .font(.caption.bold()).foregroundStyle(AppStyle.pink)
                        Text("\(store.currentStreak) días")
                            .font(.headline.bold()).foregroundStyle(AppStyle.navy)
                        Text(store.currentStreak == 0 ? "Marca una tarea para iniciar la racha." : "Mejor: \(store.bestStreak) días")
                            .font(.caption).foregroundStyle(AppStyle.slate)
                        Text(store.didStudyToday
                             ? "Hoy ya cuenta · margen completo: 2 días · congeladores: \(store.freezesThisWeek)/2"
                             : "\(store.missedLectiveDays) días lectivos sin actividad · te quedan \(store.remainingStreakGrace) de margen · congeladores: \(store.freezesThisWeek)/2")
                            .font(.caption2).foregroundStyle(store.remainingStreakGrace == 0 ? Color.red : AppStyle.slate)
                        if store.isLective(Date()) && !store.isFrozen(Date()) && store.freezesThisWeek < 2 {
                            Button("Congelar hoy") { confirmFreeze = true }.buttonStyle(.bordered).font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppStyle.navy, lineWidth: 1.5))
                }
            }
            .padding(18)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppStyle.canvas)
        .navigationTitle("Mi día")
        .confirmationDialog("¿Congelar hoy?", isPresented: $confirmFreeze, titleVisibility: .visible) {
            Button("Congelar y desplazar el plan") { store.freezeToday() }
            Button("Cancelar", role: .cancel) { }
        } message: { Text("La racha queda protegida y las clases pendientes se desplazan un día, incluso al sábado.") }
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let offset = (calendar.component(.weekday, from: selectedDate) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -offset, to: selectedDate) ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }
    private func dayShortLabel(_ date: Date) -> String {
        let codes = store.assignments(for: date).map(\.subjectCode)
        if codes.contains("ELAR25") { return "Inglés" }
        if !codes.isEmpty { return codes.joined(separator: "+") }
        return Calendar.current.component(.weekday, from: date) == 6 ? "Pendientes" : "Libre"
    }
    private func dateKey(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
    private func dateForISO(_ value: String) -> Date { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.date(from: value) ?? Date() }
    private var daysUntilExam: Int {
        let format = DateFormatter(); format.dateFormat = "yyyy-MM-dd"
        guard let exam = format.date(from: "2027-05-19") else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: exam).day ?? 0)
    }
    private var nextAssessmentCountdown: String {
        let task = store.course.subjects.flatMap(\.tasks).filter { $0.type == "A" && !store.isComplete($0) }.min { $0.week < $1.week }
        guard let task, let week = store.course.weeks.first(where: { $0.n == task.week }) else { return "Completadas" }
        let format = DateFormatter(); format.dateFormat = "yyyy-MM-dd"
        guard let end = format.date(from: week.e) else { return "Semana \(task.week)" }
        let count = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: end).day ?? 0
        return "\(max(0, count)) días"
    }
    private var nextAssessmentDays: Int? {
        let task = store.course.subjects.flatMap(\.tasks).filter { $0.type == "A" && !store.isComplete($0) }.min { $0.week < $1.week }
        guard let task, let week = store.course.weeks.first(where: { $0.n == task.week }) else { return nil }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        guard let deadline = formatter.date(from: week.e) else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: deadline).day
    }
}

struct DailyAssignmentCard: View {
    @EnvironmentObject private var store: GradeStore
    let assignment: DailyAssignment
    let subject: CourseSubject

    private var done: Int { store.completedCount(for: subject) }
    private var expected: Int { store.expectedTaskCount(for: subject) }
    private var fraction: Double { subject.tasks.isEmpty ? 0 : Double(done) / Double(subject.tasks.count) }
    private var target: Double { subject.tasks.isEmpty ? 0 : Double(expected) / Double(subject.tasks.count) }
    private var standing: ProgressStanding { store.standing(done: done, expected: expected, subject: subject) }
    private var nextTask: CourseTask? {
        let throughWeek = assignment.period.hasPrefix("Pendiente") ? store.currentCourseWeek : nil
        return store.nextTask(for: subject, throughWeek: throughWeek)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(assignment.period.uppercased())
                        .font(.caption.bold()).tracking(0.5).foregroundStyle(AppStyle.slate)
                    Text(subject.name)
                        .font(.headline.bold()).foregroundStyle(AppStyle.navy)
                }
                Spacer(minLength: 8)
                Text(standing.title.uppercased())
                    .font(.caption2.bold()).foregroundStyle(standing.title == "Atrasada" ? AppStyle.navy : standing.color)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(standing.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 3))
            }

            ProgressComparisonBar(actual: fraction, expected: target, color: standing.color)
            Text("\(done) de \(subject.tasks.count) hechas · \(expected) previstas hasta la semana \(store.referenceWeek)")
                .font(.caption).foregroundStyle(AppStyle.slate)

            Divider()

            if assignment.period.contains("atrasadas") {
                Label("PENDIENTES PARA RECUPERAR", systemImage: "exclamationmark.circle.fill")
                    .font(.caption.bold()).foregroundStyle(.red)
                ForEach(store.overdueTasks(for: subject)) { TaskRow(task: $0) }
            } else if let nextTask {
                Label("SIGUIENTE TAREA", systemImage: "arrow.up.right.square.fill")
                    .font(.caption.bold()).foregroundStyle(AppStyle.pink)
                Text(nextTask.title)
                    .font(.title3.bold()).foregroundStyle(AppStyle.navy)
                Text("\(nextTask.typeName) · Unidad \(nextTask.unit) · Semana \(nextTask.week) · \(nextTask.minutes) min\(nextTask.optional ? " · opcional" : "")")
                    .font(.caption).foregroundStyle(AppStyle.slate)
                Button {
                    store.toggle(nextTask)
                } label: {
                    Label("Marcar como hecha y mostrar la siguiente", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppStyle.teal)
            } else {
                Label("Todas las tareas de esta asignatura están hechas", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold()).foregroundStyle(AppStyle.teal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppStyle.navy, lineWidth: 1.5))
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

struct ProgressComparisonBar: View {
    let actual: Double
    let expected: Double
    let color: Color

    private func bounded(_ value: Double) -> Double { min(max(value, 0), 1) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(AppStyle.slate.opacity(0.25))
                Capsule().fill(color).frame(width: geometry.size.width * bounded(actual))
                Rectangle()
                    .fill(AppStyle.navy)
                    .frame(width: 3, height: 15)
                    .offset(x: max(0, geometry.size.width * bounded(expected) - 1.5))
            }
        }
        .frame(height: 15)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progreso real \(actual.formatted(.percent.precision(.fractionLength(0)))) frente al ritmo previsto \(expected.formatted(.percent.precision(.fractionLength(0))))")
    }
}

struct StreakCard: View {
    @EnvironmentObject private var store: GradeStore

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Label("RACHA DE ESTUDIO", systemImage: "flame.fill")
                    .font(.caption.bold()).tracking(0.5).foregroundStyle(AppStyle.yellow)
                Text("\(store.currentStreak) \(store.currentStreak == 1 ? "día" : "días")")
                    .font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text(store.currentStreak == 0
                     ? "Marca una tarea hoy para empezar tu racha."
                     : "\(store.didStudyToday ? "Has estudiado hoy" : "Tu última actividad fue ayer") · Mejor racha: \(store.bestStreak) días")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.78))
            }
            Spacer(minLength: 8)
            Image(systemName: "flame.fill")
                .font(.system(size: 32, weight: .bold)).foregroundStyle(AppStyle.pink)
                .padding(14).background(.white.opacity(0.08), in: Circle())
                .accessibilityHidden(true)
        }
        .padding(18)
        .background(AppStyle.navy, in: RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .bottomTrailing) {
            Rectangle().fill(AppStyle.pink).frame(width: 8, height: 8).offset(x: 4, y: 4)
        }
    }
}

struct SubjectCard: View {
    @EnvironmentObject private var store: GradeStore
    let subject: CourseSubject
    let done: Int
    private var fraction: Double { subject.tasks.isEmpty ? 0 : Double(done) / Double(subject.tasks.count) }
    private var expected: Int { store.expectedTaskCount(for: subject) }
    private var standing: ProgressStanding { store.standing(done: done, expected: expected, subject: subject) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(subject.abbr.uppercased())
                .font(.caption.bold()).tracking(0.4).foregroundStyle(AppStyle.slate)
            Text(subject.name).font(.headline.bold()).foregroundStyle(AppStyle.navy).multilineTextAlignment(.leading).lineLimit(3)
            ProgressComparisonBar(
                actual: fraction,
                expected: subject.tasks.isEmpty ? 0 : Double(expected) / Double(subject.tasks.count),
                color: standing.color
            )
            HStack(spacing: 5) {
                Image(systemName: standing.symbol)
                Text(standing.title)
                Spacer(minLength: 0)
                Text("\(done)/\(subject.tasks.count)").monospacedDigit()
            }
            .font(.caption.bold()).foregroundStyle(standing.color == AppStyle.yellow ? AppStyle.navy : standing.color)
            Text("\(expected) previstas hasta la semana \(store.referenceWeek)")
                .font(.caption).foregroundStyle(AppStyle.slate)
            let difficultyCount = store.attempts.filter { attempt in
                attempt.difficulty == .hard && subject.tasks.contains(where: { $0.id == attempt.taskID })
            }.count
            if difficultyCount > 0 {
                Label("\(difficultyCount) intento\(difficultyCount == 1 ? "" : "s") difícil\(difficultyCount == 1 ? "" : "es") 🏮", systemImage: "lamp.desk.fill")
                    .font(.caption).foregroundStyle(AppStyle.pink)
            }
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
    @State private var expandedSubjects: Set<String> = []

    var body: some View {
        List {
            Section {
                Text("La barra compara tus tareas completadas con las previstas. La marca vertical indica la meta.")
                    .font(.footnote).foregroundStyle(AppStyle.slate)
                ForEach(orderedSubjects) { subject in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSubjects.contains(subject.id) },
                            set: { isExpanded in
                                if isExpanded { expandedSubjects.insert(subject.id) }
                                else { expandedSubjects.remove(subject.id) }
                            }
                        )
                    ) {
                        ForEach(subject.units) { unit in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Unidad \(unit.number) · \(unit.title)")
                                    .font(.subheadline.bold()).foregroundStyle(AppStyle.navy)
                                    .padding(.top, 8)
                                let unitTasks = subject.tasks.filter { $0.unit == unit.number }
                                Text("\(unitTasks.filter(store.isComplete).count)/\(unitTasks.count) tareas completadas")
                                    .font(.caption).foregroundStyle(AppStyle.slate)
                                UnitNotesEditor(subject: subject, unit: unit)
                                ForEach(subject.tasks.filter { $0.unit == unit.number }) { task in
                                    TaskRow(task: task)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    } label: {
                SubjectCard(subject: subject, done: store.completedCount(for: subject))
                    .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.white)
                    .listRowSeparatorTint(AppStyle.slate.opacity(0.25))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppStyle.canvas)
        .navigationTitle("Asignaturas")
    }

    private var orderedSubjects: [CourseSubject] {
        store.course.subjects.sorted { a, b in
            let rank: (CourseSubject) -> (Int, Int) = { subject in
                switch store.standing(done: store.completedCount(for: subject), expected: store.expectedTaskCount(for: subject), subject: subject) {
                case .behind(let n): (0, -n)
                case .catchingUp(let n): (1, -n)
                case .onTrack: (2, 0)
                case .ahead(let n): (3, n)
                }
            }
            return rank(a) < rank(b)
        }
    }
}

struct UnitNotesEditor: View {
    @EnvironmentObject private var store: GradeStore
    let subject: CourseSubject
    let unit: CourseUnit
    @State private var note = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Apuntes de la unidad").font(.caption.bold()).foregroundStyle(AppStyle.slate)
            TextEditor(text: $note).frame(minHeight: 55).overlay(RoundedRectangle(cornerRadius: 4).stroke(AppStyle.slate.opacity(0.3)))
            Button("Guardar apuntes") { store.saveNote(note, subject: subject, unit: unit) }.buttonStyle(.bordered)
        }
        .onAppear { note = store.unitNotes[store.noteKey(subject: subject, unit: unit)] ?? "" }
    }
}

struct SubjectDetailView: View {
    @EnvironmentObject private var store: GradeStore
    let subject: CourseSubject

    var body: some View {
        List {
            Section {
                let done = store.completedCount(for: subject)
                let expected = store.expectedTaskCount(for: subject)
                let fraction = subject.tasks.isEmpty ? 0 : Double(done) / Double(subject.tasks.count)
                let target = subject.tasks.isEmpty ? 0 : Double(expected) / Double(subject.tasks.count)
                let standing = store.standing(done: done, expected: expected, subject: subject)
                ProgressComparisonBar(actual: fraction, expected: target, color: standing.color)
                Text("\(store.completedCount(for: subject)) de \(subject.tasks.count) tareas completadas")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("\(expected) tareas previstas hasta la semana \(store.referenceWeek)")
                    .font(.caption).foregroundStyle(.secondary)
                Label(standing.detail, systemImage: standing.symbol)
                    .font(.caption.bold()).foregroundStyle(standing.title == "Atrasada" ? AppStyle.navy : standing.color)
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
    @State private var showingAssessment = false
    @State private var grade = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if task.type == "A" && !store.isComplete(task) { showingAssessment = true }
                else { store.toggle(task) }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: store.isComplete(task) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(store.isComplete(task) ? AppStyle.teal : AppStyle.slate)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title).foregroundStyle(store.isComplete(task) ? .secondary : .primary).strikethrough(store.isComplete(task))
                        Text("\(task.typeName) · Unidad \(task.unit) · Semana \(task.week) · \(task.minutes) min\(task.optional ? " · opcional" : "") · hasta \(deadline)")
                            .font(.caption).foregroundStyle(isOverdue && !store.isComplete(task) ? Color.red : Color.primary.opacity(0.65))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if task.type == "A" {
                HStack(spacing: 8) {
                    TextField("Nota", text: $grade).frame(maxWidth: 80)
                    Button("−") { store.removeLastAttempt(task) }.disabled(store.attempts(for: task).isEmpty)
                    Button("+") { store.addAttempt(task, grade: grade, difficulty: .medium); grade = "" }
                    ForEach(StudyDifficulty.allCases) { item in
                        Button(item.symbol) { store.setDifficulty(item, task: task) }
                            .buttonStyle(.plain).accessibilityLabel(item.rawValue)
                    }
                }.font(.caption)
                ForEach(store.attempts(for: task)) { attempt in
                    Text("\(attempt.date.formatted(date: .abbreviated, time: .omitted)) · \(attempt.grade.isEmpty ? "Sin nota" : attempt.grade) · \(attempt.difficulty.symbol)")
                        .font(.caption2).foregroundStyle(AppStyle.slate)
                }
            }
        }
        .sheet(isPresented: $showingAssessment) {
            AssessmentSheet(task: task) { grade, difficulty in
                store.complete(task, grade: grade, difficulty: difficulty)
            } skip: { store.complete(task) }
        }
    }

    private var deadline: String {
        guard let week = store.course.weeks.first(where: { $0.n == task.week }) else { return "—" }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "es_ES"); formatter.dateFormat = "d MMM"
        return formatter.string(from: formatter.date(from: week.e) ?? Date())
    }
    private var isOverdue: Bool {
        guard let week = store.course.weeks.first(where: { $0.n == task.week }) else { return false }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        guard let end = formatter.date(from: week.e) else { return false }
        return Calendar.current.startOfDay(for: Date()) > Calendar.current.startOfDay(for: end)
    }
}

struct FridayNotesView: View {
    @EnvironmentObject private var store: GradeStore
    var body: some View {
        let closed: [(CourseSubject, CourseUnit)] = store.course.subjects.flatMap { subject in
            subject.units.compactMap { unit in
                let tasks = subject.tasks.filter { $0.unit == unit.number }
                let assessed = tasks.filter { $0.type == "A" }.contains { !store.attempts(for: $0).isEmpty }
                return !tasks.isEmpty && tasks.allSatisfy(store.isComplete) && assessed ? (subject, unit) : nil
            }
        }
        VStack(alignment: .leading, spacing: 10) {
            Text("Apuntes de unidades cerradas").font(.title3.bold()).foregroundStyle(AppStyle.navy)
            if closed.isEmpty { Text("Aún no hay unidades con todas las tareas y una autoevaluación registradas.").font(.subheadline).foregroundStyle(AppStyle.slate) }
            ForEach(Array(closed.enumerated()), id: \.offset) { entry in UnitNotesEditor(subject: entry.element.0, unit: entry.element.1) }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 5))
    }
}

struct AssessmentSheet: View {
    let task: CourseTask
    let save: (String, StudyDifficulty) -> Void
    let skip: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: GradeStore
    @State private var grade = ""
    @State private var difficulty: StudyDifficulty = .medium
    var body: some View {
        NavigationStack {
            Form {
                Section("Autoevaluación") {
                    Text(task.title)
                    Text("Intento \(store.attempts(for: task).count + 1)")
                    TextField("Nota (opcional)", text: $grade)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Picker("Dificultad", selection: $difficulty) {
                        ForEach(StudyDifficulty.allCases) { item in Text("\(item.symbol) \(item.rawValue)").tag(item) }
                    }
                }
                if !store.attempts(for: task).isEmpty {
                    Section("Intentos anteriores") {
                        ForEach(store.attempts(for: task)) { attempt in Text("\(attempt.date.formatted(date: .abbreviated, time: .omitted)) · \(attempt.grade.isEmpty ? "Sin nota" : attempt.grade) · \(attempt.difficulty.symbol)") }
                    }
                }
            }
            .navigationTitle("Registrar intento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Saltar") { skip(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar intento") { save(grade, difficulty); dismiss() } }
            }
        }
        .frame(minWidth: 320, minHeight: 300)
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
        List {
        ForEach(store.course.weeks) { week in
            let tasks = store.course.subjects.flatMap(\.tasks).filter { $0.week == week.n }
            let done = tasks.filter(store.isComplete).count
            let autoevaluations = tasks.filter { $0.type == "A" }.count
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Semana \(week.n)").font(.headline.bold()).foregroundStyle(AppStyle.navy)
                    Spacer()
                    Text(week.l).foregroundStyle(AppStyle.slate)
                }
                if let special = week.sp {
                    Text(special).font(.subheadline.bold()).foregroundStyle(AppStyle.pink)
                }
                if autoevaluations >= 4 { Label("Semana intensa · \(autoevaluations) autoevaluaciones", systemImage: "exclamationmark.triangle.fill").font(.caption.bold()).foregroundStyle(.red) }
                ProgressView(value: tasks.isEmpty ? 0 : Double(done) / Double(tasks.count)).tint(AppStyle.teal)
                Text("\(done) de \(tasks.count) tareas · \(autoevaluations) autoevaluaciones")
                    .font(.caption).foregroundStyle(AppStyle.slate)
            }
            .padding(.vertical, 5)
            .listRowBackground(week.n == store.currentCourseWeek ? AppStyle.teal.opacity(0.18) : (autoevaluations >= 4 ? Color.red.opacity(0.08) : Color.white))
            .overlay(alignment: .leading) { if week.n == store.currentCourseWeek { Rectangle().fill(AppStyle.teal).frame(width: 4) } }
        }
        Section("Pausas entre semanas") {
            Text("Los huecos entre los rangos de temporalización representan descansos lectivos. La racha los omite y no los cuenta como días sin estudio.")
                .font(.caption).foregroundStyle(AppStyle.slate)
        }
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
    @State private var confirmReset = false

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
            Section("Qué significa el semáforo") {
                Label("Por delante · superas la meta de la temporalización", systemImage: "crown.fill").foregroundStyle(AppStyle.pink)
                Label("Al día · estás en la marca prevista", systemImage: "checkmark").foregroundStyle(AppStyle.teal)
                Label("Por hacer · retraso menor que una semana de trabajo", systemImage: "exclamationmark.circle").foregroundStyle(AppStyle.yellow)
                Label("Atrasada · retraso superior a una semana de trabajo", systemImage: "arrow.down.circle").foregroundStyle(.red)
            }
            Section("Estimación del curso") {
                LabeledContent("Material del curso", value: "203 h")
                LabeledContent("Tareas marcables", value: "\(store.totalTasks)")
                LabeledContent("Ritmo orientativo", value: "10 h por semana")
                LabeledContent("Tiempo hasta el examen", value: "unas 320 h")
                Text("El margen estimado es de unas 115 h. Son referencias fijas del plan, no se recalculan automáticamente.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Sobre los datos") {
                Text("El progreso se guarda en este dispositivo. No hay sincronización automática: usa la copia JSON para transferirlo entre Mac y iPhone.")
                    .foregroundStyle(.secondary)
            }
            Section("Copia de progreso") {
                Button { showingExporter = true } label: {
                    Label("Exportar progreso", systemImage: "square.and.arrow.up")
                }
                Button { showingImporter = true } label: {
                    Label("Importar progreso", systemImage: "square.and.arrow.down")
                }
                Button("Reiniciar progreso", role: .destructive) { confirmReset = true }
                Text("También puedes pegar aquí el archivo JSON exportado desde tu tracking actual; las tareas mantienen sus identificadores originales.")
                    .font(.caption).foregroundStyle(.secondary)
                if let importMessage { Text(importMessage).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppStyle.canvas)
        .navigationTitle("Tu plan")
        .confirmationDialog("¿Reiniciar todo el progreso?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reiniciar progreso", role: .destructive) { store.resetProgress(); importMessage = "Progreso reiniciado." }
            Button("Cancelar", role: .cancel) { }
        } message: { Text("Se borrarán tareas, intentos, apuntes, clases e historial guardados en este dispositivo.") }
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

struct LiveClassesView: View {
    @EnvironmentObject private var store: GradeStore
    @State private var subjectCode = ""
    @State private var date = Date()
    @State private var topics = ""
    @State private var notes = ""
    @State private var alert = false
    var body: some View {
        List {
            Section("Añadir clase") {
                Picker("Asignatura", selection: $subjectCode) {
                    ForEach(store.course.subjects) { Text($0.name).tag($0.code) }
                }
                DatePicker("Fecha", selection: $date, displayedComponents: .date)
                TextField("Temas que se tocaron", text: $topics, axis: .vertical).lineLimit(2...5)
                TextField("Notas sueltas (opcional)", text: $notes, axis: .vertical).lineLimit(2...5)
                Button("Guardar clase") {
                    guard !subjectCode.isEmpty, !topics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { alert = true; return }
                    store.addLiveClass(LiveClassRecord(subjectCode: subjectCode, date: date, topics: topics, notes: notes))
                    topics = ""; notes = ""
                }.buttonStyle(.borderedProminent)
            }
            ForEach(store.course.subjects) { subject in
                let entries = store.liveClasses.filter { $0.subjectCode == subject.code }.sorted { $0.date > $1.date }
                if !entries.isEmpty {
                    Section(subject.name) {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.date.formatted(date: .long, time: .omitted)).font(.caption).foregroundStyle(AppStyle.slate)
                                Text(entry.topics).font(.headline)
                                if !entry.notes.isEmpty { Text(entry.notes).font(.subheadline) }
                                Button("Borrar", role: .destructive) { store.deleteLiveClass(entry) }
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .onAppear { if subjectCode.isEmpty { subjectCode = store.course.subjects.first?.code ?? "" } }
        .alert("Falta información", isPresented: $alert) { Button("Vale", role: .cancel) { } } message: { Text("Elige una asignatura e indica los temas vistos.") }
        .scrollContentBackground(.hidden).background(AppStyle.canvas).navigationTitle("Clases en directo")
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: GradeStore
    @State private var copied = false
    private var text: String {
        store.events.map { "\($0.date.formatted(date: .numeric, time: .shortened)) · \($0.message)" }.joined(separator: "\n")
    }
    var body: some View {
        List {
            Section {
                Button(copied ? "Copiado" : "Copiar todo") {
                    #if os(macOS)
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
                    #else
                    UIPasteboard.general.string = text
                    #endif
                    copied = true
                }
            }
            Section("Actividad reciente") {
                if store.events.isEmpty { ContentUnavailableView("Todavía no hay actividad", systemImage: "clock.arrow.circlepath") }
                ForEach(store.events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.message)
                        Text(event.date.formatted(date: .long, time: .shortened)).font(.caption).foregroundStyle(AppStyle.slate)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(AppStyle.canvas).navigationTitle("Caja negra")
    }
}

struct ProgressSnapshot: Codable {
    let completed: [String]
    let studyDays: [String]
    var extras: TrackerExtras?
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
