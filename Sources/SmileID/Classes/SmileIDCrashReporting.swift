import Sentry

class SmileIDCrashReporting {
    static let shared: SmileIDCrashReporting = SmileIDCrashReporting()

    private let smileIDPackagePrefix = "com.smileidentity"
    private(set) var hub: SentryHub?

    private init() {}

    deinit {
        disable()
    }

    func enable() {
        // setup sentry options
        let options = Sentry.Options()
        options.dsn = ArkanaKeys.Global().sENTRY_DSN
        options.releaseName = SmileID.version
        options.enableCrashHandler = true
        options.debug = true
        options.tracesSampleRate = 1.0
        options.profilesSampleRate = 1.0

        // setup sentry scope
        let scope = Sentry.Scope()
        scope.setTag(value: SmileID.config.partnerId, key: "partner_id")
        let user = Sentry.User()
        user.userId = SmileID.config.partnerId
        scope.setUser(user)

        // setup sentry hub
        let sentryClient = SentryClient(options: options)
        self.hub = SentryHub(client: sentryClient, andScope: scope)
        self.hub?.startSession()
    }

    func disable() {
        hub?.getClient()?.options.enableCrashHandler = false
        self.hub?.endSession()
        hub?.close()
        hub = nil
    }

    /// Checks whether the provided error involves Smile ID SDK. This is done by checking
    /// the stack trace of the error and its causes.
    /// - Parameter error: The error to check.
    /// - Returns: True if the error was caused by a Smile SDK, false otherwise.
    private func isCausedBySmileID(error: (any Error)?) -> Bool {
        guard let error = error else { return false }

        // Check if the error description contains the prefix
        if error.localizedDescription.contains(smileIDPackagePrefix) {
            return true
        }

        let nsError = error as NSError
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isCausedBySmileID(error: underlyingError)
        }

        return false
    }
}
