import SwiftUI
import UniformTypeIdentifiers

struct BackupScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    @State private var jsonURL: URL?
    @State private var pdfURL: URL?
    @State private var showImporter = false
    @State private var confirmImport: URL?
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "数据备份", onBack: onBack)
            ScreenBody {
                safetyOverview
                    .padding(.top, 4)

                dataOverview
                    .padding(.top, 22)

                exportSection
                    .padding(.top, 22)

                restoreSection
                    .padding(.top, 22)

                if let message {
                    statusMessage(message)
                        .padding(.top, 12)
                }
            }
        }
        .background(Palette.bg)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { confirmImport = url }
            case .failure(let error):
                message = "选择文件失败：\(error.localizedDescription)"
            }
        }
        .alert(
            "确定覆盖当前数据？",
            isPresented: Binding(
                get: { confirmImport != nil },
                set: { if !$0 { confirmImport = nil } }
            )
        ) {
            Button("取消", role: .cancel) {}
            Button("覆盖并恢复", role: .destructive) {
                if let url = confirmImport { performImport(url) }
            }
        } message: {
            Text("当前所有日常记录、成长、疫苗、用药和辅食数据都会被备份文件替换。")
        }
    }

    private var safetyOverview: some View {
        Card(padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Palette.mintTint)
                    AppIcon.Shield(size: 27, color: Palette.mint600, fill: .white.opacity(0.4))
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 6) {
                    Text("自动保存已开启")
                        .appFont(size: 17, weight: .black)
                        .tracking(-0.18)
                        .foregroundStyle(Palette.ink)
                    Text(lastSavedText)
                        .appFont(size: 12, weight: .bold)
                        .foregroundStyle(Palette.mint600)
                    Text("本机数据会随每次修改保存；换机或卸载前仍建议导出完整备份。")
                        .appFont(size: 13, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var dataOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("当前数据")

            Card(padding: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        stat("\(store.events.count)", "记录")
                        verticalDivider
                        stat("\(store.growth.count)", "成长点")
                        verticalDivider
                        stat("\(store.vaccines.filter(\.done).count)/\(store.vaccines.count)", "疫苗")
                    }
                    .padding(.vertical, 16)

                    Rectangle().fill(Palette.line).frame(height: 1)

                    HStack(spacing: 0) {
                        stat("\(store.medications.count)", "用药")
                        verticalDivider
                        stat("\(store.foods.count)", "食材")
                        verticalDivider
                        stat("\(store.recipes.count)", "食谱")
                    }
                    .padding(.vertical, 16)
                }
            }
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("导出数据")

            Card(padding: 0) {
                VStack(spacing: 0) {
                    exportRow(
                        format: "JSON",
                        title: "完整数据备份",
                        subtitle: "用于换机、重装或再次导入恢复",
                        tint: store.theme.primaryTint,
                        ink: store.theme.primary600,
                        url: jsonURL,
                        generate: generateJSON
                    )

                    Rectangle()
                        .fill(Palette.line)
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    exportRow(
                        format: "PDF",
                        title: "可阅读报告",
                        subtitle: "方便查看、打印或发送给家人医生",
                        tint: Palette.blue,
                        ink: Palette.blueInk,
                        url: pdfURL,
                        generate: generatePDF
                    )
                }
            }
        }
    }

    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("恢复数据")

            Card(padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("从 JSON 备份恢复")
                            .appFont(size: 15, weight: .heavy)
                            .foregroundStyle(Palette.ink)
                        Text("恢复会覆盖当前设备上的全部数据。选择文件后仍需再次确认。")
                            .appFont(size: 13, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button { showImporter = true } label: {
                        Text("选择备份文件")
                            .appFont(size: 14, weight: .heavy)
                            .foregroundStyle(Palette.pinkInk)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                Palette.pink,
                                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                            )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func exportRow(
        format: String,
        title: String,
        subtitle: String,
        tint: Color,
        ink: Color,
        url: URL?,
        generate: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(format)
                .appFont(size: 10, weight: .black)
                .tracking(0.3)
                .foregroundStyle(ink)
                .frame(width: 48, height: 42)
                .background(tint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(size: 14, weight: .heavy)
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .appFont(size: 11, weight: .semibold)
                    .foregroundStyle(Palette.ink3)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let url {
                ShareLink(item: url) {
                    Text("分享")
                        .appFont(size: 13, weight: .heavy)
                        .foregroundStyle(ink)
                        .frame(minWidth: 58, minHeight: 44)
                        .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                Button(action: generate) {
                    Text("生成")
                        .appFont(size: 13, weight: .heavy)
                        .foregroundStyle(ink)
                        .frame(minWidth: 58, minHeight: 44)
                        .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func statusMessage(_ message: String) -> some View {
        let failed = message.contains("失败")
        return Text(message)
            .appFont(size: 13, weight: .semibold)
            .foregroundStyle(failed ? Palette.pinkInk : Palette.mint600)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 14)
            .background(
                failed ? Palette.pink : Palette.mintTint,
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(width: 1, height: 34)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .appFont(size: 19, weight: .black)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
            Text(label)
                .appFont(size: 11, weight: .bold)
                .foregroundStyle(Palette.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .appFont(size: 15, weight: .heavy)
            .tracking(-0.15)
            .foregroundStyle(Palette.ink)
    }

    private var lastSavedText: String {
        if let savedAt = store.lastSavedAt() {
            return "最近保存：\(formatAutosaveTime(savedAt))"
        }
        return "最近保存：尚未生成本机保存文件"
    }

    private func formatAutosaveTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日 HH:mm"
        return formatter.string(from: date)
    }

    private func generateJSON() {
        do {
            jsonURL = try store.exportJSON()
            message = "完整备份已生成，可以分享保存"
        } catch {
            message = "生成备份失败：\(error.localizedDescription)"
        }
    }

    private func generatePDF() {
        do {
            pdfURL = try store.exportPDF()
            message = "PDF 报告已生成，可以分享保存"
        } catch {
            message = "生成 PDF 失败：\(error.localizedDescription)"
        }
    }

    private func performImport(_ url: URL) {
        do {
            try store.importJSON(from: url)
            message = "数据恢复完成"
            jsonURL = nil
            pdfURL = nil
        } catch {
            message = "恢复失败：\(error.localizedDescription)"
        }
        confirmImport = nil
    }
}
