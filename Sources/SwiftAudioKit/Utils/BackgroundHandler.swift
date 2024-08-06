//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

#if os(OSX)
import Foundation
#else
import UIKit

/// A protocol that defines background task handling capabilities.
protocol BackgroundTaskCreator: AnyObject {
    /// Marks the beginning of a new long-running background task.
    ///
    /// - Parameter handler: A handler to be called shortly before the app’s remaining background time reaches 0.
    ///     You should use this handler to clean up and mark the end of the background task. Failure to end the task
    ///     explicitly will result in the termination of the app. The handler is called synchronously on the main
    ///     thread, blocking the app’s suspension momentarily while the app is notified.
    /// - Returns: A unique identifier for the new background task. You must pass this value to the
    ///     `endBackgroundTask:` method to mark the end of this task. This method returns `UIBackgroundTaskInvalid`
    ///     if running in the background is not possible.
    func beginBackgroundTask(expirationHandler handler: (() -> Void)?) -> UIBackgroundTaskIdentifier

    /// Marks the end of a specific long-running background task.
    ///
    /// You must call this method to end a task that was started using the `beginBackgroundTask(expirationHandler:)`
    /// method. If you do not, the system may kill your app.
    ///
    /// This method can be safely called on a non-main thread.
    ///
    /// - Parameter identifier: An identifier returned by the `beginBackgroundTask(expirationHandler:)` method.
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier)
}

extension UIApplication: BackgroundTaskCreator {}
#endif

/// A class that handles background tasks to prevent iOS from suspending the app while tasks are ongoing.
class BackgroundHandler: NSObject {
#if !os(OSX)
    /// The background task creator, typically `UIApplication.shared`.
    var backgroundTaskCreator: BackgroundTaskCreator = UIApplication.shared

    /// The background task identifier if a background task has started. `nil` if not.
    @SynchronizedLock private var taskIdentifier: UIBackgroundTaskIdentifier?
#else
    /// On macOS, background tasks are not supported in the same way as iOS, so we just use an integer identifier.
    @SynchronizedLock private var taskIdentifier: Int?
#endif

    /// The number of background task requests received. When this counter hits 0, the background task, if any, will be terminated.
    @SynchronizedLock private var counter = 0

    /// Ends the background task, if any, upon deinitialization.
    deinit {
        endBackgroundTask()
    }

    /// Starts a background task if one isn't already active.
    ///
    /// - Returns: A boolean value indicating whether a background task was created.
    @discardableResult
    func beginBackgroundTask() -> Bool {
#if os(OSX)
        return false
#else
        counter += 1

        guard taskIdentifier == nil else {
            return false
        }

        taskIdentifier = backgroundTaskCreator.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }

        return taskIdentifier != UIBackgroundTaskIdentifier.invalid
#endif
    }

    /// Ends the background task if there is one.
    ///
    /// - Returns: A boolean value indicating whether the background task was ended.
    @discardableResult
    func endBackgroundTask() -> Bool {
#if os(OSX)
        return false
#else
        guard let taskIdentifier = taskIdentifier else {
            return false
        }

        counter -= 1

        guard counter == 0 else {
            return false
        }

        if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
            backgroundTaskCreator.endBackgroundTask(taskIdentifier)
        }
        self.taskIdentifier = nil
        return true
#endif
    }
}
