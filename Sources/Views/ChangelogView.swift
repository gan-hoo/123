import SwiftUI

struct ChangelogView: View {
    @Environment(\.accent) private var accent

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        List {
            ForEach(Changelog.entries) { entry in
                Section {
                    ForEach(entry.items, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle()
                                .fill(accent)
                                .frame(width: 6, height: 6)
                                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 4 }
                            Text(item)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text("v\(entry.version)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(entry.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if entry.version == currentVersion {
                            Text("当前")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accent, in: Capsule())
                        }
                        Spacer()
                        Text(entry.date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .textCase(nil)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("更新日志")
        .navigationBarTitleDisplayMode(.inline)
    }
}
