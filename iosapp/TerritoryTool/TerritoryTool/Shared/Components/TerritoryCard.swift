import SwiftUI

struct TerritoryCard: View {
    let territory: Territory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Header
            ZStack(alignment: .topLeading) {
                if let imgUrl = territory.imgUrl, let url = URL(string: imgUrl) {
                    CachedAsyncImage(
                        url: url,
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        },
                        placeholder: {
                            Color.secondary.opacity(0.1)
                                .overlay(
                                    ProgressView()
                                        .tint(.white)
                                )
                        },
                        errorView: {
                            Color.secondary.opacity(0.1)
                                .overlay(
                                    Image(systemName: "map.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary.opacity(0.3))
                                )
                        }
                    )
                    .frame(height: 140)
                    .clipped()
                } else {
                    Color.secondary.opacity(0.1)
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "map.fill")
                                .font(.largeTitle)
                                .foregroundColor(.secondary.opacity(0.3))
                        )
                }
                
                // Code Badge Overlay
                TerritoryCodeBadge(code: territory.code)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .padding(12)
            }
            
            // Content Section
            VStack(alignment: .leading, spacing: 12) {
                // Name and Status Row
                HStack(alignment: .top, spacing: 8) {
                    Text(territory.name)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    // Status Badge
                    if let person = territory.personName {
                        PersonBadge(personName: person)
                    } else {
                        StatusBadge(isAssigned: false)
                    }
                }
                
                Divider()
                    .background(Color.primary.opacity(0.1))
                
                // Footer: Dates
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label {
                            Text("dashboard.last_assigned")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if let date = territory.givenDateUtc {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.primary)
                        } else {
                            Text("-")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Spacer()
                    
                    if let date = territory.givenDateUtc {
                        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption2)
                            Text(String(format: String.localized("dashboard.days_ago"), days))
                                .font(.caption.weight(.bold))
                        }
                        .foregroundColor(days > 120 ? .red : (days > 90 ? .orange : .secondary))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (days > 120 ? Color.red : (days > 90 ? Color.orange : Color.secondary))
                                .opacity(0.1)
                        )
                        .cornerRadius(8)
                    }
                }
            }
            .padding(12)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
