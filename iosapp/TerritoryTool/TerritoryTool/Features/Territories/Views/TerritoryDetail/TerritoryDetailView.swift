import SwiftUI

/// Detalle de territorio, tema "Cartográfico cálido": cabecera con la silueta
/// del territorio, tarjeta del ciclo actual con dial, acciones en cristal,
/// trayectoria de ciclos y estadísticas comparadas con la congregación.
struct TerritoryDetailView: View {
    @StateObject private var viewModel: TerritoryDetailViewModel
    @ObservedObject private var permissionManager = PermissionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteAlert = false
    @State private var showEditSheet = false
    @State private var editingTransaction: Transaction?
    @State private var transactionToDelete: Transaction?
    @State private var showDeleteTransactionAlert = false

    private let territoryName: String

    init(territoryId: Int, territoryName: String, apiService: APIService = NetworkManager.shared) {
        self.territoryName = territoryName
        _viewModel = StateObject(wrappedValue: TerritoryDetailViewModel(territoryId: territoryId, apiService: apiService))
    }

    var body: some View {
        // GeometryReader externo para conocer el inset superior (status bar +
        // toolbar) y poder extender el mapa de la cabecera por detrás de ambos.
        GeometryReader { proxy in
            content(topInset: proxy.safeAreaInsets.top)
        }
    }

    private func content(topInset: CGFloat) -> some View {
        ZStack {
            LiquidBackgroundView()
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.territory == nil {
                loadingState
            } else if let errorMessage = viewModel.errorMessage, viewModel.territory == nil {
                errorState(errorMessage)
            } else if let territory = viewModel.territory {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // La cabecera va sin margen lateral: el mapa sangra
                        // hasta los bordes de la pantalla y por detrás de la
                        // toolbar.
                        heroHeader(territory: territory, topInset: topInset)
                            .appear(index: 0)

                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            TrajectorySection(
                                transactions: viewModel.transactions,
                                stats: viewModel.stats,
                                canManage: permissionManager.canManageTerritories,
                                onEdit: { editingTransaction = $0 },
                                onDelete: {
                                    transactionToDelete = $0
                                    showDeleteTransactionAlert = true
                                }
                            )
                            .appear(index: 1)

                            if let stats = viewModel.stats {
                                TerritoryStatsSection(stats: stats, transactions: viewModel.transactions)
                                    .appear(index: 2)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.bottom, AppSpacing.xl)
                }
                .scrollIndicators(.hidden)
                .coordinateSpace(name: Self.scrollSpace)
                .refreshable {
                    await viewModel.loadData()
                }
                .safeAreaInset(edge: .bottom) {
                    bottomAction(territory: territory)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbar {
            if permissionManager.canManageTerritories {
                ToolbarItem(placement: .topBarTrailing) {
                    adminMenu
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .alert("territory.detail.delete_confirmation_title", isPresented: $showDeleteAlert) {
            Button("cancel", role: .cancel) { }
            Button("territory.detail.delete", role: .destructive) {
                Task {
                    if await viewModel.deleteTerritory() {
                        ToastManager.shared.show(
                            NSLocalizedString("territory.delete.success", value: "Territory deleted", comment: ""),
                            style: .success,
                            undoHandle: viewModel.lastUndoHandle,
                            duration: viewModel.lastUndoHandle?.toastDuration ?? 3
                        )
                        NotificationCenter.default.post(name: .territoryDeleted, object: nil)
                        dismiss()
                    } else {
                        HapticManager.shared.notification(type: .error)
                    }
                }
            }
        } message: {
            Text("territory.detail.delete_confirmation_message")
        }
        .alert("common.delete_confirmation", isPresented: $showDeleteTransactionAlert, presenting: transactionToDelete) { transaction in
            Button("common.delete", role: .destructive) {
                Task {
                    if await viewModel.deleteTransaction(id: transaction.id) {
                        ToastManager.shared.show(
                            NSLocalizedString("dashboard.delete_transaction_success", value: "Transaction deleted", comment: ""),
                            style: .success,
                            undoHandle: viewModel.lastUndoHandle,
                            duration: viewModel.lastUndoHandle?.toastDuration ?? 3
                        )
                    }
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: { _ in
            Text("dashboard.delete_transaction_message")
        }
        .sheet(isPresented: $showEditSheet) {
            if let territory = viewModel.territory {
                EditTerritoryView(territory: territory, apiService: NetworkManager.shared) {
                    Task {
                        await viewModel.loadData()
                    }
                }
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            EditTransactionSheet(
                transactionEvent: TransactionEvent(
                    txnId: transaction.id,
                    type: .given,
                    date: transaction.givenDateUtc,
                    transaction: transaction
                ),
                isPresented: Binding(
                    get: { self.editingTransaction != nil },
                    set: { if !$0 { self.editingTransaction = nil } }
                ),
                onComplete: {
                    await self.viewModel.loadData()
                }
            )
        }
    }

    // MARK: Estados de carga y error

    /// Esqueleto con la misma silueta que la pantalla real: cabecera hero
    /// (código, nombre, días y responsable), anillos de trayectoria, banner
    /// comparativo y ranking.
    private var loadingState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(Color.surface)
                    .frame(width: 150, height: 44)
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(Color.surface)
                    .frame(width: 190, height: 24)
                Capsule()
                    .fill(Color.surface)
                    .frame(width: 96, height: 28)
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(Color.surface)
                    .frame(width: 130, height: 58)
                    .padding(.top, AppSpacing.md)
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(Color.surface)
                    .frame(height: 64)
                    .padding(.top, AppSpacing.xs)
            }
            .overlay(ProgressView().tint(.accent))

            HStack(spacing: AppSpacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle()
                        .fill(Color.surface)
                        .frame(width: 68, height: 68)
                }
            }
            .padding(.top, AppSpacing.md)

            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(Color.surface)
                .frame(height: 72)

            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(Color.surface)
                .frame(height: 96)

            Spacer()
        }
        .padding(AppSpacing.md)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.warning)
            Text("territory.detail.error")
                .font(.appTitle())
                .foregroundStyle(Color.textPrimary)
            Text(message)
                .multilineTextAlignment(.center)
                .font(.appSubheadline())
                .foregroundStyle(Color.textSecondary)
            Button("territory.detail.retry") {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.accentDeep)
        }
        .padding(AppSpacing.lg)
    }

    // MARK: Cabecera

    private static let scrollSpace = "territory-detail-scroll"

    /// Cabecera hero: el mapa real (cámara inclinada, como en las tarjetas
    /// del listado) sangra a todo el ancho y por detrás de la toolbar, con
    /// efecto stretchy al tirar del scroll. Sobre él viven el código, el
    /// estado, los días del ciclo y el responsable actual.
    private func heroHeader(territory: TerritoryDetail, topInset: CGFloat) -> some View {
        let isAssigned = territory.personName != nil
        let referenceDate = isAssigned ? territory.givenDateUtc : territory.lastPickedDateUtc
        let status = TerritoryStatusPresentation(territory.toTerritory().operationalStatus())
        let days = referenceDate.map {
            max(Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0, 0)
        }

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(territory.code)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.accentDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(territory.name)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 150)

            statusChip(territory: territory)
                .padding(.top, AppSpacing.xxs)

            daysBlock(days: days, isAssigned: isAssigned, referenceDate: referenceDate)
                .padding(.top, AppSpacing.md)

            if let person = territory.personName {
                responsibleRow(person: person)
                    .padding(.top, AppSpacing.xs)
            }

            // Aviso cuando el ciclo supera la media de la congregación.
            if isAssigned, let days,
               let average = viewModel.stats.map({ Int($0.globalAverageHoldingTime.rounded()) }),
               average > 0, days > average {
                reviewBanner(averageDays: average)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            if let geometry = territory.mapGeometry {
                stretchyMapBackdrop(geometry: geometry, topInset: topInset, tint: status.color)
            }
        }
    }

    /// Bloque de días del ciclo (o de descanso si está libre).
    private func daysBlock(days: Int?, isAssigned: Bool, referenceDate: Date?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isAssigned ? "territory.detail.cycle.started_label" : "territory.detail.available_label")
                .font(.appSubheadline())
                .foregroundStyle(Color.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                CountUpText(value: days ?? 0, font: .system(size: 44, weight: .heavy, design: .rounded))
                Text("common.days")
                    .font(.appHeadline())
                    .foregroundStyle(Color.textSecondary)
            }

            if let referenceDate {
                Text(String(
                    format: String.localized("territory.detail.cycle.since_date"),
                    referenceDate.formatted(date: .abbreviated, time: .omitted)
                ))
                .font(.appCaption())
                .foregroundStyle(Color.textSecondary)
            } else {
                Text("territory.detail.available_never")
                    .font(.appCaption())
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Fila del responsable en cristal, integrada en el hero sobre el mapa.
    private func responsibleRow(person: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            InitialsAvatar(name: person, size: 40, tint: .accentDeep)

            VStack(alignment: .leading, spacing: 2) {
                Text(person)
                    .font(.appHeadline())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text("territory.detail.cycle.responsible")
                    .font(.appCaption())
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.sm)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
    }

    /// Aviso "conviene revisar": lleva directamente al flujo de devolución.
    private func reviewBanner(averageDays: Int) -> some View {
        Button {
            HapticManager.shared.selection()
            if let territory = viewModel.territory {
                AppRouter.shared.openQuickAction(.territory(territory.toTerritory()))
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        LinearGradient(
                            colors: [Color.accentTertiary, Color.accentTertiary.opacity(0.8)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .shadow(color: Color.accentTertiary.opacity(0.35), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("territory.detail.cycle.review_title")
                        .font(.appSubheadline().weight(.semibold))
                        .foregroundStyle(Color.accentTertiary)
                    Text(String(format: String.localized("territory.detail.cycle.review_avg"), averageDays))
                        .font(.appCaption())
                        .foregroundStyle(Color.textSecondary)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(AppSpacing.sm)
            .glassEffect(
                .regular.tint(Color.accentTertiary.opacity(0.14)),
                in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    /// Mapa de fondo del hero: cubre también la toolbar/status bar; al tirar
    /// del scroll más allá del límite se estira con un zoom anclado abajo
    /// (stretchy) y, al hacer scroll normal, se desplaza más despacio que el
    /// contenido (parallax).
    private func stretchyMapBackdrop(geometry: TerritoryMapGeometry, topInset: CGFloat, tint: Color) -> some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .named(Self.scrollSpace)).minY
            let stretch = max(minY, 0)
            let height = proxy.size.height + topInset

            // Más distancia de cámara y menos desplazamiento que en las
            // tarjetas: el polígono cabe entero en la mitad derecha del hero.
            TerritorySnapshotBackdrop(
                geometry: geometry,
                stroke: tint,
                fill: tint,
                verticalBias: 0.16,
                distanceMultiplier: 4.2,
                horizontalShift: 0.28
            )
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0), location: 0),
                            .init(color: .black.opacity(0.45), location: 0.30),
                            .init(color: .black, location: 0.55),
                            .init(color: .black, location: 1)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.75),
                            .init(color: .black.opacity(0), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: proxy.size.width, height: height)
                // El zoom compensa exactamente el arrastre: el borde superior
                // queda clavado a la pantalla mientras el mapa crece.
                .scaleEffect(1 + stretch / height, anchor: .bottom)
                // Parallax: al hacer scroll, el mapa acompaña al contenido a
                // un 60 % de su velocidad (con factor < 1 nunca asoma el
                // borde superior del mapa por debajo de la toolbar).
                .offset(y: -topInset + (minY < 0 ? -minY * 0.4 : 0))
        }
    }

    private func statusChip(territory: TerritoryDetail) -> some View {
        let presentation = TerritoryStatusPresentation(territory.toTerritory().operationalStatus())

        return HStack(spacing: AppSpacing.xxs) {
            Circle()
                .fill(presentation.color)
                .frame(width: 7, height: 7)
            Text(presentation.title)
                .font(.appCaption().weight(.bold))
                .foregroundStyle(presentation.color)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(presentation.color.opacity(0.10))
        )
        .overlay(
            Capsule()
                .strokeBorder(presentation.color.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: Acción principal fija (sustituye a la tab bar)

    private func bottomAction(territory: TerritoryDetail) -> some View {
        Group {
            if territory.personName == nil {
                Button {
                    HapticManager.shared.selection()
                    AppRouter.shared.openQuickAction(.territory(territory.toTerritory()))
                } label: {
                    Label("territory.detail.assign", systemImage: "paperplane.fill")
                        .font(.appHeadline())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xxs)
                }
                .buttonStyle(.glassProminent)
                .tint(.accent)
            } else {
                Button {
                    HapticManager.shared.selection()
                    AppRouter.shared.openQuickAction(.territory(territory.toTerritory()))
                } label: {
                    Label("territory.detail.return", systemImage: "tray.and.arrow.down.fill")
                        .font(.appHeadline())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xxs)
                }
                .buttonStyle(.glassProminent)
                .tint(.accentSecondary)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.xs)
    }

    // MARK: Menú de administración

    private var adminMenu: some View {
        Menu {
            Button {
                HapticManager.shared.selection()
                Task {
                    if await viewModel.refreshImage() {
                        HapticManager.shared.notification(type: .success)
                        ToastManager.shared.show(NSLocalizedString("territory.detail.refresh_image_success", comment: ""), style: .success)
                    } else {
                        HapticManager.shared.notification(type: .error)
                    }
                }
            } label: {
                Label("territory.detail.menu.refresh_map", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isRefreshingImage)

            Button {
                showEditSheet = true
            } label: {
                Label("territory.detail.edit", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("territory.detail.delete", systemImage: "trash")
            }
        } label: {
            if viewModel.isRefreshingImage {
                ProgressView()
            } else {
                Image(systemName: "ellipsis")
            }
        }
        .accessibilityLabel(Text("territory.detail.menu.accessibility"))
    }
}

extension TerritoryDetail {
    func toTerritory() -> Territory {
        return Territory(
            id: self.id,
            code: self.code,
            name: self.name,
            mapUrl: self.mapUrl,
            imgUrl: self.imgUrl,
            personName: self.personName,
            givenDateUtc: self.givenDateUtc,
            lastPickedDateUtc: self.lastPickedDateUtc,
            mapGeometry: self.mapGeometry
        )
    }
}
