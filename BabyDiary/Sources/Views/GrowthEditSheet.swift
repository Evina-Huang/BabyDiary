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
        let cal = Calendar.current
        return cal.startOfDay(for: date) > cal.startOfDay(for: Date())
    }

    private var weightInvalid: Bool {
        !weight.trimmingCharacters(in: .whitespaces).isEmpty && (trimmedWeight ?? 0) <= 0
    }

    private var heightInvalid: Bool {
        !height.trimmingCharacters(in: .whitespaces).isEmpty && (trimmedHeight ?? 0) <= 0
    }

    private var canSave: Bool {
        guard let w = trimmedWeight, w > 0, let h = trimmedHeight, h > 0 else { return false }
        return !dateInFuture
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "编辑测量", onBack: onCancel)
            ScreenBody {
                originalSummary

                sectionLabel("测量日期")
                    .padding(.top, 24)
                dateCard

                sectionLabel("测量数据")
                    .padding(.top, 24)
                measurementCard

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
            }
        }
        .background(Palette.bg)
    }

    private var originalSummary: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .fill(Palette.blue)
                .frame(width: 54, height: 54)
                .overlay {
                    AppIcon.Growth(size: 27, color: Palette.blueInk)
                }

            VStack(alignment: .leading, spacing: 4) {
                MicroLabel(text: "当前记录")
                Text(formatDateLabel(original.date))
                    .appFont(size: 16, weight: .bold)
                    .foregroundStyle(Palette.ink)
                Text("测量时约 \(ageLabel(original.ageMonths))")
                    .appFont(size: 12, weight: .semibold)
                    .foregroundStyle(Palette.ink3)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f kg", original.weightKg))
                    .foregroundStyle(Palette.pinkInk)
                Text(String(format: "%.1f cm", original.heightCm))
                    .foregroundStyle(Palette.blueInk)
            }
            .appFont(size: 15, weight: .bold)
            .monospacedDigit()
        }
        .padding(16)
        .background(Palette.card,
                    in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        }
        .shadowCard()
    }

    private var dateCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "日期")
                HStack(spacing: 12) {
                    Text("选择日期")
                        .appFont(size: 15, weight: .bold)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    DatePicker("",
                               selection: $date,
                               in: ...Date(),
                               displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(store.theme.primary600)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .accessibilityLabel("测量日期")
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(Palette.bg2,
                            in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            }
        }
    }

    private var measurementCard: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                measurementField(label: "体重",
                                 helper: "公斤",
                                 value: $weight,
                                 unit: "kg",
                                 tint: Palette.pink,
                                 ink: Palette.pinkInk,
                                 invalid: weightInvalid)
                    .padding(16)

                Divider()
                    .overlay(Palette.line)
                    .padding(.horizontal, 16)

                measurementField(label: "身高",
                                 helper: "厘米",
                                 value: $height,
                                 unit: "cm",
                                 tint: Palette.blue,
                                 ink: Palette.blueInk,
                                 invalid: heightInvalid)
                    .padding(16)
            }
        }
    }

    private func measurementField(label: String,
                                  helper: String,
                                  value: Binding<String>,
                                  unit: String,
                                  tint: Color,
                                  ink: Color,
                                  invalid: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .appFont(size: 16, weight: .bold)
                        .foregroundStyle(Palette.ink)
                    Text(helper)
                        .appFont(size: 12, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                }

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0.0", text: value)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .appText(.statValue)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .frame(width: 104)
                        .accessibilityLabel(label)

                    Text(unit)
                        .appFont(size: 13, weight: .bold)
                        .foregroundStyle(ink)
                        .frame(width: 26, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 72)
            .background(tint.opacity(0.68),
                        in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

            if invalid {
                Text("请输入大于 0 的数值")
                    .appFont(size: 12, weight: .semibold)
                    .foregroundStyle(Palette.pinkInk)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .appFont(size: 16, weight: .bold)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
    }

    private func ageLabel(_ months: Double) -> String {
        if months < 1 {
            return "\(max(0, Int((months * 30).rounded()))) 天"
        }
        let wholeMonths = Int(months)
        let days = Int(((months - Double(wholeMonths)) * 30).rounded())
        return days > 0 ? "\(wholeMonths) 个月 \(days) 天" : "\(wholeMonths) 个月"
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
