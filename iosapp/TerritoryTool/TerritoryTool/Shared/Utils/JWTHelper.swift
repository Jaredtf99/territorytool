import Foundation

class JWTHelper {
    
    // Standard and custom claim keys
    private static let roleClaimKey = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"
    private static let userNameClaimKey = "UserName"
    private static let userIdClaimKey = "UserID"
    
    static func getUserRole(from token: String) -> UserRole? {
        guard let claims = decode(jwtToken: token) else { return nil }
        
        if let roleString = claims["app_role"] as? String ?? claims["role"] as? String ?? claims[roleClaimKey] as? String {
             return UserRole(rawValue: roleString)
        }
        if let storedRole = TokenManager.shared.getUserRole() {
            return UserRole(rawValue: storedRole)
        }
        return nil
    }
    
    static func getUserName(from token: String) -> String? {
        guard let claims = decode(jwtToken: token) else { return nil }

        return claims[userNameClaimKey] as? String
            ?? claims["unique_name"] as? String
            ?? claims["name"] as? String
            ?? claims["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"] as? String
            ?? TokenManager.shared.getUserName()
    }

    // Active congregation id carried in the JWT.
    static func getCongregationId(from token: String) -> String? {
        guard let claims = decode(jwtToken: token) else { return TokenManager.shared.getActiveCongregationId() }
        return claims["congregation_id"] as? String ?? TokenManager.shared.getActiveCongregationId()
    }

    // Global superadmin flag carried in the JWT.
    static func isSuperadmin(from token: String) -> Bool {
        guard let claims = decode(jwtToken: token) else { return false }
        if let flag = claims["is_superadmin"] as? Bool { return flag }
        if let flag = claims["is_superadmin"] as? NSNumber { return flag.boolValue }
        return false
    }
    
    private static func decode(jwtToken jwt: String) -> [String: Any]? {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }
        return decodeJWTPart(segments[1])
    }
    
    private static func decodeJWTPart(_ value: String) -> [String: Any]? {
        var body = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let length = Double(body.lengthOfBytes(using: String.Encoding.utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length
        if paddingLength > 0 {
            let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
            body = body + padding
        }
        guard let data = Data(base64Encoded: body, options: .ignoreUnknownCharacters) else { return nil }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any]
            return json
        } catch {
            return nil
        }
    }
}
