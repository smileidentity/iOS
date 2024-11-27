import AVFoundation
import SwiftUICore
import Combine
import XCTest

@testable import SmileID

final class SelfieViewModelTests: XCTestCase {

    var selfieViewModel: SelfieViewModelV2!

    // mock delegates
    var mockResultDelegate: MockSmartSelfieResultDelegate!
    var mockFaceValidatorDelegate: MockFaceValidatorDelegate!

    // mock dependencies
    var stubCameraManager: StubCameraManager!
    var mockFaceValidator: MockFaceValidator!
    var mockFaceDetector: MockFaceDetector!
    var stubLivenessManager: StubLivenessManager!

    override func setUp() {
        super.setUp()
        // initialise mocks
        mockResultDelegate = MockSmartSelfieResultDelegate()
        mockFaceValidatorDelegate = MockFaceValidatorDelegate()

        stubCameraManager = StubCameraManager()
        mockFaceValidator = MockFaceValidator()
        mockFaceDetector = MockFaceDetector()
        stubLivenessManager = StubLivenessManager()

        selfieViewModel = SelfieViewModelV2(
            cameraManager: stubCameraManager,
            faceDetector: mockFaceDetector,
            faceValidator: mockFaceValidator,
            livenessCheckManager: stubLivenessManager,
            delayTimer: MockTimer(),
            dispatchQueue: DispatchQueueMock(),
            selfieCaptureConfig: SelfieCaptureConfig(
                isEnroll: true,
                userId: "testuser",
                jobId: "testjob",
                allowNewEnroll: false,
                skipApiSubmission: false,
                useStrictMode: true,
                allowAgentMode: false,
                showAttribution: true,
                showInstructions: true,
                extraPartnerParams: [:]
            ),
            onResult: mockResultDelegate,
            localMetadata: LocalMetadata()
        )
    }

    override func tearDown() {
        selfieViewModel = nil
        mockResultDelegate = nil
        mockFaceValidatorDelegate = nil
        
        mockFaceDetector = nil
        mockFaceValidator = nil
        stubCameraManager = nil
        stubLivenessManager = nil
        super.tearDown()
    }

    func testFaceLayoutGuideFrame() {
        let windowSize = CGSize(width: 393, height: 852)
        let safeArea = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        selfieViewModel.perform(action: .windowSizeDetected(windowSize, safeArea))
        selfieViewModel.perform(action: .onViewAppear)

        XCTAssertEqual(
            mockFaceValidator.faceGuideFrame,
            CGRect(x: 71.5, y: 100, width: 250, height: 350)
        )
        XCTAssertEqual(selfieViewModel.selfieCaptureState, .capturingSelfie)
    }

    func testInitialSetup_ShouldSetupDependencies() {
        XCTAssertNotNil(mockFaceDetector.resultDelegate)
        XCTAssertNotNil(mockFaceValidator.delegate)
        XCTAssertNotNil(stubLivenessManager.delegate)
        XCTAssertNotNil(mockFaceValidator.delegate)
    }

    func testBasics() {
        let testImage = createTestUIImage()
        guard let testImageBuffer = createTestImageBuffer(with: testImage) else {
            XCTFail("Test Image Buffer shoud not be nil")
            return
        }
        stubCameraManager.sendSampleBuffer(testImageBuffer)
        stubCameraManager.sendSampleBuffer(testImageBuffer)
        stubCameraManager.sendSampleBuffer(testImageBuffer)
        stubCameraManager.sendSampleBuffer(testImageBuffer)
        stubCameraManager.sendSampleBuffer(testImageBuffer)
        stubCameraManager.sendSampleBuffer(testImageBuffer)
        stubCameraManager.sendSampleBuffer(testImageBuffer)
        stubCameraManager.sendSampleBuffer(testImageBuffer)
    }
}

// MARK: Helper Methods
extension SelfieViewModelTests {
    private func createTestUIImage() -> UIImage? {
        guard let imagePath = Bundle(for: type(of: self))
            .path(forResource: "sample_selfie", ofType: "jpg") else {
            return nil
        }
        return UIImage(contentsOfFile: imagePath)
    }

    private func createTestImageBuffer(with uiImage: UIImage?) -> CVPixelBuffer? {
        return uiImage?.pixelBuffer(width: 360, height: 640)
    }
}

// MARK: Mocks & Stubs
class MockFaceDetector: FaceDetectorProtocol {
    weak var viewDelegate: FaceDetectorViewDelegate?

    weak var resultDelegate: FaceDetectorResultDelegate?

    func processImageBuffer(_ imageBuffer: CVPixelBuffer) {
    }
}

class MockFaceValidator: FaceValidatorProtocol {
    weak var delegate: FaceValidatorDelegate?
    
    var faceGuideFrame: CGRect = .zero

    func setLayoutGuideFrame(with frame: CGRect) {
        faceGuideFrame = frame
    }

    func validate(
        faceGeometry: FaceGeometryData, selfieQuality: SelfieQualityData, brightness: Int,
        currentLivenessTask: LivenessTask?
    ) {
        // perform validation
    }
}

class MockSmartSelfieResultDelegate: SmartSelfieResultDelegate {
    func didSucceed(selfieImage: URL, livenessImages: [URL], apiResponse: SmartSelfieResponse?) {
    }

    func didError(error: any Error) {
    }
}

class StubLivenessManager: LivenessCheckManager {
    var didInitiateLivenessCheck: Bool = false

    override func initiateLivenessCheck() {
        didInitiateLivenessCheck = true
    }

    override func processFaceGeometry(_ faceGeometry: FaceGeometryData) {
        // process face geometry here
    }
}

class StubCameraManager: CameraManager {
    var cameraSwitched: Bool = false
    var sessionPaused: Bool = false

    private var cancellable: AnyCancellable?
    @Published var cameraSamplebuffer: CVPixelBuffer?
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        super.init(orientation: .portrait)

        sampleBufferPublisher
            .sink { buffer in
                print("buffer received")
            }
            .store(in: &cancellables)
    }

    override var sampleBufferPublisher: Published<CVPixelBuffer?>.Publisher {
        $cameraSamplebuffer
    }

    override func switchCamera(to position: AVCaptureDevice.Position) {
        cameraSwitched.toggle()
    }

    override func pauseSession() {
        sessionPaused = true
    }
    
    func sendSampleBuffer(_ buffer: CVPixelBuffer) {
        DispatchQueue.main.async {
            self.cameraSamplebuffer = buffer
        }
    }
}
