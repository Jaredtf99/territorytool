import SwiftUI

struct BrotherRowView: View {
    let person: Person
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    if let territories = person.territoriesInUse, !territories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(territories, id: \.territoryCode) { territory in
                                HStack {
                                    Text(territory.territoryCode)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .frame(width: 40, alignment: .leading)
                                        .contentTransition(.identity)
                                    
                                    Text(territory.territoryName)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Text(territory.givenDate, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.secondaryBackground)
                                .cornerRadius(4)
                            }
                        }
                        .padding(.top, 4)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }
                },
                label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name)
                                .font(.headline)
                                .foregroundColor(person.enabled ? .textPrimary : .textSecondary)
                                .strikethrough(!person.enabled)
                        }
                        
                        Spacer()
                        
                        if let territories = person.territoriesInUse, !territories.isEmpty {
                            HStack(spacing: 4) {
                                Text("\(territories.count)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
                            }
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, AppSpacing.xxs)
                            .background(Color.accent.opacity(0.12), in: .rect(cornerRadius: AppRadius.sm))
                            .foregroundColor(.primary) // Reset color to avoid picking up accentColor(.clear)
                        }
                    }
                    .padding()
                    .contentShape(Rectangle()) // Make the whole area tappable
                }
            )
            .disclosureGroupStyle(HiddenChevronDisclosureGroupStyle())
        }
        .glassCardStyle(cornerRadius: 12, padding: 0)
        .contentShape(Rectangle())
    }
}

struct HiddenChevronDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation {
                    configuration.isExpanded.toggle()
                }
            } label: {
                configuration.label
            }
            .buttonStyle(.plain)
            
            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}

