import SwiftUI

struct TerritoryReturnView: View {
    @StateObject private var viewModel: TerritoryReturnViewModel
    private let onSuccess: (() -> Void)?
    
    init(territory: Territory? = nil, onSuccess: (() -> Void)? = nil) {
        self.onSuccess = onSuccess
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
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.accentSecondary, in: .rect(cornerRadius: AppRadius.md))
                        }
                        .accessibilityLabel(Text("return.search_territory"))
                    }
                    .padding(.horizontal)
                }
                
                // MARK: - Date Selection
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("return.custom_date", isOn: $viewModel.useCustomDate)
                        .tint(.accent)
                        .padding(AppSpacing.md)
                        .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.md))
                        .padding(.horizontal)

                    if viewModel.useCustomDate {
                        DatePicker("return.date", selection: $viewModel.customDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .tint(.accent)
                            .padding(AppSpacing.md)
                            .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.md))
                            .padding(.horizontal)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // MARK: - Action Button
                Button(action: {
                    Task {
                        if await viewModel.returnTerritory() {
                            onSuccess?()
                        }
                    }
                }) {
                    HStack(spacing: AppSpacing.xs) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("return.button.return")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.glassProminent)
                .tint(.accentSecondary)
                .controlSize(.large)
                .disabled(viewModel.selectedTerritory == nil || viewModel.isSubmitting)
                .padding(.horizontal)
                .padding(.bottom, AppSpacing.xl)
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
                        Text(territory.code)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 50, alignment: .leading)
                        Text(territory.name)
                        Spacer()
                    }
                }
            )
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView(isPresented: $showQRScanner) { code in
                viewModel.selectTerritory(by: code)
            }
            .ignoresSafeArea()
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
