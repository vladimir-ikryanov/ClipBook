import AppKit

final class NewTagDialog: NSViewController, NSTextFieldDelegate {
  private let tagColors: [NSColor] = [
    NSColor(srgbRed: 0.23, green: 0.52, blue: 0.93, alpha: 1),
    NSColor(srgbRed: 0.08, green: 0.64, blue: 0.86, alpha: 1),
    NSColor(srgbRed: 0.52, green: 0.84, blue: 0.04, alpha: 1),
    NSColor(srgbRed: 0.13, green: 0.76, blue: 0.39, alpha: 1),
    NSColor(srgbRed: 0.96, green: 0.70, blue: 0.05, alpha: 1),
    NSColor(srgbRed: 1.00, green: 0.45, blue: 0.10, alpha: 1),
    NSColor(srgbRed: 0.93, green: 0.15, blue: 0.15, alpha: 1),
    NSColor(srgbRed: 0.91, green: 0.25, blue: 0.58, alpha: 1),
    NSColor(srgbRed: 0.60, green: 0.29, blue: 0.91, alpha: 1)
  ]
  private var selectedColorIndex = 0
  private var colorButtons: [TagColorButton] = []
  private let settingsGroupView = SettingsGroupView()
  private let dividerView = SettingsGroupDividerView()
  private let inputField = BorderlessSettingsTextField()
  private let createButton = NSButton(title: L10n.string("Create"), target: nil, action: nil)
  private let existingTag: Tag?
  var onCancel: (() -> Void)?
  var onCreate: ((String, NSColor) -> Void)?

  init(tag: Tag? = nil) {
    existingTag = tag
    super.init(nibName: nil, bundle: nil)

    if let tag,
       let color = NSColor(tagHexString: tag.color),
       let colorIndex = Self.closestColorIndex(to: color, in: tagColors) {
      selectedColorIndex = colorIndex
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let rootView = AppearanceUpdatingView(frame: NSRect(x: 0, y: 0, width: 420, height: 168))
    rootView.onEffectiveAppearanceChange = { [weak self] in
      self?.updateColorsForEffectiveAppearance()
    }
    view = rootView
    view.wantsLayer = true
    updateBackgroundColor()

    let fieldFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    let placeholderParagraphStyle = NSMutableParagraphStyle()
    placeholderParagraphStyle.alignment = .right
    inputField.font = fieldFont
    inputField.placeholderAttributedString = NSAttributedString(
      string: L10n.string("Tag name"),
      attributes: [
        .font: fieldFont,
        .foregroundColor: NSColor.placeholderTextColor,
        .paragraphStyle: placeholderParagraphStyle
      ]
    )
    inputField.alignment = .right
    inputField.delegate = self
    inputField.target = self
    inputField.action = #selector(createTag)
    inputField.stringValue = existingTag?.name ?? ""
    inputField.setContentHuggingPriority(.defaultLow, for: .horizontal)
    inputField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    inputField.translatesAutoresizingMaskIntoConstraints = false

    let tagNameLabel = NSTextField(labelWithString: L10n.string("Tag name"))
    tagNameLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
    tagNameLabel.translatesAutoresizingMaskIntoConstraints = false

    let tagColorLabel = NSTextField(labelWithString: L10n.string("Tag color"))
    tagColorLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
    tagColorLabel.translatesAutoresizingMaskIntoConstraints = false

    let colorStack = NSStackView()
    colorStack.orientation = .horizontal
    colorStack.alignment = .centerY
    colorStack.distribution = .equalSpacing
    colorStack.spacing = 0
    colorStack.setContentHuggingPriority(.required, for: .horizontal)
    colorStack.setContentCompressionResistancePriority(.required, for: .horizontal)
    colorStack.translatesAutoresizingMaskIntoConstraints = false

    for (index, color) in tagColors.enumerated() {
      let button = TagColorButton(color: color)
      button.isSelected = index == selectedColorIndex
      button.target = self
      button.action = #selector(selectColor(_:))
      button.tag = index
      colorButtons.append(button)
      colorStack.addArrangedSubview(button)
    }

    let tagNameRow = NSView()
    tagNameRow.translatesAutoresizingMaskIntoConstraints = false

    let tagColorRow = NSView()
    tagColorRow.translatesAutoresizingMaskIntoConstraints = false

    let cancelButton = NSButton(title: L10n.string("Cancel"), target: self, action: #selector(cancel))
    cancelButton.bezelStyle = .rounded
    cancelButton.translatesAutoresizingMaskIntoConstraints = false

    createButton.target = self
    createButton.action = #selector(createTag)
    createButton.title = existingTag == nil ? L10n.string("Create") : L10n.string("Save")
    createButton.bezelStyle = .rounded
    createButton.keyEquivalent = "\r"
    createButton.isEnabled = !trimmedTagName.isEmpty
    createButton.translatesAutoresizingMaskIntoConstraints = false

    let buttonStack = NSStackView(views: [cancelButton, createButton])
    buttonStack.orientation = .horizontal
    buttonStack.spacing = 12
    buttonStack.translatesAutoresizingMaskIntoConstraints = false

    settingsGroupView.translatesAutoresizingMaskIntoConstraints = false
    dividerView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(settingsGroupView)
    view.addSubview(buttonStack)
    settingsGroupView.addSubview(tagNameRow)
    settingsGroupView.addSubview(dividerView)
    settingsGroupView.addSubview(tagColorRow)
    tagNameRow.addSubview(tagNameLabel)
    tagNameRow.addSubview(inputField)
    tagColorRow.addSubview(tagColorLabel)
    tagColorRow.addSubview(colorStack)

    NSLayoutConstraint.activate([
      settingsGroupView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
      settingsGroupView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      settingsGroupView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      settingsGroupView.heightAnchor.constraint(equalToConstant: 86),

      tagNameRow.topAnchor.constraint(equalTo: settingsGroupView.topAnchor),
      tagNameRow.leadingAnchor.constraint(equalTo: settingsGroupView.leadingAnchor),
      tagNameRow.trailingAnchor.constraint(equalTo: settingsGroupView.trailingAnchor),
      tagNameRow.heightAnchor.constraint(equalToConstant: 38),

      dividerView.topAnchor.constraint(equalTo: tagNameRow.bottomAnchor),
      dividerView.leadingAnchor.constraint(equalTo: settingsGroupView.leadingAnchor, constant: 14),
      dividerView.trailingAnchor.constraint(equalTo: settingsGroupView.trailingAnchor, constant: -14),
      dividerView.heightAnchor.constraint(equalToConstant: 0.5),

      tagColorRow.topAnchor.constraint(equalTo: dividerView.bottomAnchor),
      tagColorRow.leadingAnchor.constraint(equalTo: settingsGroupView.leadingAnchor),
      tagColorRow.trailingAnchor.constraint(equalTo: settingsGroupView.trailingAnchor),
      tagColorRow.bottomAnchor.constraint(equalTo: settingsGroupView.bottomAnchor),

      tagNameLabel.leadingAnchor.constraint(equalTo: tagNameRow.leadingAnchor, constant: 16),
      tagNameLabel.centerYAnchor.constraint(equalTo: tagNameRow.centerYAnchor),

      inputField.leadingAnchor.constraint(equalTo: tagNameRow.centerXAnchor),
      inputField.trailingAnchor.constraint(equalTo: tagNameRow.trailingAnchor, constant: -16),
      inputField.centerYAnchor.constraint(equalTo: tagNameRow.centerYAnchor),
      inputField.heightAnchor.constraint(equalToConstant: 24),

      tagColorLabel.leadingAnchor.constraint(equalTo: tagColorRow.leadingAnchor, constant: 16),
      tagColorLabel.centerYAnchor.constraint(equalTo: tagColorRow.centerYAnchor),

      colorStack.leadingAnchor.constraint(greaterThanOrEqualTo: tagColorLabel.trailingAnchor, constant: 20),
      colorStack.trailingAnchor.constraint(equalTo: tagColorRow.trailingAnchor, constant: -8),
      colorStack.centerYAnchor.constraint(equalTo: tagColorRow.centerYAnchor),
      colorStack.heightAnchor.constraint(equalToConstant: 28),

      buttonStack.topAnchor.constraint(equalTo: settingsGroupView.bottomAnchor, constant: 16),
      buttonStack.trailingAnchor.constraint(equalTo: settingsGroupView.trailingAnchor),
      buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14)
    ])
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    view.window?.makeFirstResponder(inputField)
  }

  private func updateColorsForEffectiveAppearance() {
    updateBackgroundColor()
    settingsGroupView.updateColors()
    dividerView.updateColors()
    colorButtons.forEach { $0.needsDisplay = true }
  }

  func controlTextDidChange(_ notification: Notification) {
    createButton.isEnabled = !trimmedTagName.isEmpty
  }

  @objc private func cancel() {
    onCancel?()
  }

  @objc private func createTag() {
    let tagName = trimmedTagName
    guard !tagName.isEmpty else {
      return
    }
    onCreate?(tagName, tagColors[selectedColorIndex])
  }

  @objc private func selectColor(_ sender: TagColorButton) {
    selectedColorIndex = sender.tag
    for (index, button) in colorButtons.enumerated() {
      button.isSelected = index == selectedColorIndex
    }
  }

  private var trimmedTagName: String {
    inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func updateBackgroundColor() {
    var backgroundColor = NSColor.windowBackgroundColor.cgColor
    view.effectiveAppearance.performAsCurrentDrawingAppearance {
      backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    view.layer?.backgroundColor = backgroundColor
  }

  private static func closestColorIndex(to color: NSColor, in colors: [NSColor]) -> Int? {
    guard let target = color.usingColorSpace(.sRGB) else {
      return nil
    }

    return colors.enumerated().min { lhs, rhs in
      colorDistance(lhs.element, target) < colorDistance(rhs.element, target)
    }?.offset
  }

  private static func colorDistance(_ lhs: NSColor, _ rhs: NSColor) -> CGFloat {
    let lhsColor = lhs.usingColorSpace(.sRGB) ?? lhs
    let rhsColor = rhs.usingColorSpace(.sRGB) ?? rhs
    let redDistance = lhsColor.redComponent - rhsColor.redComponent
    let greenDistance = lhsColor.greenComponent - rhsColor.greenComponent
    let blueDistance = lhsColor.blueComponent - rhsColor.blueComponent
    return redDistance * redDistance
      + greenDistance * greenDistance
      + blueDistance * blueDistance
  }
}

private final class AppearanceUpdatingView: NSView {
  var onEffectiveAppearanceChange: (() -> Void)?

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    onEffectiveAppearanceChange?()
  }
}

private final class SettingsGroupView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.cornerRadius = 12
    layer?.masksToBounds = true
    updateColors()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateColors()
  }

  func updateColors() {
    var backgroundColor = NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      return isDark
        ? NSColor(white: 0x1E / 255.0, alpha: 1.0)
        : NSColor(white: 0xF5 / 255.0, alpha: 1.0)
    }.cgColor
    effectiveAppearance.performAsCurrentDrawingAppearance {
      backgroundColor = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
          ? NSColor(white: 0x1E / 255.0, alpha: 1.0)
          : NSColor(white: 0xF5 / 255.0, alpha: 1.0)
      }.cgColor
    }
    layer?.backgroundColor = backgroundColor
  }
}

private final class SettingsGroupDividerView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    updateColors()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateColors()
  }

  func updateColors() {
    var dividerColor = NSColor.separatorColor.cgColor
    effectiveAppearance.performAsCurrentDrawingAppearance {
      dividerColor = NSColor.separatorColor.cgColor
    }
    layer?.backgroundColor = dividerColor
  }
}

private final class BorderlessSettingsTextField: NSTextField {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var focusRingMaskBounds: NSRect {
    .zero
  }

  override func drawFocusRingMask() {}

  private func configure() {
    cell = VerticallyCenteredSettingsTextFieldCell(textCell: "")
    isBordered = false
    isBezeled = false
    drawsBackground = false
    focusRingType = .none
    isEditable = true
    isSelectable = true
    refusesFirstResponder = false
  }
}

private final class VerticallyCenteredSettingsTextFieldCell: NSTextFieldCell {
  override func drawingRect(forBounds rect: NSRect) -> NSRect {
    let textSize = cellSize(forBounds: rect)
    let verticalInset = max(0, floor((rect.height - textSize.height) / 2))
    return rect.insetBy(dx: 0, dy: verticalInset)
  }

  override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
    super.edit(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
  }

  override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
    super.select(
      withFrame: drawingRect(forBounds: rect),
      in: controlView,
      editor: textObj,
      delegate: delegate,
      start: selStart,
      length: selLength
    )
  }
}

private final class TagColorButton: NSButton {
  let color: NSColor
  var isSelected = false {
    didSet {
      needsDisplay = true
    }
  }

  init(color: NSColor) {
    self.color = color
    super.init(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
    isBordered = false
    imagePosition = .imageOnly
    setButtonType(.momentaryChange)
    translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      widthAnchor.constraint(equalToConstant: 28),
      heightAnchor.constraint(equalToConstant: 28)
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    if isSelected {
      NSColor.separatorColor.setStroke()
      let ringRect = bounds.insetBy(dx: 2, dy: 2)
      let ringPath = NSBezierPath(ovalIn: ringRect)
      ringPath.lineWidth = 3
      ringPath.stroke()
    }

    color.setFill()
    let circleRect = bounds.insetBy(dx: isSelected ? 7 : 5, dy: isSelected ? 7 : 5)
    NSBezierPath(ovalIn: circleRect).fill()
  }
}

private extension NSColor {
  convenience init?(tagHexString: String) {
    let hex = tagHexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard hex.count == 6, let value = Int(hex, radix: 16) else {
      return nil
    }

    self.init(
      srgbRed: CGFloat((value >> 16) & 0xFF) / 255.0,
      green: CGFloat((value >> 8) & 0xFF) / 255.0,
      blue: CGFloat(value & 0xFF) / 255.0,
      alpha: 1.0
    )
  }
}
