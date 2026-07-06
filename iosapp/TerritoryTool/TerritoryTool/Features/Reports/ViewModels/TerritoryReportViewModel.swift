import Foundation
import Combine

@MainActor
final class TerritoryReportViewModel: ObservableObject {

    struct GeneratedReport: Identifiable {
        let id = UUID()
        let url: URL
    }

    @Published var startDate: Date
    @Published var endDate: Date = Date()
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var generatedReport: GeneratedReport?

    private let apiService: APIService

    init(apiService: APIService) {
        self.apiService = apiService
        self.startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    }

    var isRangeValid: Bool {
        Calendar.current.startOfDay(for: startDate) <= endDate
    }

    func generate() async {
        guard !isGenerating else { return }
        errorMessage = nil

        guard isRangeValid else {
            errorMessage = NSLocalizedString("reports.error.invalid_range", comment: "")
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        // El rango cubre los días completos elegidos.
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: endDate)) ?? endDate

        do {
            let entries: [TerritoryReportEntry] = try await apiService.request(
                endpoint: TerritoryEndpoint.getTerritoryReport(start: start, end: end)
            )
            guard !entries.isEmpty else {
                errorMessage = NSLocalizedString("reports.error.empty", comment: "")
                return
            }

            let reportData = TerritoryReportData(
                entries: entries,
                startDate: start,
                endDate: end,
                congregationName: activeCongregationName()
            )

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let fileName = "TerritoryReport_\(formatter.string(from: start))_\(formatter.string(from: end)).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            try TerritoryReportPDFBuilder(data: reportData).writePDF(to: url)
            generatedReport = GeneratedReport(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func activeCongregationName() -> String? {
        guard let data = TokenManager.shared.getCongregationsData(),
              let congregations = try? JSONDecoder().decode([CongregationSummary].self, from: data) else {
            return nil
        }
        if let activeId = TokenManager.shared.getActiveCongregationId(),
           let active = congregations.first(where: { $0.id == activeId }) {
            return active.name
        }
        return congregations.first(where: \.isActive)?.name
    }
}
