import SwiftUI

struct SelfieConfirmationView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: SelfieCaptureViewModel
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text(SmileIDResourcesHelper.localizedString(for: "Confirmation.GoodSelfie"))
                    .multilineTextAlignment(.center)
                    .font(SmileIdentity.theme.header2)
                    .foregroundColor(SmileIdentity.theme.accent)

                Text(SmileIDResourcesHelper.localizedString(for: "Confirmation.FaceClear"))
                    .multilineTextAlignment(.center)
                    .font(SmileIdentity.theme.header5)
                    .foregroundColor(SmileIdentity.theme.tertiary)
                    .lineSpacing(1.3)
            }
            VStack {
                Image(uiImage: UIImage(data: viewModel.selfieImage ?? Data()) ?? UIImage())
                    .cornerRadius(16)
                    .clipped()
            }

            VStack {
                SmileButton(style: .secondary,
                            title: "Confirmation.YesUse",
                            clicked: {
                    viewModel.submit()
                })
                SmileButton(style: .secondary,
                            title: "Confirmation.Retake",
                            clicked: {
                                        viewModel.resetCapture()
                })
            }.padding()
        }
        .padding(.top, 64)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}
