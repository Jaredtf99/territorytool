import Foundation

struct Transaction: Codable, Identifiable {
    // The API might return "transactionId" or "id". 
    // Based on docs: "transactionId": 0
    // We map it to id for Identifiable conformance if needed, or keep original name.
    // Let's use CodingKeys to map transactionId to id.
    
    let id: Int
    let personId: Int
    let givenDateUtc: Date
    let pickedDateUtc: Date?
    let givenBy: String?
    let pickedBy: String?
    let territoryId: Int
    let territoryName: String
    let personName: String
    
    enum CodingKeys: String, CodingKey {
        case id = "transactionId"
        case personId
        case givenDateUtc
        case pickedDateUtc
        case givenBy
        case pickedBy
        case territoryId
        case territoryName
        case personName
    }
}
