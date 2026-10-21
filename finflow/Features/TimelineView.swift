import SwiftData
import SwiftUI

struct TimelineView: View {
    @Query(sort: \Expense.spokenOn) private var expenses: [Expense]
    @Environment(\.screenScale) private var screenScale
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var dragOffset: CGFloat = 0
    @State private var dragGeneration = 0
    @State private var showCalendar = false
    @State private var showDay = false

    private let spacing: CGFloat = 74

    var body: some View {
        ZStack {
            ScreenBackground()
            PanelBackground()
            GeometryReader { proxy in
                let layout = ArcLayout(in: proxy.size, scale: screenScale)
                ZStack {
                    ProportionalImage(name: "TimelineArc", designWidth: 176, designHeight: 680)
                        .position(
                            x: layout.origin.x + layout.width / 2,
                            y: layout.origin.y + layout.height / 2
                        )
                        .allowsHitTesting(false)

                    ForEach(Array(days.enumerated()), id: \.element) { index, day in
                        dayMark(day, index: index, layout: layout)
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(drag)
            }
            .padding(.top, 18)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showDay) {
            DayExpensesSheet(date: selectedDate, expenses: expenses(on: selectedDate))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        LinearGradient(
                            colors: [
                                Color(red: 0.467, green: 0.082, blue: 1).opacity(0.34),
                                FinFlowTheme.backgroundBottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
        }
        .sheet(isPresented: $showCalendar) {
            CalendarSheet(selection: $selectedDate)
                .presentationDetents([.medium])
                .presentationBackground(FinFlowTheme.backgroundBottom)
        }
    }

    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let earliestExpense = expenses.map { calendar.startOfDay(for: $0.spokenOn) }.min()
        let windowStart = calendar.date(byAdding: .day, value: -60, to: today) ?? today
        let start = [earliestExpense ?? windowStart, windowStart, selectedDate].min() ?? windowStart
        let end = max(today, selectedDate)
        var cursor = start
        var result: [Date] = []
        while cursor <= end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private var selectedIndex: Int {
        let calendar = Calendar.current
        return days.firstIndex { calendar.isDate($0, inSameDayAs: selectedDate) } ?? max(days.count - 1, 0)
    }

    private func expenses(on day: Date) -> [Expense] {
        let calendar = Calendar.current
        return expenses
            .filter { calendar.isDate($0.spokenOn, inSameDayAs: day) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func total(on day: Date) -> Double {
        expenses(on: day).reduce(0) { $0 + $1.amount }
    }

    @ViewBuilder
    private func dayMark(_ day: Date, index: Int, layout: ArcLayout) -> some View {
        let delta = CGFloat(index - selectedIndex) + (dragOffset / spacing)
        let selected = abs(delta) < 0.35
        let viewY = layout.focusViewY + delta * spacing / layout.scale
        let onArc = viewY >= 0 && viewY <= 680
        let point = layout.point(viewY: min(max(viewY, 0), 680))
        let faceWidth = (selected ? 41 : 28) * screenScale
        let amountWidth: CGFloat = 104
        let edgeFade = min(viewY, 680 - viewY) / 36
        let opacity = onArc ? min(max(edgeFade, 0), 1) * (selected ? 1 : 0.85) : 0
        let angle = layout.lineAngle(at: min(max(viewY, 0), 680))

        TimelineFace(selected: selected)
            .position(x: point.x, y: point.y)
            .opacity(opacity)
            .onTapGesture { select(day, selected: selected, onArc: onArc) }

        Text(FinFlowTheme.rupees(total(on: day)))
            .font(.system(size: selected ? 15 : 12, weight: selected ? .bold : .regular))
            .foregroundStyle(selected ? Color(red: 0.97, green: 1, blue: 0.98) : FinFlowTheme.faint)
            .lineLimit(1)
            .frame(width: amountWidth, alignment: .trailing)
            .rotationEffect(.radians(angle), anchor: .trailing)
            .position(x: point.x - faceWidth / 2 - 10 - amountWidth / 2, y: point.y)
            .opacity(opacity)
            .onTapGesture { select(day, selected: selected, onArc: onArc) }

        if selected {
            Button {
                showCalendar = true
            } label: {
                Text(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.867, green: 0.867, blue: 0.933))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(FinFlowTheme.pill, in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(width: 112, alignment: .leading)
            .rotationEffect(.radians(angle), anchor: .leading)
            .position(x: point.x + faceWidth / 2 + 10 + 56, y: point.y)
            .opacity(opacity)
        }
    }

    private func select(_ day: Date, selected: Bool, onArc: Bool) {
        guard onArc else { return }
        if selected {
            showDay = true
        } else {
            dragGeneration += 1
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                selectedDate = day
                dragOffset = 0
            }
        }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                dragGeneration += 1
                dragOffset = clampedOffset(value.translation.height)
            }
            .onEnded { value in
                var steps = Int((value.translation.height / spacing).rounded())
                if steps == 0 {
                    if value.velocity.height > 450 {
                        steps = 1
                    } else if value.velocity.height < -450 {
                        steps = -1
                    }
                }
                let earliest = selectedIndex
                let latest = selectedIndex - (days.count - 1)
                steps = min(max(steps, latest), earliest)
                let target = days[selectedIndex - steps]
                let snapped = CGFloat(steps) * spacing
                dragGeneration += 1
                let generation = dragGeneration
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    dragOffset = snapped
                } completion: {
                    guard generation == dragGeneration else { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        selectedDate = target
                        dragOffset = 0
                    }
                }
            }
    }

    private func clampedOffset(_ raw: CGFloat) -> CGFloat {
        let towardPast = CGFloat(selectedIndex) * spacing
        let towardToday = CGFloat(selectedIndex - (days.count - 1)) * spacing
        return min(max(raw, towardToday), towardPast)
    }
}

private struct ArcLayout {
    var origin: CGPoint
    var scale: CGFloat
    var width: CGFloat
    var height: CGFloat

    static let focusViewY: CGFloat = 350.74

    private static let samples: [(CGFloat, CGFloat)] = [
        (0, 174.84), (20, 141.75), (40, 117.04), (60, 96.79), (80, 80.22),
        (100, 65.98), (120, 53.86), (140, 43.39), (160, 34.65), (180, 26.81),
        (200, 20.45), (220, 15.12), (240, 10.70), (260, 7.24), (280, 4.49),
        (300, 2.52), (320, 1.23), (340, 0.61), (360, 0.58), (380, 1.16),
        (400, 2.46), (420, 4.40), (440, 7.09), (460, 10.69), (480, 15.16),
        (500, 20.74), (520, 27.67), (540, 35.55), (560, 45.28), (580, 57.07),
        (600, 70.42), (620, 87.74), (640, 108.07), (660, 135.38), (680, 175.50)
    ]

    init(in size: CGSize, scale: CGFloat) {
        self.scale = scale
        width = 176 * scale
        height = 680 * scale
        origin = CGPoint(
            x: size.width - 8 - width,
            y: (size.height - height) / 2
        )
    }

    var focusViewY: CGFloat { Self.focusViewY }

    func point(viewY: CGFloat) -> CGPoint {
        CGPoint(
            x: origin.x + Self.curveX(at: viewY) * scale,
            y: origin.y + viewY * scale
        )
    }

    func lineAngle(at viewY: CGFloat) -> CGFloat {
        let slope = Self.slope(at: viewY)
        return atan2(-slope, 1)
    }

    private static func curveX(at viewY: CGFloat) -> CGFloat {
        let clamped = min(max(viewY, 0), 680)
        let index = Int(clamped / 20)
        let upper = min(index + 1, samples.count - 1)
        let lower = min(index, samples.count - 1)
        let start = samples[lower]
        let end = samples[upper]
        guard end.0 != start.0 else { return start.1 }
        let t = (clamped - start.0) / (end.0 - start.0)
        return start.1 + (end.1 - start.1) * t
    }

    private static func slope(at viewY: CGFloat) -> CGFloat {
        let before = curveX(at: viewY - 10)
        let after = curveX(at: viewY + 10)
        return (after - before) / 20
    }
}

struct DayExpensesSheet: View {
    var date: Date
    var expenses: [Expense]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            ProportionalImage(name: "DaySheetFace", designWidth: 52, designHeight: 54)
            Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .padding(.top, 8)
            Text(date.formatted(.dateTime.weekday(.wide)))
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 1, green: 0.93, blue: 1))
                .padding(.top, 4)
            ScrollView {
                if expenses.isEmpty {
                    Text("Nothing recorded for this day.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FinFlowTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 28)
                } else {
                    LazyVStack(spacing: 15) {
                        ForEach(expenses) { expense in
                            ExpenseCard(expense: expense)
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct ExpenseCard: View {
    var expense: Expense

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(FinFlowTheme.rupees(expense.amount))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(expense.category)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FinFlowTheme.category, in: Capsule())
            }
            Text(expense.detail)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.7),
                            Color(red: 0.396, green: 0.114, blue: 1).opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

struct CalendarSheet: View {
    @Binding var selection: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a day")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            DatePicker(
                "Day",
                selection: $selection,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(FinFlowTheme.category)
            .colorScheme(.dark)
            Button("Show this day") {
                selection = Calendar.current.startOfDay(for: selection)
                dismiss()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(FinFlowTheme.backgroundBottom)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.white, in: Capsule())
        }
        .padding(24)
    }
}
