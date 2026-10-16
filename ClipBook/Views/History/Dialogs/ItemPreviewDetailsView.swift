import AppKit
import ImageIO

// Floating glass panel shown over the bottom edge of the item preview. The
// fields are centered in a single row and wrap onto additional lines whenever
// the dialog is too narrow to fit them all, in which case the panel grows
// taller and its capsule corners are capped so it still reads as a panel.
// The preview pane of the history window shows the same fields docked along
// its bottom edge instead, as a part of the pane.
@MainActor
final class ItemPreviewDetailsView: NSView {
  enum Style {
    /// A glass capsule floating over the bottom of the preview sheet.
    case floating
    /// A plain bar along the bottom of the preview pane, set apart from the
    /// preview above it by a line, with its fields centered.
    case docked
  }

  /// How the docked details are set out: the fields next to each other,
  /// wrapping onto more lines as needed, or one field per row, its title on
  /// the left and its value on the right, the rows shaded in turn. The pane
  /// lists them while it sits beside the history and has the height for it.
  enum Arrangement {
    case inline
    case list
  }

  var arrangement: Arrangement = .inline {
    didSet {
      guard arrangement != oldValue else {
        return
      }
      updateTopSeparatorVisibility()
      rebuild(for: item)
    }
  }

  /// Whether the docked bar draws the line that sets it apart from the
  /// preview. The pane leaves it out while it shows the details alone.
  var showsTopSeparator = true {
    didSet {
      updateTopSeparatorVisibility()
    }
  }

  // The gap between the panel and the bottom edge of the preview it floats
  // over, and the wider gap kept on each side so the panel never hugs the
  // window border.
  static let floatingMargin: CGFloat = 20
  static let horizontalFloatingMargin: CGFloat = 40
  private static let horizontalInset: CGFloat = 24
  private static let verticalInset: CGFloat = 10
  private static let dockedHorizontalInset: CGFloat = 12
  private static let dockedVerticalInset: CGFloat = 12
  private static let maximumCornerRadius: CGFloat = 24
  // The gap on each side of a separator, so neighbouring fields are kept
  // visually apart rather than reading as one run of text. The bar of the
  // history window sits in a narrow pane, so it keeps its fields closer.
  private static let fieldSpacing: CGFloat = 12
  private static let dockedFieldSpacing: CGFloat = 8
  private static let lineSpacing: CGFloat = 8
  private static let separatorWidth: CGFloat = 1
  private static let titleValueSpacing: CGFloat = 1
  private static let appIconSize: CGFloat = 14
  private static let appIconSpacing: CGFloat = 4
  private static let listRowHeight: CGFloat = 24
  private static let listHorizontalInset: CGFloat = 10
  private static let listTopInset: CGFloat = 6
  private static let listBottomInset: CGFloat = 10

  // Fields whose value follows the editor while the item is being edited.
  private enum FieldKey {
    case characters
    case size
  }

  private struct Field {
    let title: String
    let value: String
    var icon: NSImage?
    var key: FieldKey?
    // An icon can stand for the value, which then shows only in the tooltip.
    var showsValue: Bool

    init(title: String, value: String, icon: NSImage? = nil, key: FieldKey? = nil, showsValue: Bool = true) {
      self.title = title
      self.value = value
      self.icon = icon
      self.key = key
      self.showsValue = showsValue
    }
  }

  // A row of fields that fit next to each other, together with the width they
  // occupy, so the row can be centered once the packing is known.
  private struct FieldLine {
    var indices: [Int] = []
    var width: CGFloat = 0
  }

  private var fieldViews: [NSView] = []
  private var separatorViews: [NSView] = []
  private var valueFieldsByKey: [FieldKey: NSTextField] = [:]
  private var contentHeight: CGFloat = 0
  // The translucent capsule behind the fields: real glass where the system
  // offers it, a blurred material elsewhere.
  private let backdropView: NSView
  // The fields are laid out top-down, so they live in a flipped container
  // rather than in the panel itself.
  private let fieldsView = ItemPreviewDetailsFieldsView()
  private let style: Style
  private var item: ClipboardItem
  // The line between the docked bar and the preview above it.
  private var topSeparatorView: NSView?

  init(item: ClipboardItem, style: Style = .floating) {
    self.style = style
    self.item = item
    backdropView = style == .floating
      ? Self.makeBackdropView(contentView: fieldsView)
      : Self.makeDockedBackgroundView(contentView: fieldsView)
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    wantsLayer = true
    // Kept in front of whichever preview is installed under it.
    layer?.zPosition = 1
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
    // The panel shrinks to the dialog and wraps its fields rather than
    // forcing the dialog wider, so the width must be allowed to give way.
    setContentHuggingPriority(.required, for: .horizontal)
    setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    backdropView.autoresizingMask = [.width, .height]
    addSubview(backdropView)
    if style == .docked {
      let separatorView = ItemPreviewDetailsSeparatorView()
      addSubview(separatorView)
      topSeparatorView = separatorView
    }
    rebuild(for: item)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // The docked bar spans the pane, so only its height comes from the fields.
  override var intrinsicContentSize: NSSize {
    NSSize(
      width: style == .floating ? preferredWidth : NSView.noIntrinsicMetric,
      height: contentHeight
    )
  }

  // Tooltips are the only thing the panel reacts to, and only over its fields,
  // so a click on the translucent margin still goes to the preview below.
  override func hitTest(_ point: NSPoint) -> NSView? {
    guard let hitView = super.hitTest(point), hitView !== fieldsView,
          hitView.isDescendant(of: fieldsView) else {
      return nil
    }
    return hitView
  }

  func update(item: ClipboardItem) {
    self.item = item
    rebuild(for: item)
  }

  // The shaded rows of the list set it apart well enough on their own.
  private func updateTopSeparatorVisibility() {
    topSeparatorView?.isHidden = !showsTopSeparator || arrangement == .list
  }

  // While the item is being edited the committed values are stale, so the
  // length of the text in the editor is shown instead.
  func showLength(of text: String) {
    valueFieldsByKey[.characters]?.stringValue = Self.numberString(text.count)
    valueFieldsByKey[.size]?.stringValue = Self.sizeString(byteCount: text.utf8.count)
    for (_, valueField) in valueFieldsByKey {
      valueField.superview?.toolTip = valueField.stringValue
    }
    // The values change width, so the panel has to be resized and the row
    // packed and centered again.
    invalidateIntrinsicContentSize()
    needsLayout = true
  }

  // The vertical room the floating panel needs over a preview of the given
  // width: the panel itself plus the margin above and below it.
  func reservedHeight(forWidth width: CGFloat) -> CGFloat {
    preferredHeight(forWidth: width - Self.horizontalFloatingMargin * 2) + Self.floatingMargin * 2
  }

  // The dialog needs the height before the view is placed in the window, so the
  // wrapping has to be measurable for an arbitrary width.
  func preferredHeight(forWidth width: CGFloat) -> CGFloat {
    layOutFields(inWidth: width, applyingFrames: false)
  }

  // The width at which all fields fit on a single line. The dialog uses it to
  // widen itself instead of letting the fields wrap.
  var preferredWidth: CGFloat {
    guard !fieldViews.isEmpty else {
      return 0
    }

    let fieldsWidth = fieldViews.reduce(0) { $0 + $1.fittingSize.width }
    let separatorsWidth = CGFloat(separatorViews.count) * separatorSpan
    return fieldsWidth + separatorsWidth + horizontalInset * 2
  }

  private var horizontalInset: CGFloat {
    style == .floating ? Self.horizontalInset : Self.dockedHorizontalInset
  }

  private var verticalInset: CGFloat {
    style == .floating ? Self.verticalInset : Self.dockedVerticalInset
  }

  private var fieldSpacing: CGFloat {
    style == .floating ? Self.fieldSpacing : Self.dockedFieldSpacing
  }

  // The room a separator takes between two fields on the same line.
  private var separatorSpan: CGFloat {
    fieldSpacing * 2 + Self.separatorWidth
  }

  override func layout() {
    super.layout()

    backdropView.frame = bounds
    fieldsView.frame = backdropView.bounds
    let height = layOutFields(inWidth: bounds.width, applyingFrames: true)
    if style == .floating {
      Self.applyCornerRadius(min(height / 2, Self.maximumCornerRadius), to: backdropView)
    }
    if let topSeparatorView {
      let lineWidth = 1 / (window?.backingScaleFactor ?? 2)
      topSeparatorView.frame = NSRect(x: 0, y: bounds.height - lineWidth, width: bounds.width, height: lineWidth)
    }
    guard abs(height - contentHeight) > 0.5 else {
      return
    }

    contentHeight = height
    invalidateIntrinsicContentSize()
  }

  // MARK: - Layout

  // Returns the height the fields need for the given width, optionally moving
  // the field and separator views into place while measuring them.
  @discardableResult
  private func layOutFields(inWidth width: CGFloat, applyingFrames: Bool) -> CGFloat {
    guard !fieldViews.isEmpty else {
      return 0
    }

    if arrangement == .list {
      return layOutRows(inWidth: width, applyingFrames: applyingFrames)
    }

    let availableWidth = max(1, width - horizontalInset * 2)
    let fieldSizes = fieldViews.map(\.fittingSize)
    let lineHeight = fieldSizes.map(\.height).max() ?? 0
    let lines = Self.packLines(fieldSizes: fieldSizes, availableWidth: availableWidth, separatorSpan: separatorSpan)

    if applyingFrames {
      var originY = verticalInset
      for line in lines {
        var originX = horizontalInset + max(0, (availableWidth - line.width) / 2)
        for index in line.indices {
          if index > 0 {
            let separatorView = separatorViews[index - 1]
            separatorView.isHidden = index == line.indices.first
            if !separatorView.isHidden {
              separatorView.frame = NSRect(
                x: originX + fieldSpacing,
                y: originY,
                width: Self.separatorWidth,
                height: lineHeight
              )
              originX += separatorSpan
            }
          }

          fieldViews[index].frame = NSRect(
            x: originX,
            y: originY,
            width: min(fieldSizes[index].width, availableWidth),
            height: lineHeight
          )
          originX += fieldSizes[index].width
        }
        originY += lineHeight + Self.lineSpacing
      }
    }

    let linesHeight = CGFloat(lines.count) * lineHeight
      + CGFloat(lines.count - 1) * Self.lineSpacing
    return linesHeight + verticalInset * 2
  }

  // One row per field, as wide as the bar allows, stacked top-down.
  private func layOutRows(inWidth width: CGFloat, applyingFrames: Bool) -> CGFloat {
    if applyingFrames {
      let rowWidth = max(0, width - Self.listHorizontalInset * 2)
      for (index, rowView) in fieldViews.enumerated() {
        rowView.frame = NSRect(
          x: Self.listHorizontalInset,
          y: Self.listTopInset + CGFloat(index) * Self.listRowHeight,
          width: rowWidth,
          height: Self.listRowHeight
        )
      }
    }

    return CGFloat(fieldViews.count) * Self.listRowHeight + Self.listTopInset + Self.listBottomInset
  }

  // Greedily packs the fields into lines that fit the available width.
  private static func packLines(fieldSizes: [NSSize], availableWidth: CGFloat, separatorSpan: CGFloat) -> [FieldLine] {
    var lines: [FieldLine] = []
    var line = FieldLine()

    for index in fieldSizes.indices {
      let fieldWidth = fieldSizes[index].width
      if !line.indices.isEmpty, line.width + separatorSpan + fieldWidth > availableWidth {
        lines.append(line)
        line = FieldLine()
      }

      line.width += (line.indices.isEmpty ? 0 : separatorSpan) + fieldWidth
      line.indices.append(index)
    }

    if !line.indices.isEmpty {
      lines.append(line)
    }
    return lines
  }

  // MARK: - Backdrop

  private static func makeBackdropView(contentView: NSView) -> NSView {
    if #available(macOS 26.0, *) {
      let glassView = NSGlassEffectView()
      glassView.contentView = contentView
      return glassView
    }

    let effectView = NSVisualEffectView()
    effectView.material = .hudWindow
    effectView.blendingMode = .withinWindow
    effectView.state = .active
    effectView.wantsLayer = true
    effectView.layer?.masksToBounds = true
    contentView.autoresizingMask = [.width, .height]
    effectView.addSubview(contentView)
    return effectView
  }

  // The docked bar sits on the pane's own background, so it needs no
  // material of its own.
  private static func makeDockedBackgroundView(contentView: NSView) -> NSView {
    let backgroundView = NSView()
    contentView.autoresizingMask = [.width, .height]
    backgroundView.addSubview(contentView)
    return backgroundView
  }

  private static func applyCornerRadius(_ radius: CGFloat, to backdropView: NSView) {
    if #available(macOS 26.0, *), let glassView = backdropView as? NSGlassEffectView {
      glassView.cornerRadius = radius
    } else {
      backdropView.layer?.cornerRadius = radius
    }
  }

  // MARK: - Building

  private func rebuild(for item: ClipboardItem) {
    fieldViews.forEach { $0.removeFromSuperview() }
    separatorViews.forEach { $0.removeFromSuperview() }
    fieldViews = []
    separatorViews = []

    valueFieldsByKey = [:]
    // The history row already shows the source app of the item next to it,
    // so the pane of the history window leaves it out of its details.
    let fields = Self.fields(for: item, includesSource: style == .floating)
    if arrangement == .list {
      for (index, field) in fields.enumerated() {
        let rowView = ItemPreviewDetailsListRowView(
          title: field.title,
          value: field.value,
          icon: field.icon,
          isShaded: index.isMultiple(of: 2)
        )
        if let key = field.key {
          valueFieldsByKey[key] = rowView.valueField
        }
        fieldsView.addSubview(rowView)
        fieldViews.append(rowView)
      }
      needsLayout = true
      contentHeight = preferredHeight(forWidth: bounds.width)
      invalidateIntrinsicContentSize()
      return
    }

    for (index, field) in fields.enumerated() {
      if index > 0 {
        let separatorView = ItemPreviewDetailsSeparatorView()
        fieldsView.addSubview(separatorView)
        separatorViews.append(separatorView)
      }

      let (fieldView, valueField) = Self.makeFieldView(field)
      if let key = field.key {
        valueFieldsByKey[key] = valueField
      }
      fieldsView.addSubview(fieldView)
      fieldViews.append(fieldView)
    }

    needsLayout = true
    // Measured for the unwrapped width, so the panel has a height before it
    // is ever laid out; layout() corrects it once the fields wrap.
    contentHeight = preferredHeight(forWidth: preferredWidth)
    invalidateIntrinsicContentSize()
  }

  private static func makeFieldView(_ field: Field) -> (view: NSView, valueField: NSTextField) {
    // The value is the prominent line and the title the quieter caption
    // under it.
    let valueField = NSTextField(labelWithString: field.value)
    valueField.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
    valueField.textColor = .labelColor
    valueField.alignment = .natural
    valueField.lineBreakMode = .byTruncatingTail

    let titleField = NSTextField(labelWithString: field.title)
    titleField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    titleField.textColor = .secondaryLabelColor
    titleField.alignment = .natural
    titleField.lineBreakMode = .byTruncatingTail

    var valueView: NSView = valueField
    if let icon = field.icon {
      let iconView = NSImageView()
      iconView.image = icon
      iconView.setAccessibilityLabel(field.value)
      iconView.imageScaling = .scaleProportionallyDown
      iconView.translatesAutoresizingMaskIntoConstraints = false
      iconView.setContentHuggingPriority(.required, for: .horizontal)
      iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
      NSLayoutConstraint.activate([
        iconView.widthAnchor.constraint(equalToConstant: Self.appIconSize),
        iconView.heightAnchor.constraint(equalToConstant: Self.appIconSize)
      ])

      let valueStack = NSStackView(views: field.showsValue ? [iconView, valueField] : [iconView])
      valueStack.orientation = .horizontal
      valueStack.distribution = .fill
      valueStack.alignment = .centerY
      valueStack.spacing = Self.appIconSpacing
      valueView = valueStack
    }

    let fieldStack = NSStackView(views: [valueView, titleField])
    fieldStack.orientation = .vertical
    fieldStack.distribution = .fill
    fieldStack.alignment = .leading
    fieldStack.spacing = Self.titleValueSpacing
    // Long values are truncated to keep the bar compact, so the full value has
    // to stay reachable.
    fieldStack.toolTip = field.value
    return (fieldStack, valueField)
  }

  // MARK: - Fields

  private static func fields(for item: ClipboardItem, includesSource: Bool) -> [Field] {
    var fields = [Field(title: L10n.string("Type"), value: typeName(for: item))]
    fields.append(contentsOf: contentFields(for: item))
    fields.append(
      Field(
        title: L10n.string("Size"),
        value: sizeString(byteCount: item.byteSize),
        key: .size
      )
    )
    if includesSource, let sourceApplicationField = applicationField(for: item) {
      fields.append(sourceApplicationField)
    }
    let firstCopyDate = dateString(item.firstCopiedAt)
    let lastCopyDate = dateString(item.copiedAt)
    // Copied again within the same minute, the last copy would read the same,
    // so a single date says when the item was copied.
    if lastCopyDate == firstCopyDate {
      // Keyed apart from the "Copied" confirmation, which some languages word
      // as a message rather than a label.
      fields.append(Field(title: L10n.string(forKey: "Copied (date)"), value: firstCopyDate))
    } else {
      fields.append(Field(title: L10n.string("First Copied"), value: firstCopyDate))
      fields.append(Field(title: L10n.string("Last Copied"), value: lastCopyDate))
    }
    fields.append(
      Field(title: L10n.string("Copies"), value: numberString(item.copyCount + 1))
    )
    return fields
  }

  // The leading field describes the payload itself and therefore depends on the
  // kind of the item: pixels for images, characters for everything text based
  // and nothing at all for files, whose size already says it all.
  private static func contentFields(for item: ClipboardItem) -> [Field] {
    switch item.kind {
    case .image:
      guard let dimensions = item.imageDimensions else {
        return []
      }
      return [dimensionsField(width: dimensions.width, height: dimensions.height)]
    case .file:
      guard item.filePaths.count == 1,
            let filePath = item.filePaths.first,
            ClipboardItem.isImageFile(at: filePath),
            let dimensions = imageDimensions(atPath: filePath) else {
        return []
      }
      return [dimensionsField(width: dimensions.width, height: dimensions.height)]
    case .text, .richText, .link, .email, .color:
      return [
        Field(
          title: L10n.string("Characters"),
          value: numberString(item.previewText.count),
          key: .characters
        )
      ]
    }
  }

  // The kind of the item, with the plural name for a multiple file item.
  static func typeName(for item: ClipboardItem) -> String {
    if item.kind == .file, item.filePaths.count > 1 {
      return L10n.string("Files")
    }
    return item.kind.title
  }

  private static func dimensionsField(width: Int, height: Int) -> Field {
    Field(
      title: L10n.string("Dimensions"),
      value: "\(numberString(width)) × \(numberString(height))"
    )
  }

  private static func applicationField(for item: ClipboardItem) -> Field? {
    guard item.hasSourceApp else {
      return nil
    }

    let icon = HistorySourceAppIcon.image(
      bundleIdentifier: item.sourceBundleIdentifier,
      appName: item.sourceAppName,
      size: appIconSize
    )
    // The icon alone names the application, which saves room for the other
    // fields; its name stays in the tooltip. Without an icon the name is shown.
    return Field(
      title: L10n.string("Source"),
      value: item.sourceAppName ?? item.sourceBundleIdentifier ?? "",
      icon: icon,
      showsValue: icon == nil
    )
  }

  private static func imageDimensions(atPath filePath: String) -> (width: Int, height: Int)? {
    let fileURL = URL(fileURLWithPath: filePath)
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else {
      return nil
    }

    return (width, height)
  }

  // MARK: - Formatting

  private static let dateFormatter = DateFormatter()
  private static let numberFormatter = NumberFormatter()

  private static func dateString(_ date: Date) -> String {
    // The formatters are rebuilt lazily because the app language can change
    // while it is running.
    dateFormatter.locale = L10n.currentLocale
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short
    return dateFormatter.string(from: date)
  }

  private static func sizeString(byteCount: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
  }

  private static func numberString(_ value: Int) -> String {
    numberFormatter.locale = L10n.currentLocale
    numberFormatter.numberStyle = .decimal
    return numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
  }
}

// A row of the details listed one per row: the title on the left in the
// quieter color, the value on the right. Every other row is shaded, so the
// eye can follow a title across to its value.
private final class ItemPreviewDetailsListRowView: NSView {
  private static let horizontalPadding: CGFloat = 6
  private static let titleValueSpacing: CGFloat = 12
  private static let iconSize: CGFloat = 14
  private static let iconSpacing: CGFloat = 4
  private static let cornerRadius: CGFloat = 7

  let valueField: NSTextField
  private let titleField: NSTextField
  private let iconView: NSImageView?
  private let isShaded: Bool

  init(title: String, value: String, icon: NSImage?, isShaded: Bool) {
    titleField = NSTextField(labelWithString: title)
    titleField.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
    titleField.textColor = .secondaryLabelColor
    titleField.lineBreakMode = .byTruncatingTail

    valueField = NSTextField(labelWithString: value)
    valueField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    valueField.textColor = .labelColor
    valueField.alignment = .right
    valueField.lineBreakMode = .byTruncatingTail

    if let icon {
      let iconView = NSImageView()
      iconView.image = icon
      iconView.imageScaling = .scaleProportionallyDown
      self.iconView = iconView
    } else {
      iconView = nil
    }
    self.isShaded = isShaded
    super.init(frame: .zero)
    wantsLayer = true
    layer?.cornerRadius = Self.cornerRadius
    layer?.cornerCurve = .continuous
    addSubview(titleField)
    addSubview(valueField)
    iconView.map(addSubview)
    // Values are truncated when the pane is narrow, so the full value has to
    // stay reachable.
    toolTip = value
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var wantsUpdateLayer: Bool {
    true
  }

  override func updateLayer() {
    guard isShaded else {
      layer?.backgroundColor = nil
      return
    }

    var color = NSColor.alternatingContentBackgroundColors.last?.cgColor
    effectiveAppearance.performAsCurrentDrawingAppearance {
      color = NSColor.alternatingContentBackgroundColors.last?.cgColor
    }
    layer?.backgroundColor = color
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  // The title keeps its width; the value takes what is left and gives way
  // first when there is not enough.
  override func layout() {
    super.layout()

    let contentWidth = max(0, bounds.width - Self.horizontalPadding * 2)
    let titleSize = titleField.fittingSize
    let titleWidth = min(titleSize.width, contentWidth)
    titleField.frame = NSRect(
      x: Self.horizontalPadding,
      y: (bounds.height - titleSize.height) / 2,
      width: titleWidth,
      height: titleSize.height
    ).integral

    let iconRoom = iconView == nil ? 0 : Self.iconSize + Self.iconSpacing
    let valueSize = valueField.fittingSize
    let valueWidth = max(0, min(valueSize.width, contentWidth - titleWidth - Self.titleValueSpacing - iconRoom))
    let valueMaxX = bounds.width - Self.horizontalPadding
    valueField.frame = NSRect(
      x: valueMaxX - valueWidth,
      y: (bounds.height - valueSize.height) / 2,
      width: valueWidth,
      height: valueSize.height
    ).integral
    iconView?.frame = NSRect(
      x: valueField.frame.minX - Self.iconSpacing - Self.iconSize,
      y: (bounds.height - Self.iconSize) / 2,
      width: Self.iconSize,
      height: Self.iconSize
    ).integral
  }
}

// Holds the fields in top-down order inside the glass backdrop.
private final class ItemPreviewDetailsFieldsView: NSView {
  override var isFlipped: Bool {
    true
  }
}

// Layer backed rather than drawn: filling the dirty rect from draw(_:) is
// composited over the whole dialog on macOS 26, and every separator then
// darkens the dialog by the translucent separator color.
private final class ItemPreviewDetailsSeparatorView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var wantsUpdateLayer: Bool {
    true
  }

  // Resolved here so the separator follows the system appearance when it
  // switches between light and dark.
  override func updateLayer() {
    layer?.backgroundColor = NSColor.separatorColor.cgColor
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }
}
