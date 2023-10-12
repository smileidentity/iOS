import SmileID

enum NavigationDestination: ReflectiveEquatable {
    case documentCaptureScreen(
        countryCode: String,
        documentType: String,
        captureBothSides: Bool,
        delegate: DocumentVerificationResultDelegate
    )
    case countrySelectorScreen(homeVieModel: HomeViewModel)
    case documentSelectorScreen(document: ValidDocument, homeViewModel: HomeViewModel)
}
