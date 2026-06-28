import SwiftUI

/// The recording chrome layered over the teleprompter (BROP-6): the 3-2-1
/// count-in, a recording indicator with the elapsed clock and level meter, an
/// audio-only waveform (since there is no camera in audio mode), and the
/// post-stop "Take saved" confirmation. Display-only except the saved banner;
/// all side effects run through the passed-in controller and callbacks.
struct RecordingOverlay: View {

  // MARK: Internal

  let recorder: RecorderController
  let mode: TakeMode
  let savedTakeURL: URL?
  let onDismissSaved: () -> Void

  var body: some View {
    ZStack {
      if mode == .audio, recorder.isCapturing {
        waveform
      }

      if recorder.phase == .countingIn {
        countIn
      }

      VStack(spacing: 12) {
        if recorder.isCapturing {
          topIndicators
        }
        if let savedTakeURL {
          savedBanner(savedTakeURL)
        }
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
    }
  }

  // MARK: Private

  private var countIn: some View {
    Text("\(recorder.countdownRemaining)")
      .font(.system(size: 140, weight: .bold).monospacedDigit())
      .foregroundStyle(.white)
      .shadow(color: .black.opacity(0.6), radius: 12)
      .allowsHitTesting(false)
      .accessibilityLabel("Starting in \(recorder.countdownRemaining)")
  }

  /// REC + elapsed clock at the leading edge and the input level meter at the
  /// trailing edge, framing the centered "remaining" label in the top chrome
  /// (prototype 07 4335:14397).
  private var topIndicators: some View {
    HStack(alignment: .top) {
      recordingBadge
      Spacer()
      levelMeter
    }
  }

  private var recordingBadge: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(.red)
        .frame(width: 10, height: 10)
        .opacity(recorder.phase == .paused ? 0.4 : 1)

      // A text label so recording state does not rely on the red dot alone
      // (non-color signifier, GUIDELINES.md 4 / BROP-23).
      Text(recorder.phase == .paused ? "PAUSED" : "REC")
        .font(.caption.weight(.semibold))

      Text(TeleprompterEngine.clockString(recorder.elapsed))
        .font(.callout.monospacedDigit())
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(.bar, in: .capsule)
    .allowsHitTesting(false)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(recorder.phase == .paused ? "Recording paused" : "Recording")
    .accessibilityValue(TeleprompterEngine.clockString(recorder.elapsed))
  }

  private var levelMeter: some View {
    HStack(spacing: 8) {
      Image(systemName: "mic.fill")
        .foregroundStyle(.secondary)
      ProgressView(value: recorder.level)
        .tint(.green)
        .frame(width: 80)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(.bar, in: .capsule)
    .allowsHitTesting(false)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Input level")
    .accessibilityValue("\(Int(recorder.level * 100)) percent")
  }

  private var waveform: some View {
    HStack(alignment: .center, spacing: 3) {
      ForEach(Array(recorder.levelHistory.enumerated()), id: \.offset) { _, level in
        Capsule()
          .fill(Color.accentColor.opacity(0.6))
          .frame(width: 3, height: max(2, level * 160))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func savedBanner(_ url: URL) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)

      Text("Take saved")

      Button("Reveal in Finder") { RecordingsDirectory.reveal(url) }
        .buttonStyle(.link)
        .accessibilityIdentifier("teleprompterRevealTake")

      Button(action: onDismissSaved) {
        Image(systemName: "xmark")
      }
      .buttonStyle(.borderless)
      .minimumHitTarget()
      .accessibilityLabel("Dismiss")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.bar, in: .capsule)
    .accessibilityIdentifier("teleprompterTakeSaved")
  }
}
