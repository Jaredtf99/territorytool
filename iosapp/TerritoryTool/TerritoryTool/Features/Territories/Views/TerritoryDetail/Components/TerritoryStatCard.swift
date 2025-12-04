import SwiftUI

struct TerritoryStatCard: View {
    enum Trend {
        case up, down, neutral
    }
    
    let title: LocalizedStringKey
    let value: String
    let comparisonValue: String?
    let description: LocalizedStringKey?
    let trend: Trend?
    let trendColor: Color
    let icon: String
    let color: Color
    
    @State private var showInfo = false
    
    init(title: LocalizedStringKey, value: String, comparisonValue: String? = nil, description: LocalizedStringKey? = nil, trend: Trend? = nil, trendColor: Color = .secondary, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.comparisonValue = comparisonValue
        self.description = description
        self.trend = trend
        self.trendColor = trendColor
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        GlassCard {
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(color)
                        .frame(width: 28, height: 28)
                        .background(color.opacity(0.2))
                        .clipShape(Circle())
                    
                    Spacer()
                    
                    if description != nil {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.trailing, 4)
                    }
                    
                    if let trend = trend {
                        Image(systemName: trend == .up ? "arrow.up.right" : (trend == .down ? "arrow.down.right" : "minus"))
                            .font(.caption2.bold())
                            .foregroundColor(trendColor)
                            .padding(4)
                            .background(trendColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    
                    if let comparison = comparisonValue {
                        Text(comparison)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .scaleEffect(0.9, anchor: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(height: 100)
        }
        .onTapGesture {
            if description != nil {
                showInfo = true
            }
        }
        .alert(title, isPresented: $showInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            if let description = description {
                Text(description)
            }
        }
    }
}
