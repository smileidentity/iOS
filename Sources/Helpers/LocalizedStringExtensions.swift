import SwiftUI

extension LocalizedStringKey {
    var stringKey: String? {
        Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String
    }

    func stringValue(locale: Locale = .current) -> String {
        return SmileIDResourcesHelper.localizedString(for: self.stringKey, locale: locale)
    }
}
