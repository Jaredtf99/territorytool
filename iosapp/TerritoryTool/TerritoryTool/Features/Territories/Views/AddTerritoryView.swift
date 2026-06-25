import SwiftUI

struct AddTerritoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddTerritoryViewModel()
    @FocusState private var focusedField: Bool
    
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
                            .foregroundColor(.error)
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
                                if await viewModel.createTerritory() {
                                    ToastManager.shared.show(
                                        NSLocalizedString("territory.add.success", value: "Territory added successfully", comment: ""),
                                        style: .success,
                                        undoHandle: viewModel.lastUndoHandle,
                                        duration: viewModel.lastUndoHandle?.toastDuration ?? 3
                                    )
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
            .navigationTitle("territory.add.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button() {
                        dismiss()
                    }label: {
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
