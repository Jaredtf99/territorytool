import SwiftUI

struct EditBrotherView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BrothersViewModel
    let person: Person
    
    @State private var name: String
    @State private var isEnabled: Bool
    @FocusState private var isFocused: Bool
    
    init(viewModel: BrothersViewModel, person: Person) {
        self.viewModel = viewModel
        self.person = person
        _name = State(initialValue: person.name)
        _isEnabled = State(initialValue: person.enabled)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        GlassTextField(
                            placeholder: "brothers.name",
                            text: $name,
                            label: "brothers.name",
                            onSubmit: save
                        )
                        .focused($isFocused)
                        
                        GlassToggle(
                            label: "brothers.enabled",
                            isOn: $isEnabled
                        )
                    }
                    .padding(.horizontal)
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.error)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    PrimaryButton(
                        title: "brothers.save",
                        isLoading: viewModel.isLoading,
                        isDisabled: name.isEmpty,
                        action: save
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("brothers.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
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
            if await viewModel.updateBrother(person: person, newName: name, enabled: isEnabled) {
                HapticManager.shared.notification(type: .success)
                dismiss()
            }
        }
    }
}

