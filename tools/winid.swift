import CoreGraphics
import Foundation

// Prints the CGWindowNumber of the largest on-screen window owned by the given
// app (default "BroPrompter"), for use with `screencapture -l`. Window metadata
// (owner, bounds, number) does not require Screen Recording permission; only
// pixel capture does. See the "Debugging" notes in CLAUDE.md.

let target = CommandLine.arguments.dropFirst().first ?? "BroPrompter"

guard
  let windows = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
  ) as? [[String: Any]]
else {
  FileHandle.standardError.write(Data("failed to list windows\n".utf8))
  exit(1)
}

var bestNumber: Int?
var bestArea: CGFloat = -1

for window in windows {
  guard
    let owner = window[kCGWindowOwnerName as String] as? String,
    owner == target,
    let number = window[kCGWindowNumber as String] as? Int
  else { continue }

  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat]
  let area = (bounds?["Width"] ?? 0) * (bounds?["Height"] ?? 0)
  if area > bestArea {
    bestArea = area
    bestNumber = number
  }
}

guard let bestNumber else {
  FileHandle.standardError.write(Data("no window for \(target)\n".utf8))
  exit(2)
}

FileHandle.standardOutput.write(Data("\(bestNumber)\n".utf8))
