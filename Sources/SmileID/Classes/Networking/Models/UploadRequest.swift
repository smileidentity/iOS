import Foundation

public struct UploadRequest: Codable {
    public var images: [UploadImageInfo]
    public var idInfo: IdInfo?

    public init(
        images: [UploadImageInfo],
        idInfo: IdInfo? = nil
    ) {
        self.images = images
        self.idInfo = idInfo
    }

    enum CodingKeys: String, CodingKey {
        case images
        case idInfo = "id_info"
    }
}

public struct IdInfo: Codable {
    let country: String
    let idType: String?
    let idNumber: String?
    let firstName: String?
    let middleName: String?
    let lastName: String?
    let dob: String?
    let bankCode: String?
    let entered: Bool?

    public init(
        country: String,
        idType: String? = nil,
        idNumber: String? = nil,
        firstName: String? = nil,
        middleName: String? = nil,
        lastName: String? = nil,
        dob: String? = nil,
        bankCode: String? = nil,
        entered: Bool? = nil
    ) {
        self.country = country
        self.idType = idType
        self.idNumber = idNumber
        self.firstName = firstName
        self.middleName = middleName
        self.lastName = lastName
        self.dob = dob
        self.bankCode = bankCode
        self.entered = entered
    }

    enum CodingKeys: String, CodingKey {
        case country = "country"
        case idType = "id_type"
        case idNumber = "id_number"
        case firstName = "first_name"
        case middleName = "middle_name"
        case lastName = "last_name"
        case dob = "dob"
        case bankCode = "bank_code"
        case entered = "entered"
    }
}

public struct UploadImageInfo: Codable {
    public var imageTypeId: ImageType
    public var fileName: String

    public init(
        imageTypeId: ImageType,
        fileName: String
    ) {
        self.imageTypeId = imageTypeId
        self.fileName = fileName
    }

    enum CodingKeys: String, CodingKey {
        case imageTypeId = "image_type_id"
        case fileName = "file_name"
    }
}

public enum ImageType: String, Codable {
    case selfieJpgFile = "0"
    case idCardJpgFile = "1"
    case selfieJpgBase64 = "2"
    case idCardJpgBase64 = "3"
    case livenessJpgFile = "4"
    case idCardRearJpgFile = "5"
    case livenessJpgBase64 = "6"
    case idCardRearJpgBase64 = "7"
}
