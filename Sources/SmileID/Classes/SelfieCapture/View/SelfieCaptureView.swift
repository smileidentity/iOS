import SwiftUI
import Combine

public struct SelfieCaptureView: View, SelfieViewDelegate {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var viewModel: SelfieCaptureViewModel
    private weak var delegate: SmartSelfieResultDelegate?
    let arView = ARView()

    init(viewModel: SelfieCaptureViewModel, delegate: SmartSelfieResultDelegate) {
        self.viewModel = viewModel
        self.delegate = delegate
    }

    // NB
    // TODO:only used for previews to remove lint issues
    fileprivate init(viewModel: SelfieCaptureViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geometry in
            let ovalSize = ovalSize(from: geometry)
            ZStack {
                arView
                    .onAppear {
                        viewModel.captureResultDelegate = delegate
                        viewModel.faceLayoutGuideFrame =
                        CGRect(origin: .zero,
                               size: ovalSize)
                        arView.preview.model = viewModel
                        viewModel.viewFinderSize = geometry.size
                        viewModel.selfieViewDelegate = self
                    }.scaleEffect(1.2, anchor: .top)

                FaceOverlayView(model: viewModel)
                switch viewModel.processingState {
                case .confirmation:
                    ModalPresenter { SelfieConfirmationView(viewModel: viewModel)}
                case .inProgress:
                    ModalPresenter(centered: true){ ProcessingView() }
                case .complete:
                    ModalPresenter { SuccessView(viewModel: viewModel) }
                case .error:
                    ModalPresenter { ErrorView(viewModel: viewModel) }
                default:
                    Text("")
                }

            }
        }
        .edgesIgnoringSafeArea(.all)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button {
            presentationMode.wrappedValue.dismiss()
        } label: {
            Image(uiImage: SmileIDResourcesHelper.ArrowLeft)
                .padding()
        })
        .background(SmileID.theme.backgroundMain)
        .onAppear {
  //viewModel.cameraManager.configure()
        }
        .onDisappear {
    //        viewModel.cameraManager.stopCaptureSession()
            viewModel.resetCapture()
        }
    }

    private func ovalSize(from geometry: GeometryProxy) -> CGSize {
        return CGSize(width: geometry.size.width * 0.6,
                      height: geometry.size.width * 0.6 / 0.7)
    }

    func pauseARSession() {
        arView.preview.pauseSession()
    }

    func resumeARSession() {
        arView.preview.resumeSession()
    }
}

struct FaceBoundingBoxView: View {
    @ObservedObject private(set) var model: SelfieCaptureViewModel

    var body: some View {
        switch model.faceGeometryState {
        case .faceNotFound:
            Rectangle().fill(Color.clear)
        case .faceFound(let faceGeometryModel):
            Rectangle()
                .path(in: CGRect(
                    x: faceGeometryModel.boundingBox.origin.x,
                    y: faceGeometryModel.boundingBox.origin.y,
                    width: faceGeometryModel.boundingBox.width,
                    height: faceGeometryModel.boundingBox.height
                ))
                .stroke(Color.yellow, lineWidth: 2.0)
        case .errored:
            Rectangle().fill(Color.clear)
        }
    }
}

struct SelfieCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        SelfieCaptureView(viewModel: SelfieCaptureViewModel(userId: UUID().uuidString,
                                                            jobId: UUID().uuidString,
                                                            isEnroll: false))
    }
}

class DummyDelegate: SmartSelfieResultDelegate {
    func didSucceed(selfieImage: Data, livenessImages: [Data], jobStatusResponse: JobStatusResponse) {}
    func didError(error: Error) {}
}
