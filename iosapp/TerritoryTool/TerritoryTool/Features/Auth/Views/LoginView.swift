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
                    
                    // Username Field with Glass Style
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        TextField(LocalizedStringKey("login.username"), text: $viewModel.userName)
                            .foregroundColor(.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Password Field with Glass Style
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        SecureField(LocalizedStringKey("login.password"), text: $viewModel.password)
                            .foregroundColor(.textPrimary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.error)
                            .padding(.top, 5)
                            .multilineTextAlignment(.center)
                    }
                    
                    PrimaryButton(
                        title: LocalizedStringKey("login.button"),
                        isLoading: viewModel.isLoading,
                        action: {
                            Task {
                                await viewModel.login()
                                if viewModel.errorMessage != nil {
                                    HapticManager.shared.notification(type: .error)
                                } else {
                                    HapticManager.shared.notification(type: .success)
                                }
                            }
                        }
                    )
                    .padding(.top, 10)
                }
                .padding(30)
                .glassCardStyle(cornerRadius: 20, padding: 0)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
    }
}
