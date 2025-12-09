import SwiftUI

struct TerritoryReturnView: View {
    @StateObject private var viewModel: TerritoryReturnViewModel
    
    init(territory: Territory? = nil) {
        _viewModel = StateObject(wrappedValue: DIContainer.shared.makeTerritoryReturnViewModel(territory: territory))
    }
    
    @State private var showTerritorySheet = false
    @State private var showQRScanner = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Territory Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("return.section.territory")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Territory Selection Row
                    HStack(spacing: 12) {
                        SelectionRow(
                            title: "return.section.territory",
                            value: viewModel.selectedTerritory.map { "\($0.code) - \($0.name)" },
                            placeholder: "return.search_territory",
                            icon: "map",
                            action: { showTerritorySheet = true },
                            onClear: viewModel.selectedTerritory != nil ? {
                                withAnimation { viewModel.selectedTerritory = nil }
                            } : nil
                        )
                        
                        Button(action: {
                            showQRScanner = true
                        }) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.green)
                                .cornerRadius(12)
                                .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // MARK: - Date Selection
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("return.custom_date", isOn: $viewModel.useCustomDate)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    
                    if viewModel.useCustomDate {
                        DatePicker("return.date", selection: $viewModel.customDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // MARK: - Action Button
                Button(action: {
                    Task {
                        _ = await viewModel.returnTerritory()
                    }
                }) {
                    HStack {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("return.button.return")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green) // Green for return/success
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(viewModel.selectedTerritory == nil || viewModel.isSubmitting)
                .opacity((viewModel.selectedTerritory == nil) ? 0.5 : 1)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding(.top)
        }
        .background {
            LiquidBackgroundView()
        }
        .navigationTitle("return.title")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTerritorySheet) {
            SearchSelectionSheet(
                title: NSLocalizedString("return.search_territory", comment: ""),
                searchText: $viewModel.territorySearchText,
                items: viewModel.assignedTerritories,
                isLoading: viewModel.isLoadingTerritories,
                onSelect: { territory in
                    withAnimation {
                        viewModel.selectedTerritory = territory
                    }
                },
                content: { territory in
                    HStack {
                        TerritoryCodeBadge(code: territory.code, fontSize: .caption)
                        Text(territory.name)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
            )
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView(isPresented: $showQRScanner) { code in
                viewModel.selectTerritory(by: code)
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Alert(title: Text("common.error"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("common.ok")))
        }
        .task {
            // Reload data when view appears
            await viewModel.loadTerritories()
        }
    }
}
