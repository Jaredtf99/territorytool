import SwiftUI

struct TerritoryAssignmentView: View {
    @StateObject private var viewModel: TerritoryAssignmentViewModel
    
    init(territory: Territory? = nil) {
        _viewModel = StateObject(wrappedValue: DIContainer.shared.makeTerritoryAssignmentViewModel(territory: territory))
    }
    
    @State private var showTerritorySheet = false
    @State private var showPersonSheet = false
    @State private var showQRScanner = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Territory Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("assignment.section.territory")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Territory Selection Row
                    HStack(spacing: 12) {
                        SelectionRow(
                            title: "assignment.section.territory",
                            value: viewModel.selectedTerritory.map { "\($0.code) - \($0.name)" },
                            placeholder: "assignment.search_territory",
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
                                .background(Color.blue)
                                .cornerRadius(12)
                                .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Suggestions
                    if viewModel.selectedTerritory == nil && !viewModel.suggestedTerritories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("assignment.suggestions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.suggestedTerritories) { territory in
                                        CompactTerritoryCard(territory: territory)
                                            .onTapGesture {
                                                withAnimation {
                                                    viewModel.selectSuggestion(territory)
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                // MARK: - Publisher Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("assignment.section.publisher")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Publisher Selection Row
                    SelectionRow(
                        title: "assignment.section.publisher",
                        value: viewModel.selectedPerson?.name,
                        placeholder: "assignment.search_publisher",
                        icon: "person",
                        action: { showPersonSheet = true },
                        onClear: viewModel.selectedPerson != nil ? {
                            withAnimation { viewModel.selectedPerson = nil }
                        } : nil
                    )
                    .padding(.horizontal)
                }
                
                // MARK: - Date Selection
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("assignment.custom_date", isOn: $viewModel.useCustomDate)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    
                    if viewModel.useCustomDate {
                        DatePicker("assignment.date", selection: $viewModel.customDate, displayedComponents: [.date, .hourAndMinute])
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
                        _ = await viewModel.assignTerritory()
                    }
                }) {
                    HStack {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("assignment.button.assign")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(viewModel.selectedTerritory == nil || viewModel.selectedPerson == nil || viewModel.isSubmitting)
                .opacity((viewModel.selectedTerritory == nil || viewModel.selectedPerson == nil) ? 0.5 : 1)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding(.top)
        }
        .background {
            LiquidBackgroundView()
        }
        .navigationTitle("assignment.title")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTerritorySheet) {
            SearchSelectionSheet(
                title: NSLocalizedString("assignment.search_territory", comment: ""),
                searchText: $viewModel.territorySearchText,
                items: viewModel.availableTerritories,
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
        .sheet(isPresented: $showPersonSheet) {
            SearchSelectionSheet(
                title: NSLocalizedString("assignment.search_publisher", comment: ""),
                searchText: $viewModel.personSearchText,
                items: viewModel.persons,
                isLoading: viewModel.isLoadingPersons,
                onSelect: { person in
                    withAnimation {
                        viewModel.selectedPerson = person
                    }
                },
                content: { person in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        Text(person.name)
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
            await viewModel.loadSuggestions()
            await viewModel.loadPersons()
        }
    }
}
