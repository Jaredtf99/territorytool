import Foundation

extension Error {
    /// Mensaje claro para el usuario a partir de un error de backend.
    ///
    /// El backend lanza códigos en MAYÚSCULAS (p. ej. `GIVEN_DATE_BEFORE_LAST_PICKED_DATE`).
    /// Si hay traducción para `error.code.<CÓDIGO>` se usa; si el texto parece un código
    /// sin traducir se muestra un mensaje genérico (nunca el código crudo); en otro caso
    /// (mensajes ya legibles, errores de red) se muestra tal cual.
    var userFriendlyMessage: String {
        let raw: String
        if let netError = self as? NetworkError, case let .serverError(message) = netError {
            raw = message
        } else {
            raw = localizedDescription
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let key = "error.code.\(trimmed)"
        let localized = String.localized(key)
        if localized != key {
            return localized
        }

        // ¿Parece un código de backend (MAYÚSCULAS_CON_GUIONES_BAJOS) sin traducir?
        if trimmed.range(of: "^[A-Z][A-Z0-9_]+$", options: .regularExpression) != nil {
            return String.localized("error.action_failed")
        }

        return trimmed.isEmpty ? String.localized("error.action_failed") : trimmed
    }
}
