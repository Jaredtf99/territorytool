import Foundation

/// `nonisolated`: son constantes que necesita también el transporte de red, que vive fuera
/// del actor principal.
nonisolated struct AppConfig {
    static let supabaseURL = "https://oedcfdvywibzjtoggcgh.supabase.co"
    static let supabasePublishableKey = "sb_publishable_ce7dSBmgyydxEoqekFZ-Ww_RMe-2MCb"
}
