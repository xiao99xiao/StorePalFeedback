import AppKit

/// A chat-style message bubble for conversation threads.
@MainActor
final class MessageBubbleView: NSView {
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let bubbleLayer = CALayer()

    let isFromUser: Bool

    init(message: String, sender: String, date: String, isFromUser: Bool) {
        self.isFromUser = isFromUser
        super.init(frame: .zero)

        wantsLayer = true

        // Bubble background
        bubbleLayer.cornerRadius = 12
        bubbleLayer.backgroundColor = isFromUser
            ? NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
            : NSColor.quaternaryLabelColor.cgColor
        layer?.insertSublayer(bubbleLayer, at: 0)

        // Message
        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = .labelColor
        messageLabel.maximumNumberOfLines = 0
        messageLabel.stringValue = message
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageLabel)

        // Sender + time
        metaLabel.font = .systemFont(ofSize: 10)
        metaLabel.textColor = .tertiaryLabelColor
        metaLabel.stringValue = "\(sender) \u{00B7} \(date)"
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metaLabel)

        let padding: CGFloat = 12
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 280),

            metaLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            metaLabel.leadingAnchor.constraint(equalTo: messageLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: messageLabel.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        bubbleLayer.frame = bounds
    }
}
