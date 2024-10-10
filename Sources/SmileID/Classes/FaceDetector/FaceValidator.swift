import Foundation

protocol FaceValidatorDelegate: AnyObject {
    func updateValidationResult(_ result: FaceValidationResult)
}

struct FaceValidationResult {
    let userInstruction: SelfieCaptureInstruction?
    let hasDetectedValidFace: Bool
    let faceInBounds: Bool
}

final class FaceValidator {
    weak var delegate: FaceValidatorDelegate?
    private var faceLayoutGuideFrame: CGRect = .zero

    // MARK: Constants
    private let selfieQualityThreshold: Float = 0.5
    private let luminanceThreshold: ClosedRange<Int> = 80...200
    private let faceBoundsMultiplier: CGFloat = 1.5
    private let faceBoundsThreshold: CGFloat = 50

    init() {}

    func setLayoutGuideFrame(with frame: CGRect) {
        self.faceLayoutGuideFrame = frame
    }

    func validate(
        faceGeometry: FaceGeometryData,
        selfieQuality: SelfieQualityData,
        brightness: Int,
        currentLivenessTask: LivenessTask?
    ) {
        // check face bounds
        let faceBoundsState = checkAcceptableBounds(using: faceGeometry.boundingBox)
        let isAcceptableBounds = faceBoundsState == .detectedFaceAppropriateSizeAndPosition

        // check brightness
        let isAcceptableBrightness = luminanceThreshold.contains(brightness)

        // check selfie quality
        let isAcceptableSelfieQuality = checkSelfieQuality(selfieQuality)

        // check that face is ready for capture
        let hasDetectedValidFace = checkValidFace(
            isAcceptableBounds,
            isAcceptableBrightness,
            isAcceptableSelfieQuality
        )

        // determine what instruction/animation to display to users
        let userInstruction = userInstruction(
            from: faceBoundsState,
            detectedValidFace: hasDetectedValidFace,
            isAcceptableBrightness: isAcceptableBrightness,
            isAcceptableSelfieQuality: isAcceptableSelfieQuality,
            livenessTask: currentLivenessTask
        )

        let validationResult = FaceValidationResult(
            userInstruction: userInstruction,
            hasDetectedValidFace: hasDetectedValidFace,
            faceInBounds: isAcceptableBounds
        )
        delegate?.updateValidationResult(validationResult)
    }

    private func userInstruction(
        from faceBoundsState: FaceBoundsState,
        detectedValidFace: Bool,
        isAcceptableBrightness: Bool,
        isAcceptableSelfieQuality: Bool,
        livenessTask: LivenessTask?
    ) -> SelfieCaptureInstruction? {
        if detectedValidFace {
            if let livenessTask {
                switch livenessTask {
                case .lookLeft:
                    return .lookLeft
                case .lookRight:
                    return .lookRight
                case .lookUp:
                    return .lookUp
                }
            }
            return nil
        } else if faceBoundsState == .detectedFaceOffCentre {
            return .headInFrame
        } else if faceBoundsState == .detectedFaceTooSmall {
            return .moveCloser
        } else if faceBoundsState == .detectedFaceTooLarge {
            return .moveBack
        } else if !isAcceptableSelfieQuality || !isAcceptableBrightness {
            return .goodLight
        }
        return nil
    }

    // MARK: Validation Checks
    private func checkAcceptableBounds(using boundingBox: CGRect) -> FaceBoundsState {
        if boundingBox.width > faceBoundsMultiplier * faceLayoutGuideFrame.width {
            return .detectedFaceTooLarge
        } else if boundingBox.width * faceBoundsMultiplier < faceLayoutGuideFrame.width {
            return .detectedFaceTooSmall
        } else {
            if abs(
                boundingBox.midX - faceLayoutGuideFrame.midX
            ) > faceBoundsThreshold {
                return .detectedFaceOffCentre
            } else if abs(boundingBox.midY - faceLayoutGuideFrame.midY) > faceBoundsThreshold {
                return .detectedFaceOffCentre
            } else {
                return .detectedFaceAppropriateSizeAndPosition
            }
        }
    }

    private func checkSelfieQuality(_ value: SelfieQualityData) -> Bool {
        return value.passed >= selfieQualityThreshold
    }

    private func checkValidFace(
        _ isAcceptableBounds: Bool,
        _ isAcceptableBrightness: Bool,
        _ isAcceptableSelfieQuality: Bool
    ) -> Bool {
        return isAcceptableBounds && isAcceptableBrightness && isAcceptableSelfieQuality
    }
}
