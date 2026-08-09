import Foundation

/// Todas las notificaciones internas de la app, en un solo sitio.
///
/// `nonisolated` porque se publican también desde el transporte de red y desde
/// `TokenManager`, que viven fuera del actor principal: sin esto, el aislamiento por
/// defecto (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) las haría inaccesibles desde ahí.
/// Son constantes inmutables, así que no hay nada que proteger.
nonisolated extension Notification.Name {
    static let authChanged = Notification.Name("authChanged")
    static let sessionExpired = Notification.Name("sessionExpired")
    static let congregationChanged = Notification.Name("congregationChanged")
    static let userRequestedLogout = Notification.Name("userRequestedLogout")
    static let territoryDeleted = Notification.Name("territoryDeleted")
    static let territoryDataChanged = Notification.Name("territoryDataChanged")
    static let userDataChanged = Notification.Name("userDataChanged")
}
