import SwiftUI

// Edit an existing growth measurement. Date cannot be set in the future.
struct GrowthEditSheet: View {
    let original: GrowthPoint
    let onCancel: () -> Void
    let onSave: (GrowthPoint) -> Void

    @Environment(AppStore.self) private var store
    @State private var date: Date
    @State private var weight: String
    @State private var height: String

    init(point: GrowthPoint,
         onCancel: @escaping () -> Void,
         onSave: @escaping (GrowthPoint) -> Void) {
        self.original = point
        self.onCancel = onCancel
        self.onSave = onSave
        _date = State(initialValue: point.date)
        _weight = State(initialValue: String(format: "%.1f", point.weightKg))
        _height = State(initialValue: String(format: "%.1f", point.heightCm))
    }

    private var trimmedWeight: Double? {
        Double(weight.trimmingCharacters(in: .whitespaces))
    }
    private var trimmedHeight: Double? {
        Double(height.trimmingCharacters(in: .whitespaces))
    }

    private var dateInFuture: Bool {
        date > Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 3600)
    }

    private var canSave: Bool {
        guard let w = trimmedWeight, w > 0, let h = trimmedHeight, h > 0 else { return false }
        return !dateInFuture
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "编辑测量", onBack: onCancel)
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
                        HStack(spacing: 10) {
                            FormField(label: "体重 (kg)") {
                                TextField("0.0", text: $weight)
                                    .keyboardType(.decimalPad)
                            }
                            FormField(label: "身高 (cm)") {
                                TextField("0.0", text: $height)
                                    .keyboardType(.decimalPad)
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
    }

    private func save() {
        guard let w = trimmedWeight, let h = trimmedHeight, !dateInFuture else { return }
        var g = original
        g.date = date
        g.ageMonths = store.ageMonths(on: date)
        g.weightKg = w
        g.heightCm = h
        onSave(g)
    }
}
