import AppKit

/// A link as its page describes itself for sharing: the page picture, title and description.
/// The preview pane of the history window is usually too small to lay a page out in, so it
/// shows this card instead of loading the page.
final class LinkPreviewCardView: NSView {
  enum Layout {
    /// The picture across the top and the text under it, for a pane beside the list,
    /// which is tall and narrow. The card is as tall as its content.
    case vertical
    /// The picture on the left, as tall as the card, and the text next to it, for a pane
    /// under the list, which is wide but short. The card fills the room it is given.
    case horizontal
  }

  // The shape pages make their sharing picture in (1200 × 630), so most pictures fill the
  // box without being cropped.
  private static let imageAspectRatio: CGFloat = 1200 / 630
  // Next to the text, the picture never takes more than this share of the card.
  private static let maximumHorizontalImageShare: CGFloat = 0.6
  private static let cornerRadius: CGFloat = 10
  // The text lines up with the titles of the details listed under the card.
  private static let verticalTextInsets = NSEdgeInsets(top: 10, left: 6, bottom: 12, right: 6)
  private static let horizontalTextInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 10)
  private static let textSpacing: CGFloat = 4
  // Pictures are decoded for the widest the pane lets the card get.
  private static let imageDecodeSize = CGSize(width: 640, height: 640 / imageAspectRatio)
  private static let placeholderIconSize: CGFloat = 32

  private let imageBox = LinkPreviewCardImageBox()
  private let imageView = LinkPreviewCardImageView()
  private let placeholderView = NSImageView()
  private let titleField = LinkPreviewCardView.makeWrappingField(
    font: .systemFont(ofSize: 13, weight: .semibold),
    color: .labelColor,
    maximumNumberOfLines: 3
  )
  private let descriptionField = LinkPreviewCardView.makeWrappingField(
    font: .systemFont(ofSize: 12),
    color: .secondaryLabelColor,
    maximumNumberOfLines: 4
  )
  private let textStack = NSStackView()
  private let textInsets: NSEdgeInsets
  private var imageURL: URL?
  private var faviconURL: URL?

  init(preview: LinkPreview, layout: Layout) {
    imageURL = preview.imageURL
    faviconURL = preview.faviconURL
    textInsets = layout == .vertical ? Self.verticalTextInsets : Self.horizontalTextInsets
    super.init(frame: .zero)
    wantsLayer = true
    layer?.cornerRadius = Self.cornerRadius
    layer?.masksToBounds = true
    toolTip = preview.url.absoluteString

    // The box keeps its place whether or not the page has a picture, so every card has the
    // same shape. Until the picture is decoded, and when there is none, it shows a placeholder.
    imageBox.translatesAutoresizingMaskIntoConstraints = false
    addSubview(imageBox)
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.isHidden = true
    imageBox.addSubview(imageView)
    placeholderView.translatesAutoresizingMaskIntoConstraints = false
    placeholderView.imageScaling = .scaleProportionallyUpOrDown
    placeholderView.image = Self.placeholderSymbol
    placeholderView.contentTintColor = .tertiaryLabelColor
    imageBox.addSubview(placeholderView)
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: imageBox.topAnchor),
      imageView.bottomAnchor.constraint(equalTo: imageBox.bottomAnchor),
      imageView.leadingAnchor.constraint(equalTo: imageBox.leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: imageBox.trailingAnchor),
      placeholderView.centerXAnchor.constraint(equalTo: imageBox.centerXAnchor),
      placeholderView.centerYAnchor.constraint(equalTo: imageBox.centerYAnchor),
      placeholderView.widthAnchor.constraint(equalToConstant: Self.placeholderIconSize),
      placeholderView.heightAnchor.constraint(equalToConstant: Self.placeholderIconSize)
    ])

    textStack.orientation = .vertical
    textStack.alignment = .leading
    textStack.spacing = Self.textSpacing
    textStack.edgeInsets = textInsets
    textStack.translatesAutoresizingMaskIntoConstraints = false
    if let title = preview.title {
      titleField.stringValue = title
      textStack.addArrangedSubview(titleField)
    }
    if let description = preview.description {
      descriptionField.stringValue = description
      textStack.addArrangedSubview(descriptionField)
    }
    let hasText = !textStack.arrangedSubviews.isEmpty
    if hasText {
      addSubview(textStack)
    }

    switch layout {
    case .vertical:
      NSLayoutConstraint.activate([
        imageBox.topAnchor.constraint(equalTo: topAnchor),
        imageBox.leadingAnchor.constraint(equalTo: leadingAnchor),
        imageBox.trailingAnchor.constraint(equalTo: trailingAnchor),
        imageBox.heightAnchor.constraint(equalTo: imageBox.widthAnchor, multiplier: 1 / Self.imageAspectRatio)
      ])
      if hasText {
        NSLayoutConstraint.activate([
          textStack.topAnchor.constraint(equalTo: imageBox.bottomAnchor),
          textStack.leadingAnchor.constraint(equalTo: leadingAnchor),
          textStack.trailingAnchor.constraint(equalTo: trailingAnchor),
          textStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
      } else {
        imageBox.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
      }
    case .horizontal:
      // The picture is as tall as the card, and as wide as its shape asks for, unless that
      // leaves the text too little room: then it is cropped to the narrower box.
      let naturalWidth = imageBox.widthAnchor.constraint(
        equalTo: imageBox.heightAnchor,
        multiplier: Self.imageAspectRatio
      )
      naturalWidth.priority = .defaultHigh
      NSLayoutConstraint.activate([
        imageBox.topAnchor.constraint(equalTo: topAnchor),
        imageBox.bottomAnchor.constraint(equalTo: bottomAnchor),
        imageBox.leadingAnchor.constraint(equalTo: leadingAnchor),
        imageBox.widthAnchor.constraint(
          lessThanOrEqualTo: widthAnchor,
          multiplier: hasText ? Self.maximumHorizontalImageShare : 1
        ),
        naturalWidth
      ])
      if hasText {
        // The card is only as tall as the pane, so the text gives way at the bottom: the
        // description loses lines before the title does.
        textStack.setClippingResistancePriority(.defaultLow, for: .vertical)
        titleField.setContentCompressionResistancePriority(.defaultLow + 10, for: .vertical)
        descriptionField.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        NSLayoutConstraint.activate([
          textStack.topAnchor.constraint(equalTo: topAnchor),
          textStack.leadingAnchor.constraint(equalTo: imageBox.trailingAnchor),
          textStack.trailingAnchor.constraint(equalTo: trailingAnchor),
          textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
      } else {
        imageBox.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
      }
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var wantsUpdateLayer: Bool {
    true
  }

  override func updateLayer() {
    effectiveAppearance.performAsCurrentDrawingAppearance {
      layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.04).cgColor
    }
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  // A page without a picture is shown by its site icon, or by a globe when it has none.
  private static var placeholderSymbol: NSImage? {
    NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?
      .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: placeholderIconSize, weight: .light))
  }

  // The pictures are decoded once the card knows the screen it is on. The site icon is
  // needed only when the page has no picture, or when its picture cannot be read.
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard let window, imageView.image == nil else {
      return
    }

    let scale = window.backingScaleFactor
    if let imageURL {
      loadImage(at: imageURL, displaySize: Self.imageDecodeSize, scale: scale) { [weak self] image in
        if let image {
          self?.showImage(image)
        } else {
          self?.loadFavicon(scale: scale)
        }
      }
    } else {
      loadFavicon(scale: scale)
    }
  }

  private func loadFavicon(scale: CGFloat) {
    guard let faviconURL else {
      return
    }

    let displaySize = CGSize(width: Self.placeholderIconSize, height: Self.placeholderIconSize)
    loadImage(at: faviconURL, displaySize: displaySize, scale: scale) { [weak self] favicon in
      guard let self, let favicon else {
        return
      }
      self.placeholderView.image = favicon
      self.placeholderView.contentTintColor = nil
    }
  }

  private func loadImage(
    at url: URL,
    displaySize: CGSize,
    scale: CGFloat,
    completion: @escaping (NSImage?) -> Void
  ) {
    let maximumPixelSize = ImageAssetThumbnailLoader.maximumPixelSize(forDisplaySize: displaySize, scale: scale)
    let cachedImage = ImageAssetThumbnailLoader.shared.thumbnail(
      for: url,
      maximumPixelSize: maximumPixelSize,
      completion: completion
    )
    if let cachedImage {
      completion(cachedImage)
    }
  }

  private func showImage(_ image: NSImage) {
    imageView.image = image
    imageView.isHidden = false
    placeholderView.isHidden = true
  }

  // Wrapping labels report their height for the width they were last given, so they are
  // given the width of the text before the card settles its own height.
  override func layout() {
    super.layout()
    let textWidth = max(0, textStack.frame.width - textInsets.left - textInsets.right)
    var changed = false
    for field in [titleField, descriptionField] where abs(field.preferredMaxLayoutWidth - textWidth) > 0.5 {
      field.preferredMaxLayoutWidth = textWidth
      changed = true
    }
    if changed {
      super.layout()
    }
  }

  private static func makeWrappingField(font: NSFont, color: NSColor, maximumNumberOfLines: Int) -> NSTextField {
    let field = NSTextField(wrappingLabelWithString: "")
    field.font = font
    field.textColor = color
    field.maximumNumberOfLines = maximumNumberOfLines
    field.lineBreakMode = .byWordWrapping
    field.cell?.truncatesLastVisibleLine = true
    field.isSelectable = false
    field.setContentCompressionResistancePriority(.required, for: .vertical)
    field.setContentHuggingPriority(.defaultLow, for: .horizontal)
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return field
  }
}

// The room for the page picture. It clips the picture, which is drawn to fill it and so
// often reaches past its edges, and holds the placeholder while there is no picture.
private final class LinkPreviewCardImageBox: NSView {
  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    layer?.masksToBounds = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var wantsUpdateLayer: Bool {
    true
  }

  override func updateLayer() {
    effectiveAppearance.performAsCurrentDrawingAppearance {
      layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
    }
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }
}

// Sized by the card alone: the size of the picture must never widen the card or the pane.
private final class LinkPreviewCardImageView: LinkPreviewAspectFillImageView {
  override init(frame: NSRect) {
    super.init(frame: frame)
    // The picture is drawn to fill the view and is cut to it, never drawn over the text.
    wantsLayer = true
    layer?.masksToBounds = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
  }
}
