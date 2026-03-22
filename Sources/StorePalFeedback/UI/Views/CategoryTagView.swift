import AppKit

/// A small colored pill label showing the feedback category.
@MainActor
final class CategoryTagView: NSView {
    private let label = NSTextField(labelWithString: "")

    var category: String = "other" {
        didSet { update() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 4

        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }

    private func update() {
        let cat = FeedbackCategory(rawValue: category) ?? .other
        label.stringValue = cat.displayName

        let (textColor, bgColor): (NSColor, NSColor) = switch cat {
        case .bug: (.systemRed, .systemRed.withAlphaComponent(0.12))
        case .feature: (.systemPurple, .systemPurple.withAlphaComponent(0.12))
        case .question: (.systemBlue, .systemBlue.withAlphaComponent(0.12))
        case .other: (.secondaryLabelColor, .quaternaryLabelColor)
        }

        label.textColor = textColor
        layer?.backgroundColor = bgColor.cgColor
    }
}
