import Foundation
import UIKit

public class SmileID {
    @Injected var injectedApi: SmileIDServiceable
    public static var api: SmileIDServiceable {
        return SmileID.instance.injectedApi
    }
    public static var configuration: Config {
        return config
    }
    internal static let instance: SmileID = {
        let container = DependencyContainer.shared
        container.register(SmileIDServiceable.self) {SmileIDService.init()}
        container.register(RestServiceClient.self) {URLSessionRestServiceClient.init()}
        container.register(ServiceHeaderProvider.self) {DefaultServiceHeaderProvider.init()}
        let instance = SmileID()
        return instance
    }()
    private init() {}
    internal static var config: Config!
    internal static var useSandbox = true
    private (set) public static var theme: SmileIdTheme = DefaultTheme()

    public class func initialize(config: Config, useSandbox: Bool = true) {
        self.config = config
        self.useSandbox = useSandbox
        SmileIDResourcesHelper.registerFonts()
    }

    public class func apply(_ theme: SmileIdTheme) {
        self.theme = theme
    }

    public class func smartSelfieRegistrationScreen(userId: String = "user-\(UUID().uuidString)",
                                                    jobId: String = "job-\(UUID().uuidString)",
                                                    delegate: SmartSelfieResultDelegate)
    -> SmartSelfieInstructionsView {
        let viewModel = SelfieCaptureViewModel(userId: userId, jobId: jobId, isEnroll: true)
        return  SmartSelfieInstructionsView(viewModel: viewModel, delegate: delegate)
    }

    public class func smartSelfieAuthenticationScreen(userId: String,
                                                      jobId: String = "job-\(UUID().uuidString)",
                                                      delegate: SmartSelfieResultDelegate)
    -> SmartSelfieInstructionsView {
        let viewModel = SelfieCaptureViewModel(userId: userId, jobId: jobId, isEnroll: false)
        return SmartSelfieInstructionsView(viewModel: viewModel, delegate: delegate)
    }

    public class func setEnvironment(useSandbox: Bool) {
        SmileID.useSandbox = useSandbox
    }
}