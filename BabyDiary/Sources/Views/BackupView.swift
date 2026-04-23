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
                summaryCard
                    .padding(.top, 10)

                autosaveCard
                    .padding(.top, 12)

                Card(padding: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionLabel("导出 / 备份")
                        Text("自动保存用于日常使用，导出用于换机、重装前或额外留底。建议在大版本更新前导出一次。")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.ink2)

                        exportJSONRow
                        exportPDFRow
                    }
                }
                .padding(.top, 12)

                Card(padding: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionLabel("恢复 / 导入")
                        Text("从之前导出的 JSON 备份中恢复数据。导入会覆盖当前所有内容。")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.ink2)

                        Button {
                            showImporter = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("从 JSON 文件导入").font(.system(size: 14, weight: .semibold))
                                Spacer()
                            }
                            .padding(.vertical, 12).padding(.horizontal, 14)
                            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(Palette.ink)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.top, 12)

                if let msg = message {
                    Text(msg)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
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
            case .failure(let err):
                message = "选择文件失败：\(err.localizedDescription)"
            }
        }
        .alert("确定要导入吗？", isPresented: Binding(
            get: { confirmImport != nil },
            set: { if !$0 { confirmImport = nil } }
        )) {
            Button("取消", role: .cancel) {}
            Button("覆盖当前数据", role: .destructive) {
                if let url = confirmImport { performImport(url) }
            }
        } message: {
            Text("当前所有日常记录、成长、疫苗、用药和辅食数据将被备份文件中的内容覆盖。")
        }
    }

    // MARK: — Rows

    private var exportJSONRow: some View {
        HStack(spacing: 10) {
            rowIcon("doc.text", tint: .blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("导出 JSON 备份").font(.system(size: 14, weight: .semibold))
                Text("完整数据，可再次导入恢复")
                    .font(.system(size: 11)).foregroundStyle(Palette.ink3)
            }
            Spacer()
            if let url = jsonURL {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(store.theme.primary600)
                }
            } else {
                Button("生成") { generateJSON() }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(store.theme.primary600)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14))
    }

    private var exportPDFRow: some View {
        HStack(spacing: 10) {
            rowIcon("doc.richtext", tint: .red)
            VStack(alignment: .leading, spacing: 2) {
                Text("导出 PDF 报告").font(.system(size: 14, weight: .semibold))
                Text("直观易读，可直接打开查看")
                    .font(.system(size: 11)).foregroundStyle(Palette.ink3)
            }
            Spacer()
            if let url = pdfURL {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(store.theme.primary600)
                }
            } else {
                Button("生成") { generatePDF() }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(store.theme.primary600)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14))
    }

    private var summaryCard: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("当前数据")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 10) {
                    stat("\(store.events.count)", "记录")
                    stat("\(store.growth.count)", "成长点")
                    stat("\(store.vaccines.filter { $0.done }.count)/\(store.vaccines.count)", "疫苗")
                    stat("\(store.medications.count)", "用药")
                    stat("\(store.foods.count)", "辅食")
                }
            }
        }
    }

    private var autosaveCard: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("自动保存")

                HStack(alignment: .top, spacing: 10) {
                    rowIcon("checkmark.shield", tint: Palette.mint600)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("自动保存已开启")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.ink)

                        Text("每次新增、修改、删除后，都会立即保存到当前设备。")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.ink2)

                        Text(lastSavedText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(store.theme.primary600)

                        Text("自动保存文件保存在 App 的本地空间里，不会直接出现在「文件」App。若担心卸载或换机，请导出 JSON 备份。")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var lastSavedText: String {
        if let savedAt = store.lastSavedAt() {
            return "最近保存：\(formatAutosaveTime(savedAt))"
        }
        return "最近保存：尚未生成本机保存文件"
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 20, weight: .black)).foregroundStyle(Palette.ink)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6).textCase(.uppercase)
            .foregroundStyle(Palette.ink3)
    }

    private func rowIcon(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func formatAutosaveTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月 d 日 HH:mm"
        return f.string(from: date)
    }

    // MARK: — Actions

    private func generateJSON() {
        do {
            jsonURL = try store.exportJSON()
            message = "JSON 已生成，点击右侧分享"
        } catch {
            message = "导出 JSON 失败：\(error.localizedDescription)"
        }
    }

    private func generatePDF() {
        do {
            pdfURL = try store.exportPDF()
            message = "PDF 已生成，点击右侧分享"
        } catch {
            message = "导出 PDF 失败：\(error.localizedDescription)"
        }
    }

    private func performImport(_ url: URL) {
        do {
            try store.importJSON(from: url)
            message = "导入成功 ✓"
            jsonURL = nil; pdfURL = nil
        } catch {
            message = "导入失败：\(error.localizedDescription)"
        }
        confirmImport = nil
    }
}
