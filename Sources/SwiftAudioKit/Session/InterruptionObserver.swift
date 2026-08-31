//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

#if canImport(AVFAudio) && !os(macOS)
    import AVFAudio
#endif

enum SessionSignal: Sendable, Hashable {
    case becameInactive(PauseReason)
    case resumptionRecommended(Bool)
}

/// Shaped as two events rather than one carrying a resume flag, matching how the platform
/// splits deactivation from resumption.
@MainActor
final class InterruptionObserver {
    private var tokens = [any NSObjectProtocol]()

    isolated deinit {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }

    func signals() -> AsyncStream<SessionSignal> {
        let (stream, continuation) = AsyncStream<SessionSignal>.makeStream(bufferingPolicy: .bufferingNewest(8))

        #if canImport(AVFAudio) && !os(macOS)
            let center = NotificationCenter.default

            tokens = [
                center.addObserver(
                    forName: AVAudioSession.interruptionNotification,
                    object: nil,
                    queue: .main
                ) { note in
                    guard let signal = SessionSignal(interruption: note) else {
                        return
                    }
                    continuation.yield(signal)
                },
                center.addObserver(
                    forName: AVAudioSession.routeChangeNotification,
                    object: nil,
                    queue: .main
                ) { note in
                    guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                          AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else {
                        return
                    }
                    continuation.yield(.becameInactive(.routeChange))
                }
            ]
        #endif

        return stream
    }
}

#if canImport(AVFAudio) && !os(macOS)
    private extension SessionSignal {
        init?(interruption note: Notification) {
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else {
                return nil
            }

            switch type {
            case .began:
                self = .becameInactive(.interruption)
            case .ended:
                let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                    .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
                self = .resumptionRecommended(options.contains(.shouldResume))
            @unknown default:
                return nil
            }
        }
    }
#endif
