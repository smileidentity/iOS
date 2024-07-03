import Foundation

public class Metadata: Codable {
    let items: [Metadatum]
    
    init(items: [Metadatum]) {
        self.items = items
    }
    
    static func `default`() -> Metadata {
        return Metadata(items: [Metadatum.sdk, Metadatum.sdkVersion])
    }
}

public enum Metadatum: Codable {
    case sdk
    case sdkVersion
    case documentFrontImageOrigin(origin: DocumentImageOriginValue)
    case documentBackImageOrigin(origin: DocumentImageOriginValue)
    case cameraFacing(facing: CameraFacingValue)
    
    var value: String {
        switch self {
        case .sdk:
            return "iOS"
        case .sdkVersion:
            return SmileID.version
        case .documentFrontImageOrigin(let origin):
            return origin.rawValue
        case .documentBackImageOrigin(let origin):
            return origin.rawValue
        case .cameraFacing(let facing):
            return facing.rawValue
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case name, value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        switch self {
        case .sdk:
            try container.encode("sdk", forKey: .name)
        case .sdkVersion:
            try container.encode("sdk_version", forKey: .name)
        case .documentFrontImageOrigin:
            try container.encode("document_front_image_origin", forKey: .name)
        case .documentBackImageOrigin:
            try container.encode("document_back_image_origin", forKey: .name)
        case .cameraFacing:
            try container.encode("camera_facing", forKey: .name)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let value = try container.decode(String.self, forKey: .value)
        
        switch name {
        case "sdk":
            self = .sdk
        case "sdk_version":
            self = .sdkVersion
        case "document_front_image_origin":
            self = .documentFrontImageOrigin(origin: DocumentImageOriginValue(rawValue: value)!)
        case "document_back_image_origin":
            self = .documentBackImageOrigin(origin: DocumentImageOriginValue(rawValue: value)!)
        case "camera_facing":
            self = .cameraFacing(facing: CameraFacingValue(rawValue: value)!)
        default:
            throw DecodingError.dataCorruptedError(forKey: .name, in: container, debugDescription: "Invalid type")
        }
    }
}

public enum DocumentImageOriginValue: String, Codable {
    case gallery = "gallery"
    case cameraAutoCapture = "camera_auto_capture"
    case cameraManualCapture = "camera_manual_capture"
}

public enum CameraFacingValue: String, Codable {
    case front = "front"
    case back = "back"
}
