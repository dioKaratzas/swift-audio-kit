//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

#if canImport(UIKit) && !os(watchOS)
    import UIKit
#endif

/// Keeps the app alive while buffering, before any audio is actually playing.
/// Owned by the main actor because `UIApplication` is.
@MainActor
final class BackgroundActivity {
    private var depth = 0

    #if canImport(UIKit) && !os(watchOS)
        private var identifier = UIBackgroundTaskIdentifier.invalid
    #elseif os(macOS)
        private var assertion: (any NSObjectProtocol)?
    #else
        private var held: DispatchSemaphore?
    #endif

    func begin() {
        depth += 1
        guard depth == 1 else {
            return
        }
        start()
    }

    func end() {
        guard depth > 0 else {
            return
        }
        depth -= 1
        guard depth == 0 else {
            return
        }
        finish()
    }

    #if canImport(UIKit) && !os(watchOS)
        private func start() {
            identifier = UIApplication.shared.beginBackgroundTask(withName: "SwiftAudioKit") { [weak self] in
                self?.finish()
            }
        }

        private func finish() {
            guard identifier != .invalid else {
                return
            }
            UIApplication.shared.endBackgroundTask(identifier)
            identifier = .invalid
        }

    #elseif os(macOS)
        private func start() {
            assertion = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled],
                reason: "SwiftAudioKit playback"
            )
        }

        private func finish() {
            guard let assertion else {
                return
            }
            ProcessInfo.processInfo.endActivity(assertion)
            self.assertion = nil
        }

    #else
        private func start() {
            let semaphore = DispatchSemaphore(value: 0)
            held = semaphore
            // The block owns the assertion for as long as it runs, so it waits to be released.
            ProcessInfo.processInfo.performExpiringActivity(withReason: "SwiftAudioKit") { expired in
                guard !expired else {
                    return
                }
                semaphore.wait()
            }
        }

        private func finish() {
            held?.signal()
            held = nil
        }
    #endif
}
