import SwiftUI

struct EditTerritoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditTerritoryViewModel
    @FocusState private var focusedField: Bool
    
    private let onSuccess: (() -> Void)?
    
    init(territory: TerritoryDetail, apiService: APIService, onSuccess: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: EditTerritoryViewModel(territory: territory, apiService: apiService))
        self.onSuccess = onSuccess
    }
    
    init(territory: Territory, apiService: APIService, onSuccess: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: EditTerritoryViewModel(territory: territory, apiService: apiService))
        self.onSuccess = onSuccess
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        GlassTextField(
                            placeholder: "territory.code",
                            text: $viewModel.code,
                            label: LocalizedStringKey(NSLocalizedString("territory.code", comment: "") + " *")
                        )
                        .focused($focusedField)
                        
                        GlassTextField(
                            placeholder: "territory.name",
                            text: $viewModel.name,
                            label: LocalizedStringKey(NSLocalizedString("territory.name", comment: "") + " *")
                        )
                        
                        GlassTextField(
                            placeholder: "territory.mapUrl",
                            text: $viewModel.mapUrl,
                            label: LocalizedStringKey(NSLocalizedString("territory.mapUrl", comment: "") + " *")
                        )
                    }
                    .padding(.horizontal)
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red) // Should use app error color if available, but red is standard.
                            .font(.caption)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    PrimaryButton(
                        title: "common.save",
                        isLoading: viewModel.isLoading,
                        isDisabled: viewModel.name.isEmpty || viewModel.code.isEmpty || viewModel.mapUrl.isEmpty,
                        action: {
                            Task {
                                if await viewModel.save() {
                                    ToastManager.shared.show(NSLocalizedString("territory.edit.success", comment: ""), style: .success)
                                    HapticManager.shared.notification(type: .success)
                                    onSuccess?()
                                    dismiss()
                                } else {
                                    HapticManager.shared.notification(type: .error)
                                }
                            }
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("territory.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "multiply")
                    }
                }
            }
            .onAppear {
                focusedField = true
            }
        }
    }
}
