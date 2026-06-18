import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var isValid: Bool {
        newPassword.count >= 4 && newPassword == confirmPassword
    }

    var body: some View {
        Form {
            Section(header: Text("change_password.new")) {
                SecureField("change_password.new_placeholder", text: $newPassword)
                SecureField("change_password.confirm_placeholder", text: $confirmPassword)
            }

            if !newPassword.isEmpty && newPassword != confirmPassword {
                Text("change_password.mismatch")
                    .font(.caption)
                    .foregroundColor(.danger)
            }

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView() } else { Text("change_password.save") }
                        Spacer()
                    }
                }
                .disabled(!isValid || isSaving)
            }
        }
        .navigationTitle("change_password.title")
        .scrollContentBackground(.hidden)
        .background { LiquidBackgroundView() }
        .alert("common.error", isPresented: $showError) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await SupabaseAuthService.shared.changeOwnPassword(newPassword: newPassword)
                ToastManager.shared.show("change_password.success", style: .success)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
