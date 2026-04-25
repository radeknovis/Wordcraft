import Foundation

enum KeyboardKey: Hashable {
    case character(String)
    case space
    case delete
    case `return`
    case nextKeyboard

    var title: String {
        switch self {
        case .character(let value):
            value.uppercased()
        case .space:
            "space"
        case .delete:
            "delete"
        case .return:
            "return"
        case .nextKeyboard:
            "globe"
        }
    }
}
