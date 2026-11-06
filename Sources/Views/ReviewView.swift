import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.accent) private var accent
    @Query(filter: #Predicate<Memo> { $0.trashedAt == nil })
    private var memos: [Memo]

    @State private var picks: [Memo] = []
    @State private var page = 0
    @Environment(EditorPresenter.self) private var editor

    private var onThisDay: [Memo] {
        let cal = Calendar.current
        let now = Date()
        let md = cal.dateComponents([.month, .day, .year], from: now)
        return memos.filter {
            let c = cal.dateComponents([.month, .day, .year], from: $0.createdAt)
            return c.month == md.month && c.day == md.day && (c.year ?? 0) < (md.year ?? 0)
        }
    }

    var body: some View {
        Group {
            if memos.isEmpty {
                ContentUnavailableView("还没有笔记",
                                       systemImage: "sparkles",
                                       description: Text("记录一些想法后，再回来回顾吧"))
            } else {
                TabView(selection: $page) {
                    ForEach(Array(picks.enumerated()), id: \.offset) { index, memo in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(Fmt.relative(memo.createdAt))
                                    .font(.headline)
                                    .foregroundStyle(accent)
                                MemoCard(memo: memo, alwaysExpanded: true,
                                         onEdit: { editor.open(memo: memo) },
                                         onOpen: { editor.open(memo: memo, editing: false) })
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 60)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
        .background(Color(.systemGroupedBackground))
        .roundBackButton()
        .navigationTitle("每日回顾")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                RoundIconButton(systemName: "shuffle") {
                    withAnimation { shuffle() }
                }
                .accessibilityLabel("换一批")
                .disabled(memos.isEmpty)
            }
        }
        .onAppear {
            if picks.isEmpty { shuffle() }
        }
    }

    private func shuffle() {
        page = 0
        let otd = onThisDay
        let otdIDs = Set(otd.map(\.persistentModelID))
        let rest = memos.filter { !otdIDs.contains($0.persistentModelID) }.shuffled()
        picks = Array((otd + rest).prefix(10))
    }
}
