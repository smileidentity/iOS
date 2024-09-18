import Foundation
import SwiftUI

/// Orchestrates the selfie capture flow - navigates between instructions, requesting permissions,
/// showing camera view, and displaying processing screen
public struct OrchestratedSelfieCaptureScreen: View {
    public let allowAgentMode: Bool
    public let showAttribution: Bool
    public let showInstructions: Bool
    public let onResult: SmartSelfieResultDelegate
    @ObservedObject var viewModel: SelfieViewModel
    
    @EnvironmentObject private var localMetadata: LocalMetadata
    @State private var acknowledgedInstructions = false
    private var originalBrightness = UIScreen.main.brightness
    
    public init(
        userId: String,
        jobId: String,
        isEnroll: Bool,
        allowNewEnroll: Bool,
        allowAgentMode: Bool,
        showAttribution: Bool,
        showInstructions: Bool,
        extraPartnerParams: [String: String],
        skipApiSubmission: Bool,
        onResult: SmartSelfieResultDelegate
    ) {
        self.allowAgentMode = allowAgentMode
        self.showAttribution = showAttribution
        self.showInstructions = showInstructions
        self.onResult = onResult
        viewModel = SelfieViewModel(
            isEnroll: isEnroll,
            userId: userId,
            jobId: jobId,
            allowNewEnroll: allowNewEnroll,
            skipApiSubmission: skipApiSubmission,
            extraPartnerParams: extraPartnerParams,
            localMetadata: LocalMetadata()
        )
    }
    
    public var body: some View {
        if showInstructions, !acknowledgedInstructions {
            SmartSelfieInstructionsScreen(showAttribution: showAttribution) {
                acknowledgedInstructions = true
            }
        } else if let processingState = viewModel.processingState {
            ProcessingScreen(
                processingState: processingState,
                inProgressTitle: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.ProcessingSelfie"
                ),
                inProgressSubtitle: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.Time"
                ),
                inProgressIcon: SmileIDResourcesHelper.FaceOutline,
                successTitle: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.SelfieCaptureComplete"
                ),
                successSubtitle: SmileIDResourcesHelper.localizedString(
                    for: $viewModel.errorMessageRes.wrappedValue ?? "Confirmation.SuccessBody"
                ),
                successIcon: SmileIDResourcesHelper.CheckBold,
                errorTitle: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.Failure"
                ),
                errorSubtitle: getErrorSubtitle(
                    errorMessageRes: $viewModel.errorMessageRes.wrappedValue,
                    errorMessage: $viewModel.errorMessage.wrappedValue
                ),
                errorIcon: SmileIDResourcesHelper.Scan,
                continueButtonText: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.Continue"
                ),
                onContinue: { viewModel.onFinished(callback: onResult) },
                retryButtonText: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.Retry"
                ),
                onRetry: viewModel.onRetry,
                closeButtonText: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.Close"
                ),
                onClose: { viewModel.onFinished(callback: onResult) }
            )
        } else if let selfieToConfirm = viewModel.selfieToConfirm {
            ImageCaptureConfirmationDialog(
                title: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.GoodSelfie"
                ),
                subtitle: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.FaceClear"
                ),
                image: UIImage(data: selfieToConfirm)!,
                confirmationButtonText: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.YesUse"
                ),
                onConfirm: viewModel.submitJob,
                retakeButtonText: SmileIDResourcesHelper.localizedString(
                    for: "Confirmation.Retake"
                ),
                onRetake: viewModel.onSelfieRejected,
                scaleFactor: 1.25
            )
        } else {
            SelfieCaptureScreen(
                allowAgentMode: allowAgentMode,
                viewModel: viewModel
            )
            .onAppear {
                viewModel.updateLocalMetadata(localMetadata)
                UIScreen.main.brightness = 1
            }
            .onDisappear { UIScreen.main.brightness = originalBrightness }
        }
    }
}
