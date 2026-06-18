import SwiftUI
import Combine

@MainActor
final class CongregationsManagementViewModel: ObservableObject {
    @Published var congregations: [CongregationSummary] = []
    @Published var isLoading = false

    private let auth = SupabaseAuthService.shared
    private let store = CongregationStore.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }
        await store.refresh()
        congregations = store.congregations
    }

    func create(name: String) async throws {
        try await auth.createCongregation(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        await load()
    }

    func rename(id: String, name: String) async throws {
        try await auth.renameCongregation(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        await load()
    }

    func delete(id: String) async throws {
        try await auth.deleteCongregation(id: id)
        await load()
    }
}

struct CongregationsManagementView: View {
    @StateObject private var viewModel = CongregationsManagementViewModel()

    @State private var newName = ""
    @State private var renameTarget: CongregationSummary?
    @State private var renameText = ""
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        Form {
            Section(header: Text("congregations.new")) {
                HStack {
                    TextField("congregations.name_placeholder", text: $newName)
                    Button {
                        create()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section(header: Text("congregations.title")) {
                if viewModel.congregations.isEmpty {
                    Text("congregations.empty").foregroundColor(.secondary)
                }
                ForEach(viewModel.congregations) { congregation in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(congregation.name)
                            if congregation.isActive {
                                Text("congregations.active").font(.caption).foregroundColor(.success)
                            }
                        }
                        Spacer()
                        Button {
                            renameTarget = congregation
                            renameText = congregation.name
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(congregation)
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("congregations.title")
        .scrollContentBackground(.hidden)
        .background { LiquidBackgroundView() }
        .task { await viewModel.load() }
        .overlay {
            if viewModel.isLoading { ProgressView() }
        }
        .alert("congregations.rename", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("congregations.name_placeholder", text: $renameText)
            Button("common.cancel", role: .cancel) { renameTarget = nil }
            Button("common.save") { rename() }
        }
        .alert("common.error", isPresented: $showError) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func create() {
        let name = newName
        Task {
            do {
                try await viewModel.create(name: name)
                newName = ""
            } catch {
                present(error)
            }
        }
    }

    private func rename() {
        guard let target = renameTarget else { return }
        let name = renameText
        renameTarget = nil
        Task {
            do { try await viewModel.rename(id: target.id, name: name) }
            catch { present(error) }
        }
    }

    private func delete(_ congregation: CongregationSummary) {
        Task {
            do { try await viewModel.delete(id: congregation.id) }
            catch { present(error) }
        }
    }

    private func present(_ error: Error) {
        let raw = error.localizedDescription
        if raw.contains("CONGREGATION_ALREADY_EXISTS") {
            errorMessage = NSLocalizedString("congregations.error_exists", comment: "")
        } else if raw.contains("CONGREGATION_NOT_EMPTY") {
            errorMessage = NSLocalizedString("congregations.error_not_empty", comment: "")
        } else {
            errorMessage = raw
        }
        showError = true
    }
}
