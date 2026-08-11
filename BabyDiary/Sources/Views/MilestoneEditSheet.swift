import SwiftUI
import PhotosUI

// Add / edit a milestone entry. Nil `original` = new entry.
struct MilestoneEditSheet: View {
    let original: Milestone?
    let onCancel: () -> Void
    let onSave: (Milestone) -> Void
    let onDelete: ((String) -> Void)?

    @Environment(AppStore.self) private var store

    @State private var date: Date
    @State private var title: String
    @State private var note: String
    @State private var emoji: String
    @State private var photoData: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showMarkerPicker: Bool
    @State private var showDeleteConfirm = false

    init(original: Milestone? = nil,
         onCancel: @escaping () -> Void,
         onSave: @escaping (Milestone) -> Void,
         onDelete: ((String) -> Void)? = nil) {
        self.original = original
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
        _date = State(initialValue: original?.date ?? Date())
        _title = State(initialValue: original?.title ?? "")
        _note = State(initialValue: original?.note ?? "")
        _emoji = State(initialValue: original?.emoji ?? "")
        _photoData = State(initialValue: original?.photoData)
        _pickerItem = State(initialValue: nil)
        _showMarkerPicker = State(initialValue: original?.emoji != nil)
    }

    // 11 marks + “none” make a balanced 4 × 3 grid.
    private let emojiChoices = ["😊", "🌀", "💞", "🦷", "🍼", "🚼", "🎈", "🌟", "👣", "🧸", "🍰"]

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var calculatedAgeMonths: Double {
        store.ageMonths(on: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: original == nil ? "新增里程碑" : "编辑里程碑",
                         onBack: onCancel)
            ScreenBody {
                introCard

                sectionLabel("里程碑内容")
                    .padding(.top, 24)
                contentCard

                sectionLabel("发生时间")
                    .padding(.top, 24)
                dateCard

                sectionLabel("照片")
                    .padding(.top, 24)
                photoCard

                sectionLabel("小标记")
                    .padding(.top, 24)
                markerCard

                CTAButton(title: "保存",
                          variant: canSave ? .primary : .ghost,
                          theme: store.theme,
                          action: save)
                    .padding(.top, 24)
                    .disabled(!canSave)

                Button(action: onCancel) {
                    Text("取消")
                        .appFont(size: 15, weight: .semibold)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                }
                .buttonStyle(PressableStyle())

                if original != nil, onDelete != nil {
                    dangerZone
                        .padding(.top, 24)
                }
            }
        }
        .background(Palette.bg)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
        .alert("删除这条里程碑？", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                guard let id = original?.id else { return }
                onDelete?(id)
            }
        } message: {
            Text("删除后无法恢复。")
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            MicroLabel(text: original == nil ? "新里程碑" : "当前记录")
            Text(original?.title ?? "记录一个重要时刻")
                .appFont(size: 20, weight: .bold)
                .tracking(-0.3)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
            Text(original == nil
                 ? "写下宝宝第一次做到的事"
                 : "修改后会同步更新成长时间线")
                .appFont(size: 13, weight: .semibold)
                .foregroundStyle(Palette.ink3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.yellow.opacity(0.62),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.yellowInk.opacity(0.08), lineWidth: 1)
        }
    }

    private var contentCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "标题")
                    TextField("例如：第一次翻身", text: $title)
                        .appFont(size: 16, weight: .semibold)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .background(Palette.bg2,
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "备注（可选）")
                    TextField("当时的场景、心情…", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                        .appFont(size: 16, weight: .semibold)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                        .background(Palette.bg2,
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            }
        }
    }

    private var dateCard: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("日期")
                            .appFont(size: 15, weight: .bold)
                            .foregroundStyle(Palette.ink)
                        Text("选择发生的那一天")
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 8)
                    DatePicker("",
                               selection: $date,
                               in: ...Date().addingTimeInterval(24 * 3600),
                               displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(store.theme.primary600)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .accessibilityLabel("里程碑日期")
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 72)

                Divider()
                    .overlay(Palette.line)
                    .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("宝宝月龄")
                            .appFont(size: 15, weight: .bold)
                            .foregroundStyle(Palette.ink)
                        Text("根据出生日期自动计算")
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 8)
                    Text(milestoneAgeLabel(calculatedAgeMonths))
                        .appFont(size: 14, weight: .bold)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(Palette.bg2, in: Capsule())
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 72)
            }
        }
    }

    private var photoCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                PhotosPicker(selection: $pickerItem,
                             matching: .images,
                             photoLibrary: .shared()) {
                    photoPreview
                }
                .buttonStyle(PressableStyle())

                if photoData != nil {
                    Button {
                        photoData = nil
                        pickerItem = nil
                    } label: {
                        Text("移除照片")
                            .appFont(size: 13, weight: .bold)
                            .foregroundStyle(Palette.ink2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var markerCard: some View {
        Card {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showMarkerPicker.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("装饰标记（可选）")
                                .appFont(size: 15, weight: .bold)
                                .foregroundStyle(Palette.ink)
                            Text(emoji.isEmpty ? "当前未选择" : "当前选择 \(emoji)")
                                .appFont(size: 12, weight: .semibold)
                                .foregroundStyle(Palette.ink3)
                        }
                        Spacer(minLength: 8)
                        Text(showMarkerPicker ? "收起" : "选择")
                            .appFont(size: 13, weight: .bold)
                            .foregroundStyle(Palette.ink2)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(Palette.bg2, in: Capsule())
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityValue(showMarkerPicker ? "已展开" : "已收起")

                if showMarkerPicker {
                    Divider()
                        .overlay(Palette.line)
                        .padding(.vertical, 14)

                    LazyVGrid(columns: markerColumns, spacing: 10) {
                        emojiChip("")
                        ForEach(emojiChoices, id: \.self) { emojiChip($0) }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var markerColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    }

    private func emojiChip(_ value: String) -> some View {
        let selected = emoji == value
        return Button {
            emoji = value
        } label: {
            Group {
                if value.isEmpty {
                    Text("无")
                        .appFont(size: 13, weight: .bold)
                        .foregroundStyle(selected ? Palette.yellowInk : Palette.ink2)
                } else {
                    Text(value)
                        .appFont(size: 21)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(selected ? Palette.yellow : Palette.bg2,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Palette.yellowInk.opacity(0.18) : Palette.line,
                            lineWidth: 1)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(value.isEmpty ? "不使用标记" : "选择标记 \(value)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let data = photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityLabel("已选择的里程碑照片")
        } else {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("添加一张照片")
                        .appFont(size: 15, weight: .bold)
                        .foregroundStyle(Palette.ink)
                    Text("可选，之后也能补充")
                        .appFont(size: 12, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 8)
                Text("选择")
                    .appFont(size: 13, weight: .bold)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 38)
                    .background(Palette.card, in: Capsule())
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(Palette.bg2,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            MicroLabel(text: "删除记录")
            Button { showDeleteConfirm = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("删除这条里程碑")
                            .appFont(size: 15, weight: .bold)
                            .foregroundStyle(Palette.pinkInk)
                        Text("删除后无法恢复")
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 12)
                    Text("删除")
                        .appFont(size: 13, weight: .bold)
                        .foregroundStyle(Palette.pinkInk)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Palette.pink, in: Capsule())
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 68)
                .background(Palette.card,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.pink.opacity(0.8), lineWidth: 1)
                }
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .appFont(size: 16, weight: .bold)
            .tracking(-0.16)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalEmoji = emoji.isEmpty ? nil : emoji

        if var milestone = original {
            milestone.date = date
            milestone.ageMonths = calculatedAgeMonths
            milestone.title = trimmedTitle
            milestone.note = trimmedNote.isEmpty ? nil : trimmedNote
            milestone.emoji = finalEmoji
            milestone.photoData = photoData
            onSave(milestone)
        } else {
            onSave(Milestone.new(
                title: trimmedTitle,
                date: date,
                ageMonths: calculatedAgeMonths,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                emoji: finalEmoji,
                photoData: photoData
            ))
        }
    }
}
