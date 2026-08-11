import SwiftUI

struct MedicationScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store
    @State private var showAdd = false
    @State private var editing: MedicationRecord? = nil

    private var records: [MedicationRecord] {
        store.medications.sorted { $0.takenAt > $1.takenAt }
    }

    private var allergic: [MedicationRecord] {
        records.filter { $0.reaction == .allergic }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "用药记录", onBack: onBack)
            ScreenBody {
                allergySummary
                    .padding(.top, 4)

                addButton
                    .padding(.top, 14)

                recordsBlock
                    .padding(.top, 22)
            }
        }
        .background(Palette.bg)
        .sheet(isPresented: $showAdd) {
            MedicationEditSheet(record: nil, onClose: { showAdd = false })
                .environment(store)
                .presentationDetents([.large])
        }
        .sheet(item: $editing) { record in
            MedicationEditSheet(record: record, onClose: { editing = nil })
                .environment(store)
                .presentationDetents([.large])
        }
    }

    private var allergySummary: some View {
        return Card(padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .fill(allergic.isEmpty ? Palette.mintTint : Palette.pink)
                    AppIcon.Pill(
                        size: 26,
                        color: allergic.isEmpty ? Palette.mint600 : Palette.pinkInk
                    )
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 6) {
                    Text(allergic.isEmpty ? "暂无药物过敏记录" : "疑似药物过敏 \(allergic.count) 项")
                        .appText(.cardTitle)
                        .foregroundStyle(Palette.ink)

                    if allergic.isEmpty {
                        Text("新增用药后可标记观察中、无异常或疑似过敏。")
                            .appFont(size: 13, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(allergic.prefix(3)) { record in
                                Text(allergyLine(record))
                                    .appFont(size: 13, weight: .semibold)
                                    .foregroundStyle(Palette.pinkInk)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var addButton: some View {
        Button { showAdd = true } label: {
            HStack(spacing: 8) {
                AppIcon.Plus(size: 18, color: .white)
                Text("新增用药记录")
                    .appFont(size: 15, weight: .heavy)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(store.theme.primary,
                        in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
            .shadowPill(tint: store.theme.primary600)
        }
        .buttonStyle(PressableStyle())
    }

    private var recordsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近用药")
                    .appFont(size: 15, weight: .heavy)
                Spacer()
                Text("\(records.count) 条")
                    .appFont(size: 12, weight: .bold)
                    .foregroundStyle(Palette.ink3)
            }

            if records.isEmpty {
                EmptyStateView(
                    title: "还没有用药记录",
                    subtitle: "记录药名、剂量和反应，复诊时更容易说明情况"
                )
            } else {
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(records.enumerated()), id: \.element.id) { i, record in
                            MedicationRow(
                                record: record,
                                last: i == records.count - 1,
                                onTap: { editing = record }
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
    }

    private func allergyLine(_ record: MedicationRecord) -> String {
        let note = record.reactionNote?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let note, !note.isEmpty {
            return "\(record.name) · \(note)"
        }
        return record.name
    }
}

private struct MedicationRow: View {
    let record: MedicationRecord
    let last: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.name)
                            .appFont(size: 15, weight: .heavy)
                            .foregroundStyle(Palette.ink)
                        Text(detailLine)
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Text(record.reaction.label)
                        .appFont(size: 11, weight: .heavy)
                        .foregroundStyle(reactionStyle.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(reactionStyle.tint, in: Capsule())

                    AppIcon.Chevron(size: 14, color: Palette.ink3)
                }
                .frame(minHeight: 68)

                if !last {
                    Rectangle().fill(Palette.line).frame(height: 1)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var detailLine: String {
        var parts = [medicationDateTime(record.takenAt)]
        if !record.dose.isEmpty { parts.append(record.dose) }
        if !record.reason.isEmpty { parts.append(record.reason) }
        if let note = record.reactionNote, !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: " · ")
    }

    private var reactionStyle: (tint: Color, ink: Color) {
        style(for: record.reaction)
    }
}

private struct MedicationEditSheet: View {
    let record: MedicationRecord?
    let onClose: () -> Void
    @Environment(AppStore.self) private var store
    @State private var name: String
    @State private var takenAt: Date
    @State private var dose: String
    @State private var reason: String
    @State private var reaction: MedicationReaction
    @State private var reactionNote: String
    @State private var note: String
    @State private var showNote: Bool
    @State private var showDeleteConfirm = false

    init(record: MedicationRecord?, onClose: @escaping () -> Void) {
        self.record = record
        self.onClose = onClose
        self._name = State(initialValue: record?.name ?? "")
        self._takenAt = State(initialValue: record?.takenAt ?? Date())
        self._dose = State(initialValue: record?.dose ?? "")
        self._reason = State(initialValue: record?.reason ?? "")
        self._reaction = State(initialValue: record?.reaction ?? .observing)
        self._reactionNote = State(initialValue: record?.reactionNote ?? "")
        self._note = State(initialValue: record?.note ?? "")
        self._showNote = State(initialValue: !(record?.note ?? "").isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: record == nil ? "新增用药" : "编辑用药", onBack: onClose)
            ScreenBody {
                VStack(spacing: 18) {
                    Card(padding: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("用药信息")
                                    .appFont(size: 17, weight: .bold)
                                    .foregroundStyle(Palette.ink)
                                Text("填写药名、剂量和服用时间")
                                    .appFont(size: 12, weight: .medium)
                                    .foregroundStyle(Palette.ink3)
                            }

                            FormField(label: "药名") {
                                TextField("例如：对乙酰氨基酚", text: $name)
                            }

                            FormField(label: "剂量") {
                                TextField("例如：2.5 ml / 半包 / 1 粒", text: $dose)
                            }

                            FormField(label: "用途") {
                                TextField("例如：发热、咳嗽、医生开具", text: $reason)
                            }

                            InlineWheelTimePicker(time: $takenAt, theme: store.theme, label: "用药时间")
                        }
                    }

                    Card(padding: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("反应观察")
                                    .appFont(size: 17, weight: .bold)
                                    .foregroundStyle(Palette.ink)
                                Text("服药后可继续更新状态")
                                    .appFont(size: 12, weight: .medium)
                                    .foregroundStyle(Palette.ink3)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                FieldLabel(text: "当前状态")
                                SegPill(selection: $reaction, options: [
                                    (.observing, "观察中"),
                                    (.none, "无异常"),
                                    (.allergic, "疑似过敏"),
                                ])
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }

                            if reaction != .none {
                                FormField(label: reaction == .allergic ? "异常表现" : "观察记录（可选）") {
                                    TextField("例如：皮疹、腹泻、呕吐、嗜睡", text: $reactionNote)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }

                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showNote.toggle()
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    AppIcon.Plus(size: 18, color: store.theme.primary600)
                                        .rotationEffect(.degrees(showNote ? 45 : 0))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("补充备注")
                                            .appFont(size: 14, weight: .bold)
                                            .foregroundStyle(Palette.ink)
                                        Text("服用要求、是否停药等，可选")
                                            .appFont(size: 11, weight: .medium)
                                            .foregroundStyle(Palette.ink3)
                                    }
                                    Spacer(minLength: 0)
                                    Text(showNote ? "收起" : "填写")
                                        .appFont(size: 12, weight: .bold)
                                        .foregroundStyle(store.theme.primary600)
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityValue(showNote ? "已展开" : "已收起")

                            if showNote {
                                TextField("例如：饭后服用、已停用", text: $note, axis: .vertical)
                                    .lineLimit(2...4)
                                    .appFont(size: 16, weight: .semibold)
                                    .foregroundStyle(Palette.ink)
                                    .padding(14)
                                    .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 16)
                                    .transition(.opacity)
                            }
                        }
                    }

                    CTAButton(title: record == nil ? "保存用药记录" : "保存修改", theme: store.theme) {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if record != nil {
                        Button { showDeleteConfirm = true } label: {
                            Text("删除此用药记录")
                                .appFont(size: 14, weight: .heavy)
                                .foregroundStyle(Palette.pinkInk)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Palette.pink, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.top, 6)
            }
        }
        .background(Palette.bg)
        .alert("确定删除这条用药记录吗？", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let record {
                    store.deleteMedication(record.id)
                    onClose()
                }
            }
        } message: {
            Text("删除后这条记录将不可恢复。")
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = MedicationRecord(
            id: record?.id ?? "md_" + UUID().uuidString.prefix(6).lowercased(),
            name: trimmedName,
            takenAt: takenAt,
            dose: dose.trimmingCharacters(in: .whitespacesAndNewlines),
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            reaction: reaction,
            reactionNote: cleanOptional(reactionNote),
            note: cleanOptional(note)
        )

        if record == nil {
            store.addMedication(updated)
        } else {
            store.updateMedication(updated)
        }
        onClose()
    }

    private func cleanOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private func style(for reaction: MedicationReaction) -> (tint: Color, ink: Color) {
    switch reaction {
    case .observing:
        return (Palette.yellow, Palette.yellowInk)
    case .none:
        return (Palette.mintTint, Palette.mint600)
    case .allergic:
        return (Palette.pink, Palette.pinkInk)
    }
}

private func medicationDateTime(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "M月d日 HH:mm"
    return f.string(from: date)
}

#Preview("用药") {
    MedicationScreen(onBack: {})
        .environment(AppStore.preview)
}
