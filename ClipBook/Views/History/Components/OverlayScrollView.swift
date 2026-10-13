import AppKit

/// A scroll view whose scroller shows only while the content scrolls. AppKit
/// otherwise follows the system's scroller style, which before macOS 26 keeps a
/// legacy scroller on screen whenever a mouse is attached, and it resets the
/// style each time that preference changes, so the setter pins it instead.
final class OverlayScrollView: NSScrollView {
  override var scrollerStyle: NSScroller.Style {
    get { super.scrollerStyle }
    set { super.scrollerStyle = .overlay }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    scrollerStyle = .overlay
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
