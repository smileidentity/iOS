import Combine
import SwiftUI

enum DocumentDirective: String {
    case defaultInstructions = "Document.Directive.Default"
    case capturing = "Document.Directive.Capturing"
}

private let correctAspectRatioTolerance = 0.1
private let centeredTolerance = 30.0
private let documentAutoCaptureWaitTime: TimeInterval = 1.0
private let analysisSampleInterval: TimeInterval = 0.350

class DocumentCaptureViewModel: ObservableObject {
    // Initializer properties
    private let knownAspectRatio: Double?
    private var localMetadata: LocalMetadata

    // Other properties
    private let defaultAspectRatio: Double
    private let textDetector = TextDetector()
    private var subscribers = Set<AnyCancellable>()
    private var processingImage = false
    private var documentFirstDetectedAtTime: TimeInterval?
    private var lastAnalysisTime: TimeInterval = 0
    private var areEdgesDetectedSubscriber: AnyCancellable?
    private let side: DocumentCaptureSide
    private var retryCount: Int = 0
    private(set) var documentImageOrigin: DocumentImageOriginValue?

    // UI properties
    @Published var unauthorizedAlert: AlertState?
    @Published var acknowledgedInstructions = false
    @Published var showPhotoPicker = false
    @Published var directive: DocumentDirective = .defaultInstructions
    @Published var areEdgesDetected = false
    @Published var idAspectRatio = 1.0
    @Published var showManualCaptureButton = false
    @Published var documentImageToConfirm: Data?
    @Published var captureError: Error?
    @Published var isCapturing = false
    var cameraManager = CameraManager(orientation: .portrait)

    init(
        knownAspectRatio: Double? = nil,
        side: DocumentCaptureSide,
        localMetadata: LocalMetadata
    ) {
        self.knownAspectRatio = knownAspectRatio
        self.side = side
        self.localMetadata = localMetadata
        defaultAspectRatio = knownAspectRatio ?? 1.0
        DispatchQueue.main.async { [self] in
            idAspectRatio = defaultAspectRatio
        }

        cameraManager.$status
            .receive(on: DispatchQueue.main)
            .filter { $0 == .unauthorized }
            .map { _ in AlertState.cameraUnauthorized }
            .sink { alert in self.unauthorizedAlert = alert }
            .store(in: &subscribers)

        cameraManager.capturedImagePublisher
            .receive(on: DispatchQueue.global())
            .compactMap { $0 }
            .sink(receiveValue: onCaptureComplete)
            .store(in: &subscribers)

        cameraManager.sampleBufferPublisher
            .receive(on: DispatchQueue(label: "com.smileidentity.receivebuffer"))
            .compactMap { $0 }
            .sink(receiveValue: analyzeImage)
            .store(in: &subscribers)

        // Show Manual Capture button after 10 seconds
        Timer.scheduledTimer(
            timeInterval: 10,
            target: self,
            selector: #selector(showManualCapture),
            userInfo: nil,
            repeats: false
        )

        // Auto capture after 1 second of edges detected
        areEdgesDetectedSubscriber = $areEdgesDetected.sink(receiveValue: { areEdgesDetected in
            if areEdgesDetected {
                if let documentFirstDetectedAtTime = self.documentFirstDetectedAtTime {
                    let now = Date().timeIntervalSince1970
                    let elapsedTime = now - documentFirstDetectedAtTime
                    if elapsedTime > documentAutoCaptureWaitTime && !self.isCapturing {
                        self.documentImageOrigin = DocumentImageOriginValue.cameraAutoCapture
                        self.captureDocument()
                    }
                } else {
                    self.documentFirstDetectedAtTime = Date().timeIntervalSince1970
                }
            } else {
                self.documentFirstDetectedAtTime = nil
            }
        })
    }

    let metadataTimerStart = MonotonicTime()

    func updateLocalMetadata(_ newMetadata: LocalMetadata) {
        self.localMetadata = newMetadata
        objectWillChange.send()
    }

    @objc func showManualCapture() {
        DispatchQueue.main.async {
            self.showManualCaptureButton = true
        }
    }

    /// Called when the user taps the "Take Photo" button on the instructions screen. This is NOT
    /// the same as the manual capture button.
    func onTakePhotoClick() {
        DispatchQueue.main.async {
            self.isCapturing = false
            self.acknowledgedInstructions = true
        }
    }

    /// Called when the user taps the "Select from Gallery" button on the instructions screen
    func onGalleryClick() {
        showPhotoPicker = true
    }

    func onPhotoSelectedFromGallery(_ image: UIImage) {
        guard let image = image.jpegData(compressionQuality: 1.0) else {
            DispatchQueue.main.async {
                self.captureError = SmileIDError.unknown("Error saving image")
            }
            return
        }
        documentImageOrigin = DocumentImageOriginValue.gallery
        DispatchQueue.main.async {
            self.acknowledgedInstructions = true
            self.documentImageToConfirm = image
            self.showPhotoPicker = false
        }
    }

    /// Called when auto capture determines the image quality is sufficient OR when the user taps
    /// the manual capture button.
    func captureDocument() {
        if isCapturing {
            print("Already capturing. Skipping duplicate capture request")
            return
        }
        DispatchQueue.main.async {
            self.isCapturing = true
            self.directive = .capturing
        }
        documentImageOrigin = DocumentImageOriginValue.cameraManualCapture
        cameraManager.capturePhoto()
    }

    /// Called if the user declines the image in the capture confirmation dialog.
    func onRetry() {
        documentImageOrigin = nil
        switch side {
        case .front:
            localMetadata.metadata.removeAllOfType(Metadatum.DocumentFrontCaptureRetries.self)
            localMetadata.metadata.removeAllOfType(Metadatum.DocumentFrontCaptureDuration.self)
            localMetadata.metadata.removeAllOfType(Metadatum.DocumentFrontImageOrigin.self)
        case .back:
            localMetadata.metadata.removeAllOfType(Metadatum.DocumentBackCaptureRetries.self)
            localMetadata.metadata.removeAllOfType(Metadatum.DocumentBackCaptureDuration.self)
            localMetadata.metadata.removeAllOfType(Metadatum.DocumentBackImageOrigin.self)
        }
        retryCount += 1
        DispatchQueue.main.async {
            self.isCapturing = false
            self.acknowledgedInstructions = false
            self.documentImageToConfirm = nil
            self.captureError = nil
            self.directive = .defaultInstructions
            self.areEdgesDetected = false
        }
    }

    private func onCaptureComplete(image: Data) {
        let croppedImage = ImageUtils.cropImageToAspectRatio(
            imageData: image,
            aspectRatio: 1 / idAspectRatio
        )
        switch side {
        case .front:
            localMetadata.addMetadata(
                Metadatum.DocumentFrontCaptureDuration(duration: metadataTimerStart.elapsedTime()))
            localMetadata.addMetadata(Metadatum.DocumentFrontCaptureRetries(retries: retryCount))
            localMetadata.addMetadata(
                Metadatum.DocumentFrontImageOrigin(origin: documentImageOrigin!))
        case .back:
            localMetadata.addMetadata(
                Metadatum.DocumentBackCaptureDuration(duration: metadataTimerStart.elapsedTime()))
            localMetadata.addMetadata(Metadatum.DocumentBackCaptureRetries(retries: retryCount))
            localMetadata.addMetadata(
                Metadatum.DocumentBackImageOrigin(origin: documentImageOrigin!))
        }
        DispatchQueue.main.async { [self] in
            documentImageToConfirm = croppedImage
            isCapturing = false
        }
    }

    /// Analyzes a single frame from the camera. No other frame will be processed until this one
    /// completes. This is to prevent the UI from flickering between different states.
    ///
    /// Unlike Android, we don't perform focus and luminance detection, as text detection serves as
    /// a better proxy for image quality.
    ///
    /// - Parameter buffer: The pixel buffer to analyze
    private func analyzeImage(buffer: CVPixelBuffer) {
        let now = Date().timeIntervalSince1970
        let elapsedTime = now - lastAnalysisTime
        let enoughTimeHasPassed = elapsedTime > analysisSampleInterval
        if processingImage || isCapturing || !enoughTimeHasPassed {
            return
        }
        lastAnalysisTime = now
        processingImage = true
        let imageSize = CGSize(
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer)
        )
        RectangleDetector.rectangle(
            forPixelBuffer: buffer,
            aspectRatio: knownAspectRatio
        ) { [self] rect in
            if rect == nil {
                resetBoundingBox()
                processingImage = false
                return
            }
            let detectedAspectRatio = 1 / (rect?.aspectRatio ?? defaultAspectRatio)
            let isCorrectAspectRatio = isCorrectAspectRatio(
                detectedAspectRatio: detectedAspectRatio
            )
            let idAspectRatio = knownAspectRatio ?? detectedAspectRatio
            let isCentered = isRectCentered(
                detectedRect: rect,
                imageWidth: Double(imageSize.width),
                imageHeight: Double(imageSize.height)
            )
            DispatchQueue.main.async { [self] in
                self.idAspectRatio = idAspectRatio
            }
            textDetector.detectText(buffer: buffer) { [self] hasText in
                processingImage = false
                let areEdgesDetected = isCentered && isCorrectAspectRatio && hasText
                DispatchQueue.main.async { [self] in
                    self.areEdgesDetected = areEdgesDetected
                }
            }
        }
    }

    private func resetBoundingBox() {
        DispatchQueue.main.async {
            self.areEdgesDetected = false
            self.idAspectRatio = self.defaultAspectRatio
        }
    }

    private func isCorrectAspectRatio(
        detectedAspectRatio: Double,
        tolerance: Double = correctAspectRatioTolerance
    ) -> Bool {
        let expectedAspectRatio = knownAspectRatio ?? detectedAspectRatio
        return abs(detectedAspectRatio - expectedAspectRatio) < tolerance
    }

    private func isRectCentered(
        detectedRect: Quadrilateral?,
        imageWidth: Double,
        imageHeight: Double,
        tolerance: Double = centeredTolerance
    ) -> Bool {
        guard let detectedRect = detectedRect else { return false }

        // Sometimes, the bounding box is out of frame. This cannot be considered centered
        // We check only left and right because the document should always fill the width but may
        // not fill the height
        if detectedRect.topLeft.x < tolerance || detectedRect.topRight.x > imageWidth - tolerance {
            return false
        }

        let imageCenterX = imageWidth / 2
        let imageCenterY = imageHeight / 2

        let rectCenterX = (detectedRect.topLeft.x + detectedRect.topRight.x) / 2
        let rectCenterY = (detectedRect.topLeft.y + detectedRect.bottomLeft.y) / 2

        let deltaX = abs(imageCenterX - rectCenterX)
        let deltaY = abs(imageCenterY - rectCenterY)

        let isCenteredHorizontally = deltaX < tolerance
        let isCenteredVertically = deltaY < tolerance

        return isCenteredHorizontally && isCenteredVertically
    }

    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}
