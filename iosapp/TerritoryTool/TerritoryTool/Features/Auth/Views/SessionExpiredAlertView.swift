import SwiftUI

struct SessionExpiredAlertView: View {
    let onLogout: () -> Void
    
    @State private var isVisible = false
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            // Full Screen Background
            LiquidBackgroundView()
                .ignoresSafeArea()
            
            // Alert Card
            VStack(spacing: 20) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange, .primary)
                    .symbolEffect(.bounce, value: isVisible)
                
                Text(String(localized: "session.expired.title"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(String(localized: "session.expired.message"))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                Button(action: onLogout) {
                    Text(String(localized: "logout.title"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 10)
            }
            .padding(30)
            .background(.regularMaterial)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(40)
            .scaleEffect(scale)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
                scale = 1.0
            }
        }
    }
}

#Preview {
    SessionExpiredAlertView(onLogout: {})
}
