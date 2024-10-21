import Foundation

extension MainActor {

  /// Runs the given closure on the main actor, blocking the current actor until it completes.
  /// - Parameter body: The closure to run.
  /// - Returns: The result of the closure.
  @_unavailableFromAsync
  static func synchronousRun<T>(_ body: @MainActor () throws -> T) rethrows -> T {
    if Thread.isMainThread {
      return try runUnsafely(body)
    } else {
      return try DispatchQueue.main.sync {
        try runUnsafely(body)
      }
    }
  }

  /// Runs the given closure on the main actor unsafely. This function crashes when not called from
  /// the main actor serial executor.
  ///
  /// Adapted from https://archive.is/uNlAU#post_2.
  ///
  /// - Parameter body: The closure to run.
  /// - Returns: The result of the closure.
  @_unavailableFromAsync
  private static func runUnsafely<T>(_ body: @MainActor () throws -> T) rethrows -> T {
    #if compiler(>=5.9)
      if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
        return try assumeIsolated(body)
      }
    #elseif compiler(>=5.10)
      return try assumeIsolated(body)
    #endif
    
    dispatchPrecondition(condition: .onQueue(.main))
    return try withoutActuallyEscaping(body) { fn in
      // Remove the `@MainActor` / `@Sendable` annotations and execute the closure.
      try unsafeBitCast(fn, to: (() throws -> T).self)()
    }
  }
  
}

