import SwiftUI

struct ActionLogsView: View {
    @StateObject private var viewModel = DIContainer.shared.makeActionLogsViewModel()
    
    var body: some View {
        ZStack {
            // "Liquid" Background
            LiquidBackgroundView()
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.logs.isEmpty {
                ProgressView("common.loading")
                    .tint(.white)
                    .foregroundColor(.white)
            } else if viewModel.logs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    Text("actionlogs.empty")
                        .font(.title3.weight(.medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                List {
                    ForEach(viewModel.logs) { log in
                        ActionLogGlassRow(log: log)
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentItem: log)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.white)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await viewModel.loadLogs(reset: true)
                }
            }
        }
        .navigationTitle("actionlogs.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadLogs(reset: true)
        }
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Alert(
                title: Text("common.error"),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text("common.ok"))
            )
        }
    }
}

struct ActionLogGlassRow: View {
    let log: ActionLog
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(colorForType(log.type).opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconForType(log.type))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(colorForType(log.type))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Action Title (Derived from Type roughly or Message)
                    Text(friendlyActionName(log.type))
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                    
                    // User | Date
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(log.userName ?? "common.unknown")
                            .font(.caption.weight(.medium))
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text(log.dateUtc, style: .relative)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Indicator
                if !log.successful {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.warning)
                        .font(.caption)
                }
            }
            
            // Expandable Message Area
            if let message = log.message, !message.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                        .lineLimit(isExpanded ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Show "Show more" hint if not expanded and text is long (heuristic)
                    if !isExpanded && message.count > 50 {
                        Text("common.see_more") // Ensure this string exists or use generic arrow
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.accentColor)
                            .padding(.top, 2)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.03))
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func friendlyActionName(_ type: ActionType) -> String {
       switch type {
       case .addTerritory: return NSLocalizedString("actionlogs.type.add_territory", comment: "")
       case .editTerritory: return NSLocalizedString("actionlogs.type.edit_territory", comment: "")
       case .deleteTerritory: return NSLocalizedString("actionlogs.type.delete_territory", comment: "")
       case .addUser: return NSLocalizedString("actionlogs.type.add_user", comment: "")
       case .deleteUser: return NSLocalizedString("actionlogs.type.delete_user", comment: "")
       case .changeUserPassword: return NSLocalizedString("actionlogs.type.change_password", comment: "")
       case .editUser: return NSLocalizedString("actionlogs.type.edit_user", comment: "")
       case .addPerson: return NSLocalizedString("actionlogs.type.add_person", comment: "")
       case .editPerson: return NSLocalizedString("actionlogs.type.edit_person", comment: "")
       case .deletePerson: return NSLocalizedString("actionlogs.type.delete_person", comment: "")
       case .giveTerritory: return NSLocalizedString("actionlogs.type.give_territory", comment: "")
       case .pickTerritory: return NSLocalizedString("actionlogs.type.pick_territory", comment: "")
       case .refreshTerritoryImage: return NSLocalizedString("actionlogs.type.refresh_image", comment: "")
       case .editTransaction: return NSLocalizedString("actionlogs.type.edit_transaction", comment: "")
       case .deleteTransaction: return NSLocalizedString("actionlogs.type.delete_transaction", comment: "")
       case .unknown: return NSLocalizedString("actionlogs.type.unknown", comment: "")
       }
    }
    
    private func iconForType(_ type: ActionType) -> String {
        switch type {
        // Territories
        case .addTerritory: return "map.fill"
        case .editTerritory: return "map.fill"
        case .deleteTerritory: return "map.fill"
        case .giveTerritory: return "person.badge.plus"
        case .pickTerritory: return "tray.and.arrow.down.fill"
        case .refreshTerritoryImage: return "arrow.clockwise"
        
        // Users
        case .addUser: return "person.crop.circle.badge.plus"
        case .editUser: return "person.crop.circle"
        case .deleteUser: return "person.crop.circle.badge.minus"
        case .changeUserPassword: return "key.fill"
        
        // Brothers/Persons
        case .addPerson: return "person.3.fill"
        case .editPerson: return "person.3.fill"
        case .deletePerson: return "person.3.fill"
        
        // Transactions
        case .editTransaction: return "arrow.left.arrow.right"
        case .deleteTransaction: return "arrow.left.arrow.right"
        
        case .unknown: return "gear"
        }
    }
    
    private func colorForType(_ type: ActionType) -> Color {
        switch type {
        // Add actions = Success (green)
        case .addTerritory, .addPerson, .addUser:
            return .success
        
        // Edit actions = Warning (orange)
        case .editTerritory, .editPerson, .editUser, .changeUserPassword, .refreshTerritoryImage, .editTransaction:
            return .warning
        
        // Delete actions = Error (red)
        case .deleteTerritory, .deletePerson, .deleteUser, .deleteTransaction:
            return .error
        
        // Territory flow actions = Brand colors
        case .giveTerritory:
            return .brandPrimary
        case .pickTerritory:
            return .brandSecondary
        
        case .unknown:
            return .secondary
        }
    }
}
