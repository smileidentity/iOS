import Foundation

enum CaptureGuideAnimation: Equatable {
    case goodLight
    case headInFrame
    case moveBack
    case moveCloser
    case lookRight
    case lookLeft
    case lookUp
    case turnPhoneUp

    var fileName: String {
        switch self {
        case .goodLight:
            return "light_animation"
        case .headInFrame:
            return "positioning"
        case .moveBack:
            return "positioning"
        case .moveCloser:
            return "positioning"
        case .lookRight:
            return "liveness_guides"
        case .lookLeft:
            return "liveness_guides"
        case .lookUp:
            return "liveness_guides"
        case .turnPhoneUp:
            return "positioning"
        }
    }

    var animationProgressRange: ClosedRange<CGFloat> {
        switch self {
        case .headInFrame:
            return 0...0.28
        case .moveBack:
            return 0.38...0.67
        case .moveCloser:
            return 0.73...1.0
        case .lookRight:
            return 0...0.4
        case .lookLeft:
            return 0.4...0.64
        case .lookUp:
            return 0.64...1.0
        default:
            return 0...1.0
        }
    }
}
