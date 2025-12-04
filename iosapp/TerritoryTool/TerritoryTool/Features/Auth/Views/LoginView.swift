import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    
    init(viewModel: LoginViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            LiquidBackgroundView()
            
            VStack(spacing: 30) {
                // Logo / Title
                VStack(spacing: 10) {
                    Image(systemName: "globe.europe.africa.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.brandPrimary)
                        .shadow(color: .brandPrimary.opacity(0.3), radius: 10)
                    
                    Text("Territory Tool")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.textPrimary)
                }
                .padding(.top, 50)
                
                // Login Form
                VStack(spacing: 20) {
                    Text("login.welcome")
                        .font(.headline)
                        .foregroundColor(.textSecondary)
                    
                    CustomTextField(icon: "person.fill", placeholder: String(localized: "login.username"), text: $viewModel.userName)
                    
                    CustomSecureField(icon: "lock.fill", placeholder: String(localized: "login.password"), text: $viewModel.password)
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.error)
                            .padding(.top, 5)
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.login()
                            if viewModel.errorMessage != nil {
                                HapticManager.shared.notification(type: .error)
                            } else {
                                HapticManager.shared.notification(type: .success)
                            }
                        }
                    }) {
                        Text(viewModel.isLoading ? "login.logging_in" : "login.button")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandPrimary)
                            .cornerRadius(10)
                    }
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.7 : 1)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
    }
}

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(10)
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            SecureField(placeholder, text: $text)
                .foregroundColor(.textPrimary)
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(10)
    }
}
