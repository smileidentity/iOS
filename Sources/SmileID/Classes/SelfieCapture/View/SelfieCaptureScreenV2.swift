import Lottie
import SwiftUI

public struct SelfieCaptureScreenV2: View {
    @ObservedObject var viewModel: SelfieViewModelV2
    let showAttribution: Bool
    @State private var showImages: Bool = false

    @State private var progress1: CGFloat = 0.3
    @State private var progress2: CGFloat = 0.8
    @State private var progress3: CGFloat = 0.5

    @Environment(\.presentationMode) private var presentationMode

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Camera Preview Layer
                CameraView(cameraManager: viewModel.cameraManager, selfieViewModel: viewModel)
                    .onAppear {
                        viewModel.cameraManager.switchCamera(to: .front)
                    }

                // CameraPreview Mask
                Rectangle()
                    .fill(.white)
                    .reverseMask {
                        Circle()
                            .frame(width: 260, height: 260)
                    }

                FaceBoundingArea(viewModel: viewModel)
                UserInstructionsView(viewModel: viewModel)
                LivenessGuidesView(
                    topArcProgress: $progress1,
                    rightArcProgress: $progress2,
                    leftArcProgress: $progress3
                )
                .hidden()

                VStack {
                    Spacer()
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text(SmileIDResourcesHelper.localizedString(for: "Action.Cancel"))
                            .foregroundColor(SmileID.theme.accent)
                    }
                }
                .padding(.bottom, 40)
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                viewModel.perform(action: .windowSizeDetected(proxy.frame(in: .global)))
            }
            .alert(item: $viewModel.unauthorizedAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message ?? ""),
                    primaryButton: .default(
                        Text(SmileIDResourcesHelper.localizedString(for: "Camera.Unauthorized.PrimaryAction")),
                        action: {
                            viewModel.perform(action: .openApplicationSettings)
                        }
                    ),
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showImages) {
                CapturedImagesView(model: viewModel)
            }
        }
    }

    // swiftlint:disable identifier_name
    @ViewBuilder func DebugView() -> some View {
        ZStack {
            FaceBoundingBoxView(model: viewModel)
            FaceLayoutGuideView(model: viewModel)
            VStack(spacing: 0) {
                Spacer()
                Text("xDelta: \(viewModel.boundingXDelta)")
                Text("yDelta: \(viewModel.boundingYDelta)")
                switch viewModel.isAcceptableBounds {
                case .unknown:
                    Text("Bounds - Unknown")
                case .detectedFaceTooSmall:
                    Text("Bounds - Face too small")
                case .detectedFaceTooLarge:
                    Text("Bounds - Face too large")
                case .detectedFaceOffCentre:
                    Text("Bounds - Face off Center")
                case .detectedFaceAppropriateSizeAndPosition:
                    Text("Bounds - Appropriate Size and Position")
                }
                Divider()
                Text("Yaw: \(viewModel.activeLiveness.yawAngle)")
                Text("Row: \(viewModel.activeLiveness.rollAngle)")
                Text("Pitch: \(viewModel.activeLiveness.pitchAngle)")
                Text("Quality: \(viewModel.faceQualityValue)")
                Text("Fail: \(viewModel.selfieQualityValue.failed) | Pass: \(viewModel.selfieQualityValue.passed)")
                    .font(.subheadline.weight(.medium))
                    .padding(5)
                    .background(Color.yellow)
                    .clipShape(.rect(cornerRadius: 5))
                    .padding(.bottom, 10)
                HStack {
                    switch viewModel.activeLiveness.faceDirection {
                    case .left:
                        Text("Looking Left")
                    case .right:
                        Text("Looking Right")
                    case .none:
                        Text("Looking Straight")
                    }
                    Spacer()
                    Button {
                        showImages = true
                    } label: {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.yellow)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text("\(viewModel.livenessImages.count + (viewModel.selfieImage != nil ? 1 : 0))")
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            )
                    }
                }
            }
            .font(.footnote)
            .foregroundColor(.white)
            .padding(.bottom, 40)
            .padding(.horizontal)
        }
    }

    // swiftlint:disable identifier_name
    @ViewBuilder func CameraOverlayView() -> some View {
        VStack {
            HStack {
                Text(SmileIDResourcesHelper.localizedString(for: viewModel.directive))
                    .font(SmileID.theme.header2)
                    .foregroundColor(.primary)
                    .padding(.bottom)
            }
            .background(Color.black)
            Spacer()
            HStack {
                Button {
                    viewModel.perform(action: .toggleDebugMode)
                } label: {
                    Image(systemName: "ladybug")
                        .font(.title)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
