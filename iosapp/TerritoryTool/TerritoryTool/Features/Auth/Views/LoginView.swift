import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel

    init(viewModel: LoginViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            LiquidBackgroundView()

            VStack(spacing: AppSpacing.xl) {
                // Logo / Título
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "globe.europe.africa.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(Color.accent)

                    Text(verbatim: "Territory Tool")
                        .font(.appLargeTitle())
                        .foregroundStyle(.primary)
                }
                .padding(.top, 50)

                // Formulario
                VStack(spacing: AppSpacing.md) {
                    Text("login.welcome")
                        .font(.appHeadline())
                        .foregroundStyle(.secondary)

                    field(icon: "person.fill") {
                        TextField(LocalizedStringKey("login.username"), text: $viewModel.userName)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }

                    field(icon: "lock.fill") {
                        SecureField(LocalizedStringKey("login.password"), text: $viewModel.password)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.appCaption())
                            .foregroundStyle(Color.danger)
                            .multilineTextAlignment(.center)
                    }

                    PrimaryButton(
                        title: LocalizedStringKey("login.button"),
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            await viewModel.login()
                            HapticManager.shared.notification(
                                type: viewModel.errorMessage != nil ? .error : .success
                            )
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }
                .padding(AppSpacing.lg)
                .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.xl))
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }

    /// Campo de texto con icono y Liquid Glass nativo.
    @ViewBuilder
    private func field<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            content()
                .foregroundStyle(.primary)
        }
        .padding(AppSpacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.md))
    }
}
