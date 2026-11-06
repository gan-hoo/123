import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.accent) private var accent
    let filter: MemoFilter
    var onSelectFilter: (MemoFilter) -> Void
    var onRoute: (Route) -> Void

    @Query(filter: #Predicate<Memo> { $0.trashedAt == nil }, sort: \Memo.createdAt)
    private var memos: [Memo]

    private var tagCounts: [TagCount] { TagParser.tagCounts(from: memos) }

    /// 所有笔记的字数（不计空白字符）
    private var wordCount: Int {
        memos.reduce(0) { sum, memo in
            sum + memo.fullText.reduce(0) { $1.isWhitespace ? $0 : $0 + 1 }
        }
    }

    private var usedDays: Int {
        guard let first = memos.first?.createdAt else { return 0 }
        let cal = Calendar.current
        let d = cal.dateComponents([.day], from: cal.startOfDay(for: first), to: cal.startOfDay(for: Date())).day ?? 0
        return d + 1
    }

    var body: some View {
        let tags = tagCounts
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Text("Jin Notes")
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        onRoute(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    stat(memos.count, "笔记")
                    Spacer()
                    stat(tags.filter { $0.depth == 0 }.count, "标签")
                    Spacer()
                    stat(usedDays, "天")
                    Spacer()
                    stat(wordCount, "字数")
                }
                .padding(.horizontal, 8)

                MonthHeatmapView(
                    dates: memos.map(\.createdAt),
                    selectedDay: {
                        if case .day(let d) = filter { return d }
                        return nil
                    }(),
                    onSelectDay: { day in onSelectFilter(.day(day)) }
                )

                VStack(spacing: 2) {
                    navRow("全部笔记", icon: "square.grid.2x2", selected: filter == .all) {
                        onSelectFilter(.all)
                    }
                    navRow("置顶", icon: "pin", selected: filter == .pinned) {
                        onSelectFilter(.pinned)
                    }
                    navRow("每日回顾", icon: "sparkles", selected: false) {
                        onRoute(.review)
                    }
                    navRow("回收站", icon: "trash", selected: false) {
                        onRoute(.trash)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("全部标签")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                    if tags.isEmpty {
                        Text("在笔记中输入 #标签 即可创建")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                    }
                    ForEach(tags) { tag in
                        tagRow(tag)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 10_000 {
            let w = Double(n) / 10_000
            return w >= 100 ? "\(Int(w))万" : String(format: "%.1f万", w)
        }
        return "\(n)"
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(formatCount(value))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func navRow(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 22)
                Text(title)
                Spacer()
            }
            .font(.body)
            .foregroundStyle(selected ? accent : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selected ? accent.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tagRow(_ tag: TagCount) -> some View {
        let selected = filter == .tag(tag.tag)
        return Button {
            onSelectFilter(.tag(tag.tag))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "number")
                    .font(.footnote)
                    .foregroundStyle(selected ? accent : Color.secondary)
                Text(tag.leaf)
                    .lineLimit(1)
                Spacer()
                Text("\(tag.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(selected ? accent : Color.primary)
            .padding(.leading, 12 + CGFloat(tag.depth) * 16)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(selected ? accent.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 月历热力图：每个格子是一天，颜色深浅表示当天笔记数量
struct MonthHeatmapView: View {
    @Environment(\.accent) private var accent

    let dates: [Date]
    var selectedDay: Date?
    var onSelectDay: (Date) -> Void

    @State private var month: Date = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()

    private var calendar: Calendar { Calendar.current }

    private struct Cell: Identifiable {
        let id: Int
        let date: Date?
        let count: Int
        let isToday: Bool
        let isFuture: Bool
    }

    private var counts: [Date: Int] {
        var result: [Date: Int] = [:]
        for d in dates {
            result[calendar.startOfDay(for: d), default: 0] += 1
        }
        return result
    }

    private var weekdaySymbols: [String] {
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func cells() -> [Cell] {
        let counts = self.counts
        let today = calendar.startOfDay(for: Date())
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: month)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Cell] = []
        for i in 0..<leading {
            result.append(Cell(id: -1 - i, date: nil, count: 0, isToday: false, isFuture: false))
        }
        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: month) ?? month
            result.append(Cell(id: day, date: date, count: counts[date] ?? 0,
                               isToday: date == today, isFuture: date > today))
        }
        return result
    }

    private var monthTotal: Int {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return 0 }
        return dates.filter { interval.contains($0) }.count
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private func shiftMonth(_ delta: Int) {
        if let m = calendar.date(byAdding: .month, value: delta, to: month) {
            withAnimation(.easeInOut(duration: 0.2)) { month = m }
        }
    }

    private func fill(_ count: Int) -> Color {
        switch count {
        case 0: return Color.gray.opacity(0.13)
        case 1: return accent.opacity(0.35)
        case 2...3: return accent.opacity(0.65)
        default: return accent
        }
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                Text(Fmt.monthTitle.string(from: month))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .disabled(isCurrentMonth)
                Spacer()
                Text("本月 \(monthTotal) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !isCurrentMonth {
                    Button("今天") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            month = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
                        }
                    }
                    .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(weekdaySymbols, id: \.self) { w in
                    Text(w)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(cells()) { cell in
                    dayCell(cell)
                }
            }

            HStack(spacing: 4) {
                Spacer()
                Text("少")
                ForEach([0, 1, 2, 4], id: \.self) { n in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fill(n))
                        .frame(width: 9, height: 9)
                }
                Text("多")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func numberColor(_ cell: Cell) -> Color {
        if cell.count >= 2 { return .white }
        if cell.isFuture { return Color.secondary.opacity(0.5) }
        return .secondary
    }

    @ViewBuilder
    private func dayCell(_ cell: Cell) -> some View {
        if let date = cell.date {
            let selected = selectedDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false
            Button {
                if cell.count > 0 { onSelectDay(date) }
            } label: {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(cell.isFuture ? Color.clear : fill(cell.count))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 11, weight: cell.isToday ? .bold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(numberColor(cell))
                    }
                    .overlay {
                        if cell.isToday || selected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(accent, lineWidth: selected ? 2 : 1.5)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(cell.count == 0)
            .accessibilityLabel("\(Fmt.dayTitle.string(from: date))，\(cell.count) 条笔记")
        } else {
            Color.clear.aspectRatio(1, contentMode: .fit)
        }
    }
}
