import Foundation

struct Transaction: Codable, Identifiable {
    let id: Int
    let personId: Int
    let givenDateUtc: Date
    let pickedDateUtc: Date?
    let givenBy: String?
    let pickedBy: String?
    let territoryId: Int
    let territoryName: String
    let personName: String
    /// `nil` cuando el origen no lo trae; al editar no se envía para no pisar el valor real.
    let deliveryFormat: DeliveryFormat?
    
    enum CodingKeys: String, CodingKey {
        // camelCase
        case id = "transactionId"
        case personId, givenDateUtc, pickedDateUtc, givenBy, pickedBy, territoryId, territoryName, personName, deliveryFormat
        // PascalCase
        case TransactionId, PersonId, GivenDateUtc, PickedDateUtc, GivenBy, PickedBy, TerritoryId, TerritoryName, PersonName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try camelCase first, then PascalCase
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? container.decode(Int.self, forKey: .TransactionId)
        personId = try container.decodeIfPresent(Int.self, forKey: .personId) ?? container.decode(Int.self, forKey: .PersonId)
        givenDateUtc = try container.decodeIfPresent(Date.self, forKey: .givenDateUtc) ?? container.decode(Date.self, forKey: .GivenDateUtc)
        pickedDateUtc = try container.decodeIfPresent(Date.self, forKey: .pickedDateUtc) ?? container.decodeIfPresent(Date.self, forKey: .PickedDateUtc)
        givenBy = try container.decodeIfPresent(String.self, forKey: .givenBy) ?? container.decodeIfPresent(String.self, forKey: .GivenBy)
        pickedBy = try container.decodeIfPresent(String.self, forKey: .pickedBy) ?? container.decodeIfPresent(String.self, forKey: .PickedBy)
        territoryId = try container.decodeIfPresent(Int.self, forKey: .territoryId) ?? container.decode(Int.self, forKey: .TerritoryId)
        territoryName = try container.decodeIfPresent(String.self, forKey: .territoryName) ?? container.decode(String.self, forKey: .TerritoryName)
        personName = try container.decodeIfPresent(String.self, forKey: .personName) ?? container.decode(String.self, forKey: .PersonName)
        deliveryFormat = try container.decodeIfPresent(DeliveryFormat.self, forKey: .deliveryFormat)
    }
    
    // Manual initializer for creating instances programmatically
    init(id: Int, personId: Int, givenDateUtc: Date, pickedDateUtc: Date?, givenBy: String?, pickedBy: String?, territoryId: Int, territoryName: String, personName: String, deliveryFormat: DeliveryFormat? = nil) {
        self.id = id
        self.personId = personId
        self.givenDateUtc = givenDateUtc
        self.pickedDateUtc = pickedDateUtc
        self.givenBy = givenBy
        self.pickedBy = pickedBy
        self.territoryId = territoryId
        self.territoryName = territoryName
        self.personName = personName
        self.deliveryFormat = deliveryFormat
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(personId, forKey: .personId)
        try container.encode(givenDateUtc, forKey: .givenDateUtc)
        try container.encodeIfPresent(pickedDateUtc, forKey: .pickedDateUtc)
        try container.encodeIfPresent(givenBy, forKey: .givenBy)
        try container.encodeIfPresent(pickedBy, forKey: .pickedBy)
        try container.encode(territoryId, forKey: .territoryId)
        try container.encode(territoryName, forKey: .territoryName)
        try container.encode(personName, forKey: .personName)
        try container.encodeIfPresent(deliveryFormat, forKey: .deliveryFormat)
    }
}
