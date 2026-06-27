// swift-tools-version:5.9
import PackageDescription

/// Tooling-only package. It exists solely to host the Airbnb FormatSwift command
/// plugin so `swift package format` can lint and format the app sources against
/// the Airbnb Swift Style Guide. The app itself is an XcodeGen-generated
/// .xcodeproj and does NOT build through SwiftPM - XcodeGen and xcodebuild ignore
/// this manifest, and the plugin reads only it. See CLAUDE.md "Linting and
/// formatting" and BROP-26.
let package = Package(
  name: "BroPrompterTooling",
  dependencies: [
    .package(url: "https://github.com/airbnb/swift", from: "1.0.0")
  ]
)
