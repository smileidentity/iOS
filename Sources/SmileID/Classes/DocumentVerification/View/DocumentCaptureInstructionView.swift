import SwiftUI
/// Instructionf for document capture
public struct DocumentCaptureInstructionsView: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @ObservedObject private var viewModel: DocumentCaptureViewModel
    private weak var documentCaptureDelegate: DocumentCaptureResultDelegate?

    init(viewModel: DocumentCaptureViewModel, delegate: DocumentCaptureResultDelegate) {
        self.viewModel = viewModel
        documentCaptureDelegate = delegate
    }

    fileprivate init(viewModel: DocumentCaptureViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        /// we're using the selfie capture view for now to show it's working
        CaptureInstructionView<DocumentCaptureView>(
            image: SmileIDResourcesHelper.InstructionsHeaderdDocumentIcon,
            title: SmileIDResourcesHelper.localizedString(for: "Instructions.Document.Header"),
            callOut: SmileIDResourcesHelper.localizedString(for: "Instructions.Document.Callout"),
            instructions: [
                CaptureInstruction(title:
                                    SmileIDResourcesHelper.localizedString(for: "Instructions.GoodLight"),
                                   instruction:
                                    SmileIDResourcesHelper.localizedString(for: "Instructions.GoodLightBody"),
                                   image: Constants.ImageName.light),
                CaptureInstruction(title:
                                    SmileIDResourcesHelper.localizedString(for: "Instructions.ClearImage"),
                                   instruction:
                                    SmileIDResourcesHelper.localizedString(for: "Instructions.ClearImageBody"),
                                   image: Constants.ImageName.clearImage),
            ], captureType: .document,
            destination: .documentCaptureScreen(documentCaptureViewModel: viewModel, delegate: documentCaptureDelegate),
            // TO-DO: Get value from viewModel after document capture feature is complete
            showAttribution: true
        )
    }
}

struct DocumentCaptureInstructionsView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentCaptureInstructionsView(viewModel: DocumentCaptureViewModel(userId: "",
                                                                            jobId: "",
                                                                            document: Document(countryCode: "",
                                                                                               documentType: "",
                                                                                               aspectRatio: 0.2)))
            .environment(\.locale, Locale(identifier: "en"))
    }
}
