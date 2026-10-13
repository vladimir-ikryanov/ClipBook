import AppKit

/// The corners of a rectangle, in the coordinate space of the path.
struct ContinuousCorners: OptionSet {
  let rawValue: Int

  static let minXMinY = ContinuousCorners(rawValue: 1 << 0)
  static let maxXMinY = ContinuousCorners(rawValue: 1 << 1)
  static let maxXMaxY = ContinuousCorners(rawValue: 1 << 2)
  static let minXMaxY = ContinuousCorners(rawValue: 1 << 3)
  static let all: ContinuousCorners = [.minXMinY, .maxXMinY, .maxXMaxY, .minXMaxY]
}

extension NSBezierPath {
  // A continuous corner runs this many radii along each edge before it meets the edge,
  // so the curvature eases in and out instead of starting abruptly as a circular arc does.
  private static let continuousCornerExtent: CGFloat = 1.528665

  // The three cubic curves of one continuous corner, as (control 1, control 2, end) points
  // measured in radii: the first coordinate along the edge the path arrives on, the second
  // along the edge it leaves on.
  private static let continuousCornerSegments: [((CGFloat, CGFloat), (CGFloat, CGFloat), (CGFloat, CGFloat))] = [
    ((1.08849, 0), (0.868407, 0), (0.631494, 0.074911)),
    ((0.372824, 0.169060), (0.169060, 0.372824), (0.074911, 0.631494)),
    ((0, 0.868407), (0, 1.08849), (0, continuousCornerExtent))
  ]

  /// A rectangle whose given corners are rounded with the continuous curvature Apple uses
  /// for its rounded rectangles, and whose other corners stay square.
  static func continuousRoundedRect(
    _ rect: NSRect,
    cornerRadius: CGFloat,
    corners: ContinuousCorners = .all
  ) -> NSBezierPath {
    let path = NSBezierPath()
    guard !rect.isEmpty else {
      return path
    }

    let radius = max(0, min(cornerRadius, min(rect.width, rect.height) / 2 / continuousCornerExtent))
    let extent = radius * continuousCornerExtent
    guard radius > 0, !corners.isEmpty else {
      path.appendRect(rect)
      return path
    }

    // Walk the rectangle counterclockwise from the bottom edge, drawing each corner as
    // three cubic curves when it is rounded and as a sharp turn when it is not.
    let walk: [(corner: NSPoint, rounds: Bool, arrives: CGVector, leaves: CGVector)] = [
      (NSPoint(x: rect.maxX, y: rect.minY), corners.contains(.maxXMinY), CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: 1)),
      (NSPoint(x: rect.maxX, y: rect.maxY), corners.contains(.maxXMaxY), CGVector(dx: 0, dy: 1), CGVector(dx: -1, dy: 0)),
      (NSPoint(x: rect.minX, y: rect.maxY), corners.contains(.minXMaxY), CGVector(dx: -1, dy: 0), CGVector(dx: 0, dy: -1)),
      (NSPoint(x: rect.minX, y: rect.minY), corners.contains(.minXMinY), CGVector(dx: 0, dy: -1), CGVector(dx: 1, dy: 0))
    ]

    let firstStep = walk[3]
    path.move(to: firstStep.rounds ? firstStep.corner + firstStep.leaves * extent : firstStep.corner)

    for step in walk {
      guard step.rounds else {
        path.line(to: step.corner)
        continue
      }

      path.line(to: step.corner - step.arrives * extent)
      for (control1, control2, end) in continuousCornerSegments {
        path.curve(
          to: step.corner - step.arrives * (end.0 * radius) + step.leaves * (end.1 * radius),
          controlPoint1: step.corner - step.arrives * (control1.0 * radius) + step.leaves * (control1.1 * radius),
          controlPoint2: step.corner - step.arrives * (control2.0 * radius) + step.leaves * (control2.1 * radius)
        )
      }
    }

    path.close()
    return path
  }
}

private func + (point: NSPoint, vector: CGVector) -> NSPoint {
  NSPoint(x: point.x + vector.dx, y: point.y + vector.dy)
}

private func - (point: NSPoint, vector: CGVector) -> NSPoint {
  NSPoint(x: point.x - vector.dx, y: point.y - vector.dy)
}

private func * (vector: CGVector, scale: CGFloat) -> CGVector {
  CGVector(dx: vector.dx * scale, dy: vector.dy * scale)
}
