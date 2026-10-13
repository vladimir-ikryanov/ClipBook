import AppKit

final class PreviewImage: NSView {
  private let imageView = NSImageView()
  private var aspectRatioConstraint: NSLayoutConstraint?

  init(image: NSImage) {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    wantsLayer = true
    layer?.masksToBounds = true
    configure()
    setImage(image)
  }

  /// An empty preview that already takes the shape of the picture it waits
  /// for, so the row lays out once and the image drops in when decoded.
  init(aspectRatioSize: CGSize) {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    wantsLayer = true
    layer?.masksToBounds = true
    configure()
    applyAspectRatio(of: aspectRatioSize)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func setImage(_ image: NSImage) {
    imageView.image = image
    imageView.contentTintColor = nil
    applyAspectRatio(of: image.size)
  }

  func setFallbackImage(_ image: NSImage, tintColor: NSColor) {
    imageView.image = image
    imageView.contentTintColor = tintColor
    applyAspectRatio(of: image.size)
  }

  private func applyAspectRatio(of size: CGSize) {
    if let aspectRatioConstraint {
      NSLayoutConstraint.deactivate([aspectRatioConstraint])
    }
    let aspectRatio = max(size.width, 1) / max(size.height, 1)
    let aspectRatioConstraint = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: aspectRatio)
    self.aspectRatioConstraint = aspectRatioConstraint
    aspectRatioConstraint.isActive = true
  }

  private func configure() {
    imageView.imageScaling = .scaleProportionallyDown
    imageView.wantsLayer = true
    imageView.layer?.cornerRadius = 8
    imageView.layer?.masksToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

    addSubview(imageView)

    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
      imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
      imageView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
      imageView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
      imageView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
      imageView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
      imageView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor)
    ])
  }
}
