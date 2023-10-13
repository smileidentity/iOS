import SwiftUI

struct OrchestratedDocumentVerificationScreen<T>: View {
    let countryCode: String
    let documentType: String?
    let captureBothSides: Bool
    let idAspectRatio: Double?
    let bypassSelfieCaptureWithFile: URL?
    let userId: String
    let jobId: String
    let showAttribution: Bool
    let allowGalleryUpload: Bool
    let showInstructions: Bool
    let onResult: T

    @ObservedObject private var viewModel: OrchestratedDocumentVerificationViewModel<T>

    init(
        countryCode: String,
        documentType: String?,
        captureBothSides: Bool,
        idAspectRatio: Double?,
        bypassSelfieCaptureWithFile: URL?,
        userId: String,
        jobId: String,
        showAttribution: Bool,
        allowGalleryUpload: Bool,
        showInstructions: Bool,
        jobType: JobType,
        onResult: T
    ) {
        self.countryCode = countryCode
        self.documentType = documentType
        self.captureBothSides = captureBothSides
        self.idAspectRatio = idAspectRatio
        self.bypassSelfieCaptureWithFile = bypassSelfieCaptureWithFile
        self.userId = userId
        self.jobId = jobId
        self.showAttribution = showAttribution
        self.allowGalleryUpload = allowGalleryUpload
        self.showInstructions = showInstructions
        self.onResult = onResult
        // swiftlint:disable force_cast
        if jobType == .enhancedDocumentVerification {
            viewModel = OrchestratedEnhancedDocumentVerificationViewModel(
                userId: userId,
                jobId: jobId,
                countryCode: countryCode,
                documentType: documentType,
                captureBothSides: captureBothSides,
                selfieFile: bypassSelfieCaptureWithFile,
                jobType: jobType
            ) as! OrchestratedDocumentVerificationViewModel<T>
        } else {
            viewModel = OrchestratedDocumentVerificationViewModelImpl(
                userId: userId,
                jobId: jobId,
                countryCode: countryCode,
                documentType: documentType,
                captureBothSides: captureBothSides,
                selfieFile: bypassSelfieCaptureWithFile,
                jobType: jobType
            ) as! OrchestratedDocumentVerificationViewModel<T>
        }
        // swiftlint:enable force_cast
    }

    var body: some View {
        switch viewModel.step {
        case .frontDocumentCapture:
            DocumentCaptureScreen(
                showInstructions: showInstructions,
                showAttribution: showAttribution,
                allowGallerySelection: allowGalleryUpload,
                showSkipButton: false,
                instructionsTitleText: SmileIDResourcesHelper.localizedString(
                    for: "Instructions.Document.Front.Header"
                ),
                instructionsSubtitleText: SmileIDResourcesHelper.localizedString(
                    for: "Instructions.Document.Front.Callout"
                ),
                captureTitleText: SmileIDResourcesHelper.localizedString(for: "Action.TakePhoto"),
                knownIdAspectRatio: idAspectRatio,
                onConfirm: viewModel.onFrontDocumentImageConfirmed,
                onError: viewModel.onError
            )
        case .backDocumentCapture:
            DocumentCaptureScreen(
                showInstructions: showInstructions,
                showAttribution: showAttribution,
                allowGallerySelection: allowGalleryUpload,
                showSkipButton: true,
                instructionsTitleText: SmileIDResourcesHelper.localizedString(
                    for: "Instructions.Document.Back.Header"
                ),
                instructionsSubtitleText: SmileIDResourcesHelper.localizedString(
                    for: "Instructions.Document.Back.Callout"
                ),
                captureTitleText: SmileIDResourcesHelper.localizedString(for: "Action.TakePhoto"),
                knownIdAspectRatio: idAspectRatio,
                onConfirm: viewModel.onBackDocumentImageConfirmed,
                onError: viewModel.onError,
                onSkip: viewModel.onDocumentBackSkip
            )
        case .selfieCapture:
            SelfieCaptureView(
                viewModel: SelfieCaptureViewModel(
                    userId: userId,
                    jobId: jobId,
                    isEnroll: false,
                    shouldSubmitJob: false,
                    // imageCaptureDelegate is just for image capture, not job result
                    imageCaptureDelegate: viewModel
                ),
                showBackButton: false,
                delegate: nil
            )
        case .processing(let state):
            ProcessingScreen(
                processingState: state,
                inProgressTitle: SmileIDResourcesHelper.localizedString(
                    for: "Document.Processing.Header"
                ),
                inProgressSubtitle: SmileIDResourcesHelper.localizedString(
                    for: "Document.Processing.Callout"
                ),
                inProgressIcon: SmileIDResourcesHelper.DocumentProcessing,
                successTitle: SmileIDResourcesHelper.localizedString(
                    for: "Document.Complete.Header"
                ),
                successSubtitle: SmileIDResourcesHelper.localizedString(
                    for: "Document.Complete.Callout"
                ),
                successIcon: SmileIDResourcesHelper.CheckBold,
                errorTitle: SmileIDResourcesHelper.localizedString(for: "Document.Error.Header"),
                errorSubtitle: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.FailureReason"
                ),
                errorIcon: SmileIDResourcesHelper.Scan,
                continueButtonText: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.Continue"
                ),
                onContinue: { viewModel.onFinished(delegate: onResult) },
                retryButtonText: SmileIDResourcesHelper.localizedString(for: "Confirmation.Retry"),
                onRetry: viewModel.onRetry,
                closeButtonText: SmileIDResourcesHelper.localizedString(for: "Confirmation.Close"),
                onClose: { viewModel.onFinished(delegate: onResult) }
            )
        }
    }
}
