import Foundation
import ARKit
import UIKit
import Combine

protocol SelfieViewDelegate {
    func pauseARSession()
    func resumeARSession()
}

enum SelfieCaptureViewModelAction {
    case sceneUnstable
    case noFaceDetected
    case smileDirective
    case smileAction
    case noSmile
    case multipleFacesDetected
    case faceObservationDetected(FaceGeometryModel)
    case faceQualityObservationDetected(FaceQualityModel)
}

enum SelfieProcessingState {
    static func == (lhs: SelfieProcessingState, rhs: SelfieProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.complete, .complete):
            return false
        case (let .error(error1), let .error(error2)):
            return error1.localizedDescription == error2.localizedDescription
        case (.confirmation, .confirmation):
            return true
        case (.endFlow, .endFlow):
            return true
        case (.inProgress, .inProgress):
            return true
        default:
            return false
        }
    }

    case confirmation(Data)
    case inProgress
    case complete(JobStatusResponse<SmartSelfieJobResult>?, SmileIDError?)
    case endFlow
    case error(Error)
}

final class SelfieCaptureViewModel: ObservableObject, JobSubmittable, ConfirmationDialogContract {

    // MARK: Published Properties
    @Published var agentMode = false {
        didSet { switchCamera() }
    }
    @Published private(set) var progress: CGFloat = 0
    @Published var directive: String = "Instructions.Start"
    @Published private(set) var processingState: SelfieProcessingState? {
        didSet {
            switch processingState {
            case .none:
                resumeCameraSession()
            case .endFlow:
                pauseCameraSession()
            case .some:
                pauseCameraSession()
            }
        }
    }

    // MARK: Public Properties
    var faceLayoutGuideFrame = CGRect.zero
    var viewFinderSize = CGSize.zero
    var selfieViewDelegate: SelfieViewDelegate?
    var smartSelfieResultDelegate: SmartSelfieResultDelegate?
    weak var imageCaptureDelegate: SelfieImageCaptureDelegate?
    weak var viewDelegate: FaceDetectorDelegate? {
        didSet {
            faceDetector.viewDelegate = viewDelegate
        }
    }

    // MARK: Private Properties
    private var userId: String
    private var jobId: String
    private var isEnroll: Bool
    private var shouldSubmitJob: Bool
    private (set) var showAttribution: Bool
    private var selfieImage: Data?
    private var currentExif: [String: Any]?
    private (set) var allowsAgentMode: Bool
    private let subject = PassthroughSubject<String, Never>()
    private (set) lazy var cameraManager: CameraManageable = CameraManager(orientation: .portrait)
    private var faceDetector = FaceDetector()
    private var subscribers = Set<AnyCancellable>()
    private var faceDetectionSubscribers: AnyCancellable?
    private var throttleSubscription: AnyCancellable?
    private let numberOfLivenessImages = 7
    private let selfieImageSize = CGSize(width: 640, height: 640)
    private let livenessImageSize = CGSize(width: 320, height: 320)
    private var currentBuffer: CVPixelBuffer?
    private(set) var faceDetectionState: FaceDetectionState = .noFaceDetected
    private var fallbackTimer: Timer?
    private var savedFiles: SelfieCaptureResultStore?
    private var livenessImages = [Data]()
    private var lastCaptureTime: Int64 = 0
    private var interCaptureDelay = 600
    private var debounceTimer: Timer?
    private var isARSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }
    private(set) var isAcceptableRoll: Bool = false {
        didSet { calculateDetectedFaceValidity() }
    }
    private(set) var isAcceptableYaw: Bool = false {
        didSet { calculateDetectedFaceValidity() }
    }
    private(set) var isAcceptableBounds: FaceBoundsState = .unknown {
        didSet { calculateDetectedFaceValidity() }
    }
    private(set) var isAcceptableQuality: Bool = true {
        didSet { calculateDetectedFaceValidity() }
    }
    private(set) var faceGeometryState: FaceObservation<FaceGeometryModel, ErrorWrapper> = .faceNotFound {
        didSet { processUpdatedFaceGeometry() }
    }
    private(set) var faceQualityState: FaceObservation<FaceQualityModel, ErrorWrapper> = .faceNotFound {
        didSet { processUpdatedFaceQuality() }
    }
    private var isSmiling = false {
        didSet { calculateDetectedFaceValidity() }
    }
    private(set) var hasDetectedValidFace: Bool = false {
        didSet { captureImageIfNeeded() }
    }

    init(
        userId: String,
        jobId: String,
        isEnroll: Bool,
        allowsAgentMode: Bool = false,
        showAttribution: Bool = true,
        cameraManager: CameraManageable? = nil,
        shouldSubmitJob: Bool = true,
        imageCaptureDelegate: SelfieImageCaptureDelegate? = nil
    ) {
        self.userId = userId
        self.isEnroll = isEnroll
        self.jobId = jobId
        self.shouldSubmitJob = shouldSubmitJob
        self.showAttribution = showAttribution
        self.allowsAgentMode = allowsAgentMode
        self.imageCaptureDelegate = imageCaptureDelegate
        faceDetector.model = self
        if let cameraManager = cameraManager {
            self.cameraManager = cameraManager
        }
        if ARFaceTrackingConfiguration.isSupported {
            subscribeToARFrame()
        } else {
            setupFaceDetectionSubscriptions()
        }
        setupDirectiveSubscription()
    }

    func resetState() {
        agentMode = false
        resetCapture()
    }

    private func switchCamera() {
        resetCapture()
        if isARSupported {
            switchARKitCamera()
        } else {
            switchAVCaptureCamera()
        }
    }

    func pauseCameraSession() {
        if isARSupported && agentMode {
            cameraManager.pauseSession()
        } else if isARSupported && !agentMode {
            selfieViewDelegate?.pauseARSession()
            cameraManager.pauseSession()
        } else if !isARSupported {
            cameraManager.pauseSession()
        }
    }

    func resumeCameraSession() {
        if isARSupported && agentMode {
            cameraManager.resumeSession()
        } else if isARSupported && !agentMode {
            selfieViewDelegate?.resumeARSession()
        } else if !isARSupported {
            cameraManager.resumeSession()
        }
    }

    @objc func captureImageAfterThreeSecs() {
        captureImage()
        fallbackTimer = nil
    }

    func subscribeToARFrame() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveFrame),
            name: NSNotification.Name(rawValue: "UpdateARFrame"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        throttleSubscription?.cancel()
        throttleSubscription = nil
        pauseCameraSession()
    }

    @objc func didReceiveFrame(_ notification: NSNotification) {
        if let dict = notification.userInfo as? NSDictionary {
            if let frame = dict["frame"] as? ARFrame {
                currentBuffer = frame.capturedImage

                if #available(iOS 16.0, *) {
                    currentExif = frame.exifData
                } else {
                    currentExif = nil
                }
            }
        }
    }

    private func captureImageIfNeeded() {
        if hasDetectedValidFace {
            if livenessImages.count == 3 && isARSupported && !agentMode {
                perform(action: .smileDirective)
                if isSmiling {
                    captureImage()
                    return
                } else {
                    return
                }
            } else if livenessImages.count == 3 {
                perform(action: .smileDirective)
                if fallbackTimer == nil {
                    DispatchQueue.main.async {
                        self.fallbackTimer = Timer.scheduledTimer(
                            timeInterval: 2,
                            target: self,
                            selector: #selector(self.captureImageAfterThreeSecs),
                            userInfo: nil,
                            repeats: false
                        )
                    }
                }
                return
            }
            captureImage()
        }
    }

    func switchARKitCamera() {
        faceDetectionSubscribers?.cancel()
        faceDetectionSubscribers = nil
        if agentMode {
            selfieViewDelegate?.pauseARSession()
            setupFaceDetectionSubscriptions()
            cameraManager.switchCamera(to: .back)
        } else {
            cameraManager.pauseSession()
            selfieViewDelegate?.resumeARSession()
        }
    }

    func declineImage() {
        resetCapture()
        resumeCameraSession()
    }

    func switchAVCaptureCamera() {
        faceDetectionSubscribers?.cancel()
        faceDetectionSubscribers = nil
        setupFaceDetectionSubscriptions()
        if agentMode {
            cameraManager.switchCamera(to: .back)
        } else {
            cameraManager.switchCamera(to: .front)
        }
    }

    func perform(action: SelfieCaptureViewModelAction) {
        switch action {
        case .sceneUnstable:
            publishUnstableSceneObserved()
            subject.send("Instructions.Start")
        case .noFaceDetected:
            publishNoFaceObserved()
            subject.send("Instructions.Start")
        case .multipleFacesDetected:
            publishFaceObservation(.multipleFacesDetected)
            subject.send("Instructions.MultipleFaces")
        case .faceObservationDetected(let faceGeometry):
            publishFaceObservation(.faceDetected, faceGeometryModel: faceGeometry)
        case .faceQualityObservationDetected(let faceQualityModel):
            publishFaceObservation(.faceDetected, faceQualityModel: faceQualityModel)
        case .smileDirective:
            subject.send("Instructions.Smile")
        case .smileAction:
            if livenessImages.count >= 3 {
                isSmiling = true
            }
        case .noSmile:
            if livenessImages.count < 3 {
                isSmiling = false
            }
        }
    }

    private func captureImage() {
        DispatchQueue.main.async {
            if self.livenessImages.count >= 3 {
                self.perform(action: .smileDirective)
            } else {
                self.subject.send("Instructions.Capturing")
            }
        }
        guard let currentBuffer = currentBuffer, hasDetectedValidFace == true,
              livenessImages.count < numberOfLivenessImages + 1
        else {
            return
        }
        guard case let .faceFound(faceGeometry) = faceGeometryState else {
            return
        }
        var orientation: CGImagePropertyOrientation

        if isARSupported && !agentMode {
            orientation = .right
        } else if !isARSupported && !agentMode {
            orientation = .upMirrored
        } else {
            orientation = .up
        }

        while (livenessImages.count < numberOfLivenessImages) &&
                  ((Date().millisecondsSince1970 - lastCaptureTime) > interCaptureDelay) {
            guard let image = ImageUtils.resizePixelBufferToHeight(
                currentBuffer,
                height: Int(livenessImageSize.height),
                exif: currentExif,
                orientation: orientation
            )
            else {
                return
            }
            livenessImages.append(image)
            lastCaptureTime = Date().millisecondsSince1970
            updateProgress()
        }

        if (livenessImages.count == numberOfLivenessImages) &&
               ((Date().millisecondsSince1970 - lastCaptureTime) > interCaptureDelay) &&
               selfieImage == nil {
            publishFaceObservation(.finalFrame)
            guard let selfieImage = ImageUtils.resizePixelBufferToHeight(
                currentBuffer,
                height: Int(selfieImageSize.height),
                exif: currentExif,
                orientation: orientation
            )
            else {
                return
            }
            lastCaptureTime = Date().millisecondsSince1970
            self.selfieImage = selfieImage
            updateProgress()
            DispatchQueue.main.async {
                self.processingState = .confirmation(selfieImage)
            }
        }
    }

    private func handleError(_ error: SmileIDError) {
        switch error {
        case .request(let urlError):
            processingState = .error(urlError)
        case .httpError, .unknown:
            processingState = .error(error)
        case .jobStatusTimeOut:
            processingState = .complete(nil, nil)
        default:
            processingState = .complete(nil, error)
        }
    }

    func submit() {
        if !shouldSubmitJob {
            processingState = .complete(nil, nil)
            return
        }
        processingState = .inProgress
        var zip: Data
        do {
            savedFiles = try LocalStorage.saveImageJpg(
                livenessImages: livenessImages,
                previewImage: selfieImage!
            )
            let zipUrl = try LocalStorage.zipFiles(at: savedFiles!.allFiles)
            zip = try Data(contentsOf: zipUrl)
        } catch {
            processingState = .error(error)
            return
        }

        let jobType = isEnroll ? JobType.smartSelfieEnrollment : JobType.smartSelfieAuthentication
        let authRequest = AuthenticationRequest(
            jobType: jobType,
            enrollment: isEnroll,
            jobId: jobId,
            userId: userId
        )

        SmileID.api.authenticate(request: authRequest)
            .flatMap { authResponse in
                self.prepUpload(authResponse)
                    .flatMap { prepUploadResponse in
                        self.upload(prepUploadResponse, zip: zip)
                            .filter { result in
                                switch result {
                                case .response:
                                    return true
                                default:
                                    return false
                                }
                            }
                            .map { _ in authResponse }
                    }
            }
            .flatMap {
                self.getJobStatus($0) as AnyPublisher<JobStatusResponse<SmartSelfieJobResult>, Error>
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    DispatchQueue.main.async { [weak self] in
                        if let error = error as? SmileIDError {
                            self?.handleError(error)
                        }
                    }
                default:
                    self.processingState = .complete(nil, nil)
                }
            }, receiveValue: { [weak self] response in
                DispatchQueue.main.async {
                    self?.processingState = .complete(response, nil)
                }
            })
            .store(in: &subscribers)
    }

    func resetCapture() {
        DispatchQueue.main.async {
            if self.processingState != nil {
                self.processingState = nil
            }
            if self.progress != 0 {
                self.progress = 0
            }
        }
        isSmiling = false
        faceDetectionState = .noFaceDetected
        isAcceptableRoll = false
        isAcceptableYaw = false
        isAcceptableBounds = .unknown
        hasDetectedValidFace = false
        faceGeometryState = .faceNotFound
        faceQualityState = .faceNotFound
        faceDetector.model = self
        if !livenessImages.isEmpty {
            livenessImages = []
        }
        if selfieImage != nil {
            selfieImage = nil
        }
        if let savedFiles = savedFiles {
            try? LocalStorage.delete(at: savedFiles.allFiles)
        }
    }

    func acceptImage() {
        submit()
    }

    func handleClose() {
        pauseCameraSession()
        processingState = .endFlow
    }

    func handleCompletion() {
        switch processingState {
        case .complete(let response, let error):
            pauseCameraSession()
            processingState = .endFlow
            if let error = error {
                smartSelfieResultDelegate?.didError(error: error)
                return
            }
            if let savedFiles = savedFiles, let response = response {
                smartSelfieResultDelegate?.didSucceed(
                    selfieImage: savedFiles.selfie,
                    livenessImages: savedFiles.livenessImages,
                    jobStatusResponse: response
                )
                return
            }
            if let selfie = selfieImage {
                imageCaptureDelegate?.didCapture(
                    selfie: selfie,
                    livenessImages: livenessImages
                )
                return
            }
        default:
            break
        }
    }

    func handleRetry() {
        processingState = .inProgress
        submit()
    }

    private func publishUnstableSceneObserved() {
        faceDetectionState = .sceneUnstable
    }

    private func updateProgress() {
        DispatchQueue.main.async { [self] in
            let selfieImageCount = selfieImage == nil ? 0 : 1
            progress = CGFloat(
                livenessImages.count + selfieImageCount) / CGFloat(numberOfLivenessImages + 1
            )
        }
    }

    func setupDirectiveSubscription() {
        throttleSubscription = subject.throttle(
            for: .milliseconds(300),
            scheduler: RunLoop.main,
            latest: true
        ).sink { value in
            if value != self.directive {
                self.directive = value
            }
        }
    }
}

// MARK: Face detection methods
extension SelfieCaptureViewModel {
    private func setupFaceDetectionSubscriptions() {
        faceDetectionSubscribers = cameraManager.sampleBufferPublisher
            .receive(on: DispatchQueue.global())
            .compactMap { $0 }
            .sink {
                self.faceDetector.detect(pixelBuffer: $0)
                self.currentBuffer = $0
            }
    }

    private func pauseFaceDetection() {
        faceDetectionSubscribers?.cancel()
        faceDetectionSubscribers = nil
        cameraManager.pauseSession()
    }

    private func publishFaceObservation(
        _ faceDetectionState: FaceDetectionState,
        faceGeometryModel: FaceGeometryModel? = nil,
        faceQualityModel: FaceQualityModel? = nil
    ) {
        self.faceDetectionState = faceDetectionState
        if let faceGeometryModel = faceGeometryModel {
            faceGeometryState = .faceFound(faceGeometryModel)
        }
        if let faceQualityModel = faceQualityModel {
            faceQualityState = .faceFound(faceQualityModel)
        }
    }

    private func publishNoFaceObserved() {
        faceDetectionState = .noFaceDetected
        faceGeometryState = .faceNotFound
        faceQualityState = .faceNotFound
        resetCapture()
    }

    func invalidateFaceGeometryState() {
        isAcceptableRoll = false
        isAcceptableYaw = false
        isAcceptableBounds = .unknown
    }

    func calculateDetectedFaceValidity() {
        hasDetectedValidFace =
            isAcceptableBounds == .detectedFaceAppropriateSizeAndPosition &&
            isAcceptableRoll &&
            isAcceptableYaw &&
            isAcceptableQuality
    }

    func updateAcceptableBounds(using boundingBox: CGRect) {
        if boundingBox.width > (0.80 * faceLayoutGuideFrame.width) {
            isAcceptableBounds = .detectedFaceTooLarge
            subject.send("Instructions.FaceClose")
        } else if boundingBox.width < (faceLayoutGuideFrame.width * 0.25) {
            isAcceptableBounds = .detectedFaceTooSmall
            subject.send("Instructions.FaceFar")
        } else {
            let isFaceInFrame = boundingBox.minX >= faceLayoutGuideFrame.minX &&
                boundingBox.maxX <= faceLayoutGuideFrame.maxX &&
                boundingBox.maxY <= faceLayoutGuideFrame.maxY &&
                boundingBox.minY >= faceLayoutGuideFrame.minY
            if !isFaceInFrame {
                isAcceptableBounds = .detectedFaceOffCentre
                subject.send("Instructions.Start")
                resetCapture()
            } else {
                isAcceptableBounds = .detectedFaceAppropriateSizeAndPosition
            }
        }
    }

    // TO-DO: Fix roll and yaw
    func updateAcceptableRollYaw(using roll: Double, yaw: Double) {
        // Roll values differ because back camera feed is in landscape
        let maxRoll = agentMode || !isARSupported ? 2.0 : 0.5
        isAcceptableRoll = abs(roll) < maxRoll
        isAcceptableYaw = abs(CGFloat(yaw)) < 0.5
    }

    func processUpdatedFaceGeometry() {
        switch faceGeometryState {
        case .faceNotFound:
            invalidateFaceGeometryState()
        case .errored(let errorWrapper):
            print(errorWrapper.error.localizedDescription)
            invalidateFaceGeometryState()
        case .faceFound(let faceGeometryModel):
            let boundingBox = faceGeometryModel.boundingBox
            let roll = faceGeometryModel.roll.doubleValue
            let yaw = faceGeometryModel.yaw.doubleValue
            updateAcceptableBounds(using: boundingBox)
            updateAcceptableRollYaw(using: roll, yaw: yaw)
        }
    }

    func processUpdatedFaceQuality() {
        switch faceQualityState {
        case .faceNotFound:
            isAcceptableQuality = true
        case .errored(let errorWrapper):
            print(errorWrapper.error.localizedDescription)
            isAcceptableQuality = true
        case .faceFound(let faceQualityModel):
            if faceQualityModel.quality < 0.3 {
                isAcceptableQuality = true
            }
            isAcceptableQuality = true
        }
    }
}
