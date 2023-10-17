import SmileID
import SwiftUI

@available(iOS 14.0, *)
struct HomeView: View {
    let partner = SmileID.configuration.partnerId
    let version = SmileID.version
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    @ObservedObject var viewModel = HomeViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Test Our Products")
                    .font(SmileID.theme.header2)
                    .foregroundColor(.black)

                MyVerticalGrid(
                    maxColumns: 2,
                    items: [
                        ProductCell(
                            image: "userauth",
                            name: "SmartSelfie™ Enrollment",
                            content: SmileID.smartSelfieEnrollmentScreen(
                                userId: generateUserId(),
                                allowAgentMode: true,
                                delegate: viewModel
                            )
                        ),
                        ProductCell(
                            image: "userauth",
                            name: "SmartSelfie™ Authentication",
                            content: EnterUserIDView(
                                userId: viewModel.returnedUserID,
                                viewModel: UserIDViewModel()
                            )
                        ),
                        ProductCell(
                            image: "document",
                            name: "Document Verification",
                            content: DocumentVerificationWithSelector(delegate: viewModel)
                        ),
                        ProductCell(
                            image: "document",
                            name: "Enhanced Document Verification",
                            content: EnhancedDocumentVerificationWithSelector(delegate: viewModel)
                        )
                    ].map { AnyView($0) }
                )

                Spacer()

                Text("Partner \(partner) - Version \(version) - Build \(build)")
                    .font(SmileID.theme.body)
                    .foregroundColor(SmileID.theme.onLight)
            }
                .toast(isPresented: $viewModel.showToast) {
                    Text(viewModel.toastMessage)
                        .font(SmileID.theme.body)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
                .navigationBarTitle(Text("Smile ID"), displayMode: .inline)
                .navigationBarItems(trailing: ToggleButton())
                .background(SmileID.theme.backgroundLight.edgesIgnoringSafeArea(.all))
        }
    }
}

@available(iOS 14.0, *)
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let _ = SmileID.initialize(
            config: Config(
                partnerId: "",
                authToken: "",
                prodUrl: "",
                testUrl: "",
                prodLambdaUrl: "",
                testLambdaUrl: ""
            ),
            useSandbox: true
        )
        HomeView()
    }
}

private struct DocumentVerificationWithSelector: View {
    @State private var countryCode: String?
    @State private var documentType: String?
    @State private var captureBothSides: Bool?
    let delegate: DocumentVerificationResultDelegate

    var body: some View {
        if let countryCode = countryCode,
           let documentType = documentType,
           let captureBothSides = captureBothSides {
            SmileID.documentVerificationScreen(
                countryCode: countryCode,
                documentType: documentType,
                captureBothSides: captureBothSides,
                allowGalleryUpload: true,
                delegate: delegate
            )
        } else {
            DocumentVerificationIdTypeSelector { countryCode, documentType, captureBothSides in
                self.countryCode = countryCode
                self.documentType = documentType
                self.captureBothSides = captureBothSides
            }
        }
    }
}

private struct EnhancedDocumentVerificationWithSelector: View {
    @State private var countryCode: String?
    @State private var documentType: String?
    @State private var captureBothSides: Bool?
    let delegate: EnhancedDocumentVerificationResultDelegate

    var body: some View {
        if let countryCode = countryCode,
           let documentType = documentType,
           let captureBothSides = captureBothSides {
            SmileID.enhancedDocumentVerificationScreen(
                countryCode: countryCode,
                documentType: documentType,
                captureBothSides: captureBothSides,
                allowGalleryUpload: true,
                delegate: delegate
            )
        } else {
            DocumentVerificationIdTypeSelector { countryCode, documentType, captureBothSides in
                self.countryCode = countryCode
                self.documentType = documentType
                self.captureBothSides = captureBothSides
            }
        }
    }
}

/// A view that displays a grid of items in a vertical layout. It first fills up all items in the
/// first row before moving on to the next row. If the number of items is not a multiple of the
/// number of columns, the last row is filled from left to right with the remaining items.
struct MyVerticalGrid: View {
    let maxColumns: Int
    let items: [AnyView]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(0..<items.count / maxColumns + 1) { rowIndex in
                HStack(spacing: 24) {
                    let numRemainingItems = items.count - rowIndex * maxColumns
                    let numColumns = min(numRemainingItems, maxColumns)
                    ForEach(0..<numColumns) { columnIndex in
                        items[rowIndex * numColumns + columnIndex]
                    }
                }
            }
        }
    }
}

struct NavigationBarModifier: ViewModifier {
    var backgroundColor: Color = .clear

    init(backgroundColor: Color) {
        self.backgroundColor = backgroundColor
        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.configureWithTransparentBackground()
        coloredAppearance.backgroundColor = .clear
        coloredAppearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        coloredAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]

        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
        UINavigationBar.appearance().tintColor = .white
    }

    func body(content: Content) -> some View {
        ZStack {
            content
            VStack {
                GeometryReader { geometry in
                    backgroundColor
                        .frame(height: geometry.safeAreaInsets.top)
                        .edgesIgnoringSafeArea(.top)
                    Spacer()
                }
            }
        }
    }
}

extension View {
    func navigationBarColor(_ backgroundColor: Color) -> some View {
        modifier(NavigationBarModifier(backgroundColor: backgroundColor))
    }
}
