import Sentry

protocol ErrorReportingService {
    func captureError(_ error: any Error, userInfo: [String: Any]?)
}

class SentryErrorReporter {
    static let shared: SentryErrorReporter = SentryErrorReporter()

    private let sentryHub: SentryHub

    private init() {
        // setup sentry options
        let options = Sentry.Options()
        // TODO: Protect this DSN
        options.dsn = "https://d81c446178994daaa52af05a8b3072b9@o1154186.ingest.us.sentry.io/4504162971353088"
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
        self.sentryHub = SentryHub(client: sentryClient, andScope: scope)
    }
}

extension SentryErrorReporter: ErrorReportingService {
    func captureError(_ error: any Error, userInfo: [String: Any]? = nil) {
        sentryHub.capture(error: error)
    }
}
