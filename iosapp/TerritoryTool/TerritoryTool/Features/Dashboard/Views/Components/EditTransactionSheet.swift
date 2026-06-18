import SwiftUI

struct EditTransactionSheet: View {
    let transactionEvent: TransactionEvent
    @Binding var isPresented: Bool
    let onComplete: () async -> Void  // Simple callback to refresh parent
    
    private let apiService: APIService = NetworkManager()
    
    @State private var selectedPerson: Person?
    @State private var selectedTerritory: Territory?
    @State private var givenDate: Date
    @State private var returnedDate: Date?
    @State private var hasInitialized = false
    @State private var isSaving = false
    
    @State private var allPersons: [Person] = []
    @State private var allTerritories: [Territory] = []
    @State private var isLoadingData = false
    
    @State private var showPersonSheet = false
    @State private var personSearchText = ""
    
    @State private var showTerritorySheet = false
    @State private var territorySearchText = ""
    @State private var showQRScanner = false
    
    var filteredPersons: [Person] {
        if personSearchText.isEmpty { return allPersons }
        return allPersons.filter { $0.name.localizedCaseInsensitiveContains(personSearchText) }
    }
    
    var filteredTerritories: [Territory] {
        if territorySearchText.isEmpty { return allTerritories }
        return allTerritories.filter { 
            $0.code.localizedCaseInsensitiveContains(territorySearchText) || 
            $0.name.localizedCaseInsensitiveContains(territorySearchText)
        }
    }
    
    init(
        transactionEvent: TransactionEvent,
        isPresented: Binding<Bool>,
        onComplete: @escaping () async -> Void
    ) {
        self.transactionEvent = transactionEvent
        self._isPresented = isPresented
        self.onComplete = onComplete
        
        // Initialize State with current values
        self._givenDate = State(initialValue: transactionEvent.transaction.givenDateUtc)
        self._returnedDate = State(initialValue: transactionEvent.transaction.pickedDateUtc)
    }
    
    private func initializeStubData() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        let tx = transactionEvent.transaction
        givenDate = tx.givenDateUtc
        returnedDate = tx.pickedDateUtc
        
        selectedPerson = Person(id: tx.personId, name: tx.personName, enabled: true, territoriesInUse: nil)
        
        selectedTerritory = Territory(
            id: tx.territoryId,
            code: "",
            name: tx.territoryName,
            mapUrl: "",
            imgUrl: nil,
            personName: nil,
            givenDateUtc: nil,
            lastPickedDateUtc: nil,
            mapGeometry: nil
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LiquidBackgroundView()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Person Selection
                        SelectionRow(
                            title: "Person",
                            value: selectedPerson?.name,
                            placeholder: "dashboard.edit_transaction.select_person",
                            icon: "person.fill",
                            action: { showPersonSheet = true }
                        )
                        
                        // Territory Selection
                        HStack(spacing: 12) {
                            SelectionRow(
                                title: "Territory",
                                value: selectedTerritory?.code.isEmpty == true ? selectedTerritory?.name : selectedTerritory?.code,
                                placeholder: "dashboard.edit_transaction.select_territory",
                                icon: "map.fill",
                                action: { showTerritorySheet = true }
                            )
                            
                            Button(action: {
                                showQRScanner = true
                            }) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.accent)
                                    .cornerRadius(12)
                                    .shadow(color: .accent.opacity(0.3), radius: 5, x: 0, y: 3)
                            }
                        }
                        
                        // Given Date
                        GlassCard(cornerRadius: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("dashboard.edit_transaction.given_date", systemImage: "arrow.right")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button {
                                        givenDate = Date()
                                    } label: {
                                        Text("common.today")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accent)
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                DatePicker("", selection: $givenDate, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .environment(\.locale, Locale.current)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        
                        // Returned Date (Optional)
                        GlassCard(cornerRadius: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("dashboard.edit_transaction.returned_date", systemImage: "arrow.uturn.left")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if returnedDate != nil {
                                        Button {
                                            returnedDate = Date()
                                        } label: {
                                            Text("common.today")
                                                .font(.caption2.bold())
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.accent)
                                                .clipShape(Capsule())
                                        }
                                        
                                        Button {
                                            returnedDate = nil
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                                .font(.headline)
                                        }
                                    } else {
                                        Button {
                                            returnedDate = Date()
                                        } label: {
                                            Text("common.add")
                                                .font(.caption2.bold())
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.accent)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                
                                if returnedDate != nil {
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { returnedDate ?? Date() },
                                            set: { returnedDate = $0 }
                                        ),
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .labelsHidden()
                                    .environment(\.locale, Locale.current)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("dashboard.edit_transaction.title_generic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button {
                            save()
                        } label: {
                            Image(systemName: "checkmark")
                                
                        }
                        .disabled(selectedPerson == nil || selectedTerritory == nil)
                    }
                }
            }
            .task {
                await loadData()
            }
            .onAppear {
                initializeStubData()
            }
            .sheet(isPresented: $showPersonSheet) {
                SearchSelectionSheet(
                    title: String.localized("dashboard.edit_transaction.select_person"),
                    searchText: $personSearchText,
                    items: filteredPersons,
                    isLoading: isLoadingData,
                    onSelect: { person in
                        selectedPerson = person
                    },
                    content: { person in
                        HStack {
                            Text(person.name)
                            Spacer()
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showTerritorySheet) {
                SearchSelectionSheet(
                    title: String.localized("dashboard.edit_transaction.select_territory"),
                    searchText: $territorySearchText,
                    items: filteredTerritories,
                    isLoading: isLoadingData,
                    onSelect: { territory in
                        selectedTerritory = territory
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
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView(isPresented: $showQRScanner) { code in
                    selectTerritory(by: code)
                }
                .ignoresSafeArea()
            }
        }
    }
    
    private func loadData() async {
        do {
            isLoadingData = true
            
            async let personsRequest: [Person] = apiService.request(endpoint: TerritoryEndpoint.getPersons(search: nil))
            async let territoriesRequest: [Territory] = apiService.request(
                endpoint: TerritoryEndpoint.getTerritories(
                    term: nil, inUse: nil, orderBy: nil, orderByAscending: nil,
                    lastGivenDateFrom: nil, lastGivenDateTo: nil
                )
            )
            
            let (persons, territories) = try await (personsRequest, territoriesRequest)
            self.allPersons = persons
            self.allTerritories = territories
            
            // Refine selection with full objects if found
            if let foundPerson = persons.first(where: { $0.id == transactionEvent.transaction.personId }) {
                self.selectedPerson = foundPerson
            }
            if let foundTerritory = territories.first(where: { $0.id == transactionEvent.transaction.territoryId }) {
                self.selectedTerritory = foundTerritory
            }
            
            isLoadingData = false
        } catch {
            print("Error loading data: \(error)")
            isLoadingData = false
        }
    }
    
    private func selectTerritory(by scannedValue: String) {
        // The scanned value is likely a Map URL, not just the code.
        // Match logic from TerritoryAssignmentViewModel
        let sanitizedScannedUrl = scannedValue.replacingOccurrences(of: "&usp=sharing", with: "")
        
        // Try to match by Map URL first
        if let territory = allTerritories.first(where: { 
            $0.mapUrl.replacingOccurrences(of: "&usp=sharing", with: "") == sanitizedScannedUrl 
        }) {
            withAnimation {
                self.selectedTerritory = territory
            }
            HapticManager.shared.notification(type: .success)
            return
        }
        
        // Fallback: Try to match by Code
        if let territory = allTerritories.first(where: { $0.code.localizedCaseInsensitiveCompare(scannedValue) == .orderedSame }) {
            withAnimation {
                self.selectedTerritory = territory
            }
            HapticManager.shared.notification(type: .success)
            return
        }
        
        // Not found
        HapticManager.shared.notification(type: .error)
        ToastManager.shared.show(
            String(format: NSLocalizedString("common.no_results", comment: ""), scannedValue),
            style: .error
        )
    }

    private func save() {
        guard let person = selectedPerson, let territory = selectedTerritory else { return }
        
        isSaving = true
        HapticManager.shared.selection()
        
        Task {
            do {
                // Create a properly configured date formatter
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                try await apiService.request(endpoint: TerritoryEndpoint.updateTransaction(
                    id: transactionEvent.transaction.id,
                    territoryId: territory.id,
                    personId: person.id,
                    date: givenDate,
                    pickedDate: returnedDate
                ))
                
                HapticManager.shared.notification(type: .success)
                ToastManager.shared.show(
                    NSLocalizedString("dashboard.edit_transaction.success", value: "Transaction updated", comment: ""),
                    style: .success
                )
                
                await onComplete()
                isPresented = false
            } catch {
                print("Error saving transaction: \(error)")
                HapticManager.shared.notification(type: .error)
                ToastManager.shared.show(
                    NSLocalizedString("common.error", comment: ""),
                    style: .error
                )
                isSaving = false
            }
        }
    }
}
