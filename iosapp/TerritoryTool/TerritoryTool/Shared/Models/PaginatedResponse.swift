import Foundation

/// Generic wrapper for paginated API responses
/// Used for endpoints that return paginated data with metadata
struct PaginatedResponse<T: Codable>: Codable {
    let data: [T]
    let current_page: Int?
    let last_page: Int?
    let total: Int?
    
    enum CodingKeys: String, CodingKey {
        case data
        case current_page
        case last_page
        case total
    }
}
