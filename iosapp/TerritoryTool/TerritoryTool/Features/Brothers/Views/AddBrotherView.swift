import SwiftUI

struct AddBrotherView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BrothersViewModel
    @State private var name: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                
                VStack(spacing: 20) {
                    GlassTextField(
                        placeholder: "brothers.name",
                        text: $name,
                        onSubmit: save
                    )
                    .focused($isFocused)
                    .padding(.horizontal)
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.error)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    PrimaryButton(
                        title: "brothers.save",
                        isLoading: viewModel.isLoading,
                        isDisabled: name.isEmpty,
                        action: save
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("brothers.add.title")
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
                isFocused = true
            }
        }
    }
    
    private func save() {
        guard !name.isEmpty else { return }
        HapticManager.shared.selection()
        
        Task {
            if await viewModel.addBrother(name: name) {
                HapticManager.shared.notification(type: .success)
                dismiss()
            }
        }
    }
}

