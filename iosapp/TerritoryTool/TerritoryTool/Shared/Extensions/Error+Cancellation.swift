import Foundation

extension Error {
    /// `true` cuando el error es una cancelación de `Task` o de `URLSession`.
    ///
    /// Las cancelaciones ocurren de forma normal (p. ej. SwiftUI cancela el
    /// `Task` de un `.refreshable` cuando el contenido cambia, o cancelamos una
    /// carga anterior al lanzar otra). Nunca deben mostrarse al usuario como un
    /// fallo ni deben borrar los datos ya cargados.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
