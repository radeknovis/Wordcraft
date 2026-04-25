import Foundation

struct KeyboardLayout {
    static let qwertyRows: [[KeyboardKey]] = [
        "qwertyuiop".map { .character(String($0)) },
        "asdfghjkl".map { .character(String($0)) },
        "zxcvbnm".map { .character(String($0)) }
    ]

    static let controlRow: [KeyboardKey] = [
        .nextKeyboard,
        .space,
        .delete,
        .return
    ]
}
