import SwiftUI

extension View {
  /// Floors an interactive control's hit area at a minimum target size (28pt by
  /// default, GUIDELINES.md 4 / BROP-23) without changing what it draws. Use on
  /// icon-only buttons whose glyph is smaller than the target.
  func minimumHitTarget(_ size: CGFloat = 28) -> some View {
    frame(minWidth: size, minHeight: size)
      .contentShape(Rectangle())
  }
}
