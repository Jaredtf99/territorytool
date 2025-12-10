import SwiftUI

struct AddEditUserView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: UsersViewModel
    
    enum Mode {
        case add
        case edit(User)
        
        var title: String {
            switch self {
            case .add: return "users.add_title"
            case .edit: return "users.edit_title"
            }
        }
        
        var buttonTitle: String {
            switch self {
            case .add: return "common.create"
            case .edit: return "common.save"
            }
        }
    }
    
    let mode: Mode
    
    @State private var userName: String = ""
    @State private var role: UserRole = .user
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case username
        case password
        case confirmPassword
    }
    
    // Validation
    var isValid: Bool {
        if userName.isEmpty { return false }
        
        // Password validation
        if !password.isEmpty {
            if password != confirmPassword { return false }
            if password.count < 4 { return false } // Basic length check
        }
        
        switch mode {
        case .add:
            return !password.isEmpty && !confirmPassword.isEmpty
        case .edit:
            return true
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Error Message
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }
                        
                        // MARK: - User Info Section
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(title: "users.section_info")
                            
                            VStack(spacing: 16) {
                                GlassTextField(placeholder: "users.username", text: $userName)
                                    .focused($focusedField, equals: .username)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                                
                                // Role Picker - Custom Segment Style directly in list
                                if !viewModel.availableRolesForAssignment().isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("users.role")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 4)
                                        
                                        HStack(spacing: 12) {
                                            ForEach(viewModel.availableRolesForAssignment(), id: \.self) { roleOption in
                                                Button {
                                                    withAnimation {
                                                        role = roleOption
                                                    }
                                                } label: {
                                                    HStack {
                                                        Text(roleOption.rawValue)
                                                            .fontWeight(role == roleOption ? .bold : .regular)
                                                    }
                                                    .foregroundColor(role == roleOption ? .white : .primary)
                                                    .padding(.vertical, 12)
                                                    .padding(.horizontal, 16)
                                                    .frame(maxWidth: .infinity)
                                                    .background(
                                                        role == roleOption ? Color.accentColor : Color.clear
                                                    )
                                                    .cornerRadius(12)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.secondary.opacity(0.3), lineWidth: role == roleOption ? 0 : 1)
                                                    )
                                                }
                                            }
                                        }
                                        .padding(4)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(16)
                                    }
                                }
                            }
                            .padding()
                            .glassCardStyle(cornerRadius: 20, padding: 0)
                        }
                        
                        // MARK: - Security Section
                        VStack(alignment: .leading, spacing: 12) {
                            if shouldShowSecuritySection {
                                sectionHeader(title: "users.section_security")
                                
                                VStack(spacing: 16) {
                                    if case .edit = mode {
                                        Text("users.new_password_optional")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    
                                    SecureField("users.password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .confirmPassword }
                                        .textFieldStyle(.plain)
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                    
                                    if !password.isEmpty {
                                        SecureField("users.confirm_password", text: $confirmPassword)
                                            .focused($focusedField, equals: .confirmPassword)
                                            .submitLabel(.done)
                                            .onSubmit { if isValid { save() } }
                                            .textFieldStyle(.plain)
                                            .padding()
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        password == confirmPassword ? Color.green.opacity(0.5) : Color.red.opacity(0.5),
                                                        lineWidth: 1
                                                    )
                                            )
                                        
                                        if !confirmPassword.isEmpty && password != confirmPassword {
                                            Text("users.passwords_do_not_match")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                                .padding()
                                .glassCardStyle(cornerRadius: 20, padding: 0)
                            }
                        }
                        
                        // Action Button
                        PrimaryButton(title: LocalizedStringKey(mode.buttonTitle), isLoading: viewModel.isLoading, action: save)
                            .disabled(!isValid)
                            .opacity(isValid ? 1 : 0.6)
                            .padding(.top, 10)
                        
                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationTitle(LocalizedStringKey(mode.title))
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
                if case .edit(let user) = mode {
                    userName = user.userName
                    role = user.role
                } else {
                    focusedField = .username
                }
            }
        }
    }
    
    private var shouldShowSecuritySection: Bool {
        switch mode {
        case .add: return true
        case .edit(let user): return viewModel.canChangePassword(for: user)
        }
    }
    
    private func sectionHeader(title: String) -> some View {
        Text(LocalizedStringKey(title))
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 8)
    }
    
    private func save() {
        Task {
            let success: Bool
            switch mode {
            case .add:
                success = await viewModel.addUser(name: userName, role: role, password: password)
            case .edit(let user):
                // Update basic info
                let updateSuccess = await viewModel.updateUser(user: user, newName: userName, newRole: role)
                
                // If password provided, update it too
                var passwordSuccess = true
                if !password.isEmpty {
                    passwordSuccess = await viewModel.changePassword(for: user, newPassword: password)
                }
                
                success = updateSuccess && passwordSuccess
            }
            
            if success {
                dismiss()
            }
        }
    }
}
