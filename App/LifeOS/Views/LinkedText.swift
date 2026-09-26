import LifeOSKit
import SwiftUI

/// Text whose web links are tappable. The package finds the links.
struct LinkedText: View {
    let text: String

    var body: some View {
        Text(LinkedText.attributed(text))
    }

    static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString()
        for segment in LinkText.segments(text) {
            switch segment {
            case .text(let plain):
                result.append(AttributedString(plain))
            case .link(let label, let url):
                var link = AttributedString(label)
                link.link = url
                result.append(link)
            }
        }
        return result
    }
}
