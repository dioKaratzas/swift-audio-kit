//
//  SynchronizedLock.swift
//  SwiftAudioKit
//
//  Created by Karatzas Dionysios on 4/8/24.
//  Copyright © 2024 Karatzas Dionysios. All rights reserved.
//

import Foundation

/// A property wrapper that provides thread-safe access to a value using an `NSLock`.
///
/// `SynchronizedLock` ensures that access to the wrapped value is synchronized across multiple threads, preventing
/// race conditions and ensuring thread safety. This is particularly useful in multi-threaded environments where
/// a shared resource may be accessed or modified by different threads simultaneously.
///
/// The property wrapper uses an internal `NSLock` to synchronize read and write operations on the wrapped value.
///
/// ## Example Usage:
///
/// ```swift
/// @SynchronizedLock var counter = 0
///
/// // Safely increment the counter from multiple threads.
/// counter += 1
/// ```
///
/// ## Topics
/// ### Creating a Synchronized Property
/// - ``init(wrappedValue:)``
///
/// ### Accessing the Wrapped Value
/// - ``wrappedValue``
///
@propertyWrapper
struct SynchronizedLock<Value> {
    /// The underlying value that is protected by the lock.
    private var value: Value

    /// The lock used to synchronize access to the value.
    private var lock = NSLock()

    /// The wrapped value that is accessed in a thread-safe manner.
    ///
    /// When getting or setting the wrapped value, the access is synchronized using the internal `NSLock`. This ensures
    /// that only one thread can read or write the value at a time, preventing race conditions.
    var wrappedValue: Value {
        get { lock.synchronized { value } }
        set { lock.synchronized { value = newValue } }
    }

    /// Creates a new instance of `SynchronizedLock` with the given initial value.
    ///
    /// - Parameter wrappedValue: The initial value to be stored in the property wrapper.
    init(wrappedValue value: Value) {
        self.value = value
    }
}

private extension NSLock {
    /// Executes a closure while holding the lock, ensuring thread-safe access.
    ///
    /// This method locks the `NSLock` before executing the closure and unlocks it immediately after the closure
    /// completes, whether it completes normally or through an error.
    ///
    /// - Parameter block: The closure to execute within the locked context.
    /// - Returns: The result returned by the closure.
    @discardableResult
    func synchronized<T>(_ block: () -> T) -> T {
        lock()
        defer { unlock() }
        return block()
    }
}
