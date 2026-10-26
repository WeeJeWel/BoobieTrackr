import SwiftUI

enum Palette {
    static let background = Color(red: 0.075, green: 0.059, blue: 0.064)
    static let surface = Color(red: 0.13, green: 0.105, blue: 0.115)
    static let elevated = Color(red: 0.19, green: 0.145, blue: 0.155)
    static let accent = Color(red: 240.0 / 255, green: 105.0 / 255, blue: 146.0 / 255)
    static let cream = Color(red: 1.0, green: 0.91, blue: 0.84)
    static let muted = Color(red: 0.66, green: 0.57, blue: 0.58)
}

extension FeedingKind {
    var image: Image {
        self == .bottle ? Image(systemName: symbol) : Image(symbol)
    }
}

struct FeedingEventSymbol: View {
    let kind: FeedingKind
    var side: FeedingSide? = nil
    var size: CGFloat = 24
    var selectedColor: Color = Palette.accent

    var body: some View {
        ZStack {
            if kind != .breast {
                kind.image.resizable().scaledToFit()
            } else {
                Image(side == .right ? "BreastLeftInactive" : "BreastLeft").resizable().scaledToFit()
                    .foregroundStyle(selectedColor)
                Image(side == .left ? "BreastRightInactive" : "BreastRight").resizable().scaledToFit()
                    .foregroundStyle(selectedColor)
            }
        }
        .frame(width: size, height: size)
    }
}

struct FeedingIcon: View {
    let kind: FeedingKind
    var side: FeedingSide? = nil
    var body: some View {
        FeedingEventSymbol(kind: kind, side: side)
            .foregroundStyle(Palette.accent)
            .frame(width: 48, height: 48)
            .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityHidden(true)
    }
}
