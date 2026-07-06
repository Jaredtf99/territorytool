import SwiftUI
import PDFKit

struct TerritoryReportView: View {
    @StateObject private var viewModel: TerritoryReportViewModel

    init(viewModel: TerritoryReportViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? DIContainer.shared.makeTerritoryReportViewModel())
    }

    var body: some View {
        Form {
            Section(
                header: Text("reports.date_range"),
                footer: Text("reports.description")
            ) {
                DatePicker(
                    "reports.start_date",
                    selection: $viewModel.startDate,
                    in: ...viewModel.endDate,
                    displayedComponents: .date
                )
                DatePicker(
                    "reports.end_date",
                    selection: $viewModel.endDate,
                    displayedComponents: .date
                )
            }

            Section {
                Button {
                    Task { await viewModel.generate() }
                } label: {
                    HStack {
                        if viewModel.isGenerating {
                            ProgressView()
                                .padding(.trailing, 6)
                            Text("reports.generating")
                        } else {
                            Label("reports.generate", systemImage: "doc.richtext")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(viewModel.isGenerating || !viewModel.isRangeValid)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.warning)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("reports.title")
        .scrollContentBackground(.hidden)
        .background {
            LiquidBackgroundView()
        }
        .sheet(item: $viewModel.generatedReport) { report in
            ReportPreviewSheet(url: report.url)
        }
    }
}

/// Previsualización del PDF generado con opción de compartir.
private struct ReportPreviewSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFDocumentView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("reports.title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        ShareLink(item: url) {
                            Label("reports.share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

private struct PDFDocumentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.pageShadowsEnabled = true
        view.backgroundColor = UIColor(rgb: 0xE7DECB)
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

#Preview {
    NavigationStack {
        TerritoryReportView(viewModel: TerritoryReportViewModel(apiService: MockAPIService()))
    }
}
