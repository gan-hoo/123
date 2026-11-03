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

    private var usedDays: Int {
        guard let first = memos.first?.createdAt else { return 0 }
        let cal = Calendar.current
        let d = cal.dateComponents([.day], from: cal.startOfDay(for: first), to: cal.startOfDay(for: Date())).day ?? 0
        return d + 1
    }

    var body: some View {
        let tags = tagCounts
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image("Logo")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text("拾念")
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
                }
                .padding(.horizontal, 8)

                HeatmapView(dates: memos.map(\.createdAt))

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

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
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

struct HeatmapView: View {
    @Environment(\.accent) private var accent
    let dates: [Date]
    var weeks = 14

    private struct Cell: Hashable {
        let date: Date
        let count: Int
        let isFuture: Bool
    }

    private func grid() -> [[Cell]] {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        for d in dates {
            counts[cal.startOfDay(for: d), default: 0] += 1
        }
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) // 1 = 周日
        let thisWeekStart = cal.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
        let start = cal.date(byAdding: .day, value: -7 * (weeks - 1), to: thisWeekStart) ?? today
        var columns: [[Cell]] = []
        for w in 0..<weeks {
            var col: [Cell] = []
            for d in 0..<7 {
                let day = cal.date(byAdding: .day, value: w * 7 + d, to: start) ?? today
                col.append(Cell(date: day, count: counts[day] ?? 0, isFuture: day > today))
            }
            columns.append(col)
        }
        return columns
    }

    private func color(for cell: Cell) -> Color {
        if cell.isFuture { return .clear }
        switch cell.count {
        case 0: return Color.gray.opacity(0.15)
        case 1: return accent.opacity(0.35)
        case 2...3: return accent.opacity(0.65)
        default: return accent
        }
    }

    var body: some View {
        let columns = grid()
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                ForEach(columns.indices, id: \.self) { w in
                    VStack(spacing: 3) {
                        ForEach(columns[w], id: \.self) { cell in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(color(for: cell))
                                .frame(width: 15, height: 15)
                        }
                    }
                }
            }
            HStack(spacing: 4) {
                Text("最近 \(weeks) 周")
                Spacer()
                Text("少")
                ForEach([0, 1, 2, 4], id: \.self) { n in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: Cell(date: Date(), count: n, isFuture: false)))
                        .frame(width: 9, height: 9)
                }
                Text("多")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
