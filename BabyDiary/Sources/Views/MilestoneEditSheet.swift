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
    @State private var pickerItem: PhotosPickerItem? = nil

    init(original: Milestone? = nil,
         onCancel: @escaping () -> Void,
         onSave: @escaping (Milestone) -> Void,
         onDelete: ((String) -> Void)? = nil) {
        self.original = original
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
        _date      = State(initialValue: original?.date ?? Date())
        _title     = State(initialValue: original?.title ?? "")
        _note      = State(initialValue: original?.note ?? "")
        _emoji     = State(initialValue: original?.emoji ?? "")
        _photoData = State(initialValue: original?.photoData)
    }

    private let emojiChoices = ["😊","🌀","💞","🦷","🍼","🚼","🎈","🌟","👣","🧸","🍰","📸"]

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: original == nil ? "新增里程碑" : "编辑里程碑",
                         onBack: onCancel)
            ScreenBody {
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            FieldLabel(text: "日期")
                            DatePicker("", selection: $date,
                                       in: ...Date().addingTimeInterval(24 * 3600),
                                       displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(store.theme.primary600)
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Palette.bg2,
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        FormField(label: "标题") {
                            TextField("例如：第一次翻身", text: $title)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            FieldLabel(text: "备注（可选）")
                            TextField("当时的场景、心情…", text: $note, axis: .vertical)
                                .lineLimit(2...4)
                                .padding(.horizontal, 16).padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Palette.bg2,
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            FieldLabel(text: "图标")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    emojiChip("")
                                    ForEach(emojiChoices, id: \.self) { emojiChip($0) }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            FieldLabel(text: "照片（可选）")
                            PhotosPicker(selection: $pickerItem,
                                         matching: .images,
                                         photoLibrary: .shared()) {
                                photoPreview
                            }
                            if photoData != nil {
                                Button {
                                    photoData = nil
                                    pickerItem = nil
                                } label: {
                                    Text("移除照片")
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundStyle(Palette.ink2)
                                }
                            }
                        }
                    }
                }

                CTAButton(title: "保存",
                          variant: canSave ? .primary : .ghost,
                          theme: store.theme,
                          action: save)
                    .padding(.top, 18)
                    .disabled(!canSave)

                if let id = original?.id, let onDelete {
                    Button {
                        onDelete(id)
                    } label: {
                        Text("删除这条里程碑")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color(hex: 0xFF7F64))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 4)
                }

                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(PressableStyle())
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
    }

    private func emojiChip(_ e: String) -> some View {
        let on = emoji == e
        return Button {
            emoji = e
        } label: {
            Group {
                if e.isEmpty {
                    Text("无")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(on ? .white : Palette.ink2)
                } else {
                    Text(e).font(.system(size: 20))
                }
            }
            .frame(width: 40, height: 40)
            .background(on ? store.theme.primary : Palette.bg2,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let data = photoData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            HStack(spacing: 8) {
                AppIcon.Plus(size: 16, color: Palette.ink2)
                Text("选择照片")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Palette.bg2,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalEmoji = emoji.isEmpty ? nil : emoji
        if var m = original {
            m.date = date
            m.title = t
            m.note = trimmedNote.isEmpty ? nil : trimmedNote
            m.emoji = finalEmoji
            m.photoData = photoData
            onSave(m)
        } else {
            onSave(Milestone.new(
                title: t, date: date,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                emoji: finalEmoji, photoData: photoData
            ))
        }
    }
}
