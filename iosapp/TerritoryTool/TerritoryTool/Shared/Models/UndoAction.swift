import Foundation

enum UndoHandleKind: String, Codable, Equatable {
    case domain
    case user
}

struct UndoHandle: Codable, Equatable {
    let id: String
    let expiresAt: Date
    let kind: UndoHandleKind
}

struct UndoableMutationResponse: Decodable {
    let undoId: String
    let expiresAt: Date

    private enum CodingKeys: String, CodingKey {
        case undoId
        case expiresAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        undoId = try container.decode(String.self, forKey: .undoId)
        let rawExpiresAt = try container.decode(String.self, forKey: .expiresAt)
        expiresAt = try Self.decodeDate(rawExpiresAt)
    }

    func handle(kind: UndoHandleKind) -> UndoHandle {
        UndoHandle(id: undoId, expiresAt: expiresAt, kind: kind)
    }

    private static func decodeDate(_ value: String) throws -> Date {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: [],
                debugDescription: "Invalid undo expiration timestamp: \(value)"
            )
        )
    }
}

extension UndoHandle {
    var toastDuration: TimeInterval {
        max(0.5, expiresAt.timeIntervalSinceNow)
    }
}
