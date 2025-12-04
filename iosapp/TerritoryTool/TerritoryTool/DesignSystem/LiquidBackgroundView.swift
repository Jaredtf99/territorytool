import SwiftUI

struct LiquidBackgroundView: View {
    @State private var animate = true
    
    var body: some View {
        ZStack {
            // Base Background
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            // Animated Blobs
            ZStack {
                // Blob 1: Top Left - Brand Primary
                Circle()
                    .fill(Color.brandPrimary.opacity(0.4))
                    .frame(width: 350, height: 350)
                    .blur(radius: 60)
                    .offset(x: animate ? -50 : 0, y: animate ? -50 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animate)
            
                
                // Blob 2: Bottom Right - Brand Secondary
                Circle()
                    .fill(Color.brandSecondary.opacity(0.4))
                    .frame(width: 350, height: 350)
                    .blur(radius: 60)
                    .offset(x: animate ? 50 : 0, y: animate ? 50 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animate)
                
                // Blob 3: Center/Bottom Left - Mix
                Circle()
                    .fill(Color.brandPrimary.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 50)
                    .offset(x: animate ? -30 : 30, y: animate ? -100 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: animate)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                // Subtle gradient overlay to blend everything
                LinearGradient(colors: [.clear, .background.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        .ignoresSafeArea()
        .onAppear {
            animate = true
        }
    }
}

#Preview {
    LiquidBackgroundView()
}
