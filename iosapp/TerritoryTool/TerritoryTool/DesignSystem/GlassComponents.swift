import SwiftUI

struct GlassBackground: View {
    var body: some View {
        ZStack {
            // Dynamic background
            LinearGradient(
                gradient: Gradient(colors: [.gradientStart, .gradientEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Abstract shapes for depth
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -100)
                .blur(radius: 50)
            
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 400, height: 400)
                .offset(x: 150, y: 200)
                .blur(radius: 60)
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 20
    
    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(
                ZStack {
                    // Glass effect
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
                    // Subtle gradient border/glow
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassCardStyle(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

struct GlassButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appBody())
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.interactiveSpring(), value: configuration.isPressed)
    }
}
