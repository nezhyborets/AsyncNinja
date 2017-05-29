//
//  Copyright (c) 2016-2017 Anton Mironov
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom
//  the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Dispatch

// MARK: - Brief

/// This file contains 8 public methods that are product of three factors
/// - result handling: regular or flattening
/// - contextual: yes or no
/// - block scheduling: immediate or delayed

// MARK: - future makers: non-contextual, immediate block scheduling

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - lazy: indicates if the block will be lazily executed.
///     Lazy execution means that execution will occur on first subscription.
///     False by default
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause
///     returned future to complete successfuly.
///     Throw from block will returned future to complete with failure
/// - Returns: future
public func future<T>(
  executor: Executor = .primary,
  lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
  cancellationToken: CancellationToken? = nil,
  _ block: @escaping () throws -> T
  ) -> Future<T> {
  // Test: FutureTests.testMakeFutureOfBlock_Success
  // Test: FutureTests.testMakeFutureOfBlock_Failure

  return Promise<T>(
    lazy: lazy,
    cancellationToken: cancellationToken
  ) { (promise: Promise<T>) in
    executor.execute(from: nil) { [weak promise] (originalExecutor) in
      guard !(promise?.isComplete ?? true) else { return }
      let value = fallible(block: block)
      promise?.complete(value, from: originalExecutor)
    }
  }
}

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - lazy: indicates if the block will be lazily executed.
///     Lazy execution means that execution will occur on first subscription.
///     False by default
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause returned future
///     to complete with future. Throw from block will returned future to complete with failure
/// - Returns: future
public func flatFuture<T>(
  executor: Executor = .primary,
  lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
  cancellationToken: CancellationToken? = nil,
  _ block: @escaping () throws -> Future<T>
  ) -> Future<T> {

  return Promise<T>(
    lazy: lazy,
    cancellationToken: cancellationToken
  ) { (promise: Promise<T>) in
    executor.execute(from: nil) { [weak promise] (originalExecutor) in
      guard !(promise?.isComplete ?? true) else { return }
      do {
        promise?.complete(with: try block())
      } catch {
        promise?.fail(error, from: originalExecutor)
      }
    }
  }
}

// MARK: - future makers: contextual, immediate block scheduling

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - lazy: indicates if the block will be lazily executed.
///     Lazy execution means that execution will occur on first subscription.
///     False by default
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause
///     returned future to complete successfuly.
///     Throw from block will returned future to complete with failure
///   - strongContext: is `ExecutionContext` restored from
///     a weak reference of context passed to method
/// - Returns: future
public func future<T, Context: ExecutionContext>(
  context: Context,
  executor: Executor? = nil,
  lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
  cancellationToken: CancellationToken? = nil,
  _ block: @escaping (_ strongContext: Context) throws -> T
  ) -> Future<T> {
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Success_ContextAlive
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Success_ContextDead
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Failure_ContextDead

  return Promise(
    context: context,
    lazy: lazy,
    cancellationToken: cancellationToken
  ) { (context: Context, promise: Promise<T>) in
    (executor ?? context.executor).execute(from: nil) { [weak promise, weak context] (originalExecutor) in
      guard !(promise?.isComplete ?? true) else { return }

      let completion = fallible { () -> T in
        guard let context = context
          else { throw AsyncNinjaError.contextDeallocated }
        return try block(context)
      }
      promise?.complete(completion, from: originalExecutor)
    }
  }
}

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - lazy: indicates if the block will be lazily executed.
///     Lazy execution means that execution will occur on first subscription.
///     False by default
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause
///     returned future to complete with future.
///     Throw from block will complete returned future with failure.
///   - strongContext: is `ExecutionContext` restored from weak reference of context passed to method
/// - Returns: future
public func flatFuture<T, Context: ExecutionContext>(
  context: Context,
  executor: Executor? = nil,
  lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
  cancellationToken: CancellationToken? = nil,
  _ block: @escaping (_ strongContext: Context) throws -> Future<T>
  ) -> Future<T> {

  return Promise<T>(
    context: context,
    lazy: lazy,
    cancellationToken: cancellationToken
  ) { (context: Context, promise: Promise<T>) in
    (executor ?? context.executor).execute(from: nil) { [weak promise, weak context] (originalExecutor) in
      guard !(promise?.isComplete ?? true) else { return }

      do {
        guard let context = context
          else { throw AsyncNinjaError.contextDeallocated }
        promise?.complete(with: try block(context))
      } catch {
        promise?.fail(error, from: originalExecutor)
      }
    }
  }
}

// MARK: - future makers: non-contextual, delayed block scheduling

/// Asynchrounously executes block after timeout on executor and wraps returned value into future
/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - after: is `Double` timeout in seconds to schedule block after
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause
///     returned future to complete successfuly.
///     Throw from block will returned future to complete with failure
/// - Returns: future
public func future<T>(
  executor: Executor = .primary,
  after timeout: Double,
  cancellationToken: CancellationToken? = nil,
  _ block: @escaping () throws -> T
  ) -> Future<T> {
  // Test: FutureTests.testMakeFutureOfDelayedFallibleBlock_Success
  // Test: FutureTests.testMakeFutureOfDelayedFallibleBlock_Failure
  return promise(executor: executor,
                 after: timeout,
                 cancellationToken: cancellationToken,
                 block)
}

/// Asynchrounously executes block after timeout on executor and wraps returned value into future
/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - after: is `Double` timeout in seconds to schedule block after
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause
///     returned future to complete with future.
///     Throw from block will returned future to complete with failure
/// - Returns: future
public func flatFuture<T>(
  executor: Executor = .primary,
  after timeout: Double,
  cancellationToken: CancellationToken? = nil,
  _ block: @escaping () throws -> Future<T>
  ) -> Future<T> {
  return flatPromise(executor: executor,
                     after: timeout,
                     cancellationToken: cancellationToken,
                     block)
}

// MARK: - future makers: contextual, delayed block scheduling

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - after: is `Double` timeout in seconds to schedule block after
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause returned
///     future to complete successfuly.
///     Throw from block will returned future to complete with failure
///   - strongContext: is `ExecutionContext` restored from weak reference of context passed to method
/// - Returns: future
public func future<T, C: ExecutionContext>(
  context: C,
  executor: Executor? = nil,
  after timeout: Double,
  cancellationToken: CancellationToken? = nil,
  _ block: @escaping (_ strongContext: C) throws -> T
  ) -> Future<T> {

  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Success_EarlyContextDead
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextDead
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Failure_EarlyContextDead

  let promiseValue = promise(executor: executor ?? context.executor,
                             after: timeout,
                             cancellationToken: cancellationToken) {
    [weak context] () -> T in
    if let context = context {
      return try block(context)
    } else {
      throw AsyncNinjaError.contextDeallocated
    }
  }

  context.addDependent(completable: promiseValue)

  return promiseValue
}

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - after: is `Double` timeout in seconds to schedule block after
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause returned
///     future to complete successfuly.
///     Throw from block will returned future to complete with failure
///   - strongContext: is `ExecutionContext` restored from weak reference of context passed to method
/// - Returns: future
public func flatFuture<T, C: ExecutionContext>(
  context: C,
  executor: Executor? = nil,
  after timeout: Double,
  cancellationToken: CancellationToken? = nil,
  _ block: @escaping (_ strongContext: C) throws -> Future<T>
  ) -> Future<T> {
  let promise = flatPromise(executor: executor ?? context.executor,
                            after: timeout,
                            cancellationToken: cancellationToken) {
    [weak context] () -> Future<T> in

    if let context = context {
      return try block(context)
    } else {
      throw AsyncNinjaError.contextDeallocated
    }
  }

  context.addDependent(completable: promise)

  return promise
}

// MARK: - internal helper methods

/// **internal use only**
private func promise<T>(
  executor: Executor,
  after timeout: Double,
  cancellationToken: CancellationToken?,
  _ block: @escaping () throws -> T
  ) -> Promise<T> {
  let promise = Promise<T>()

  cancellationToken?.add(cancellable: promise)

  executor.execute(
    after: timeout
  ) { [weak promise] (originalExecutor) in
    if cancellationToken?.isCancelled ?? false {
      promise?.cancel(from: originalExecutor)
    } else if case .some = promise {
      let completion = fallible(block: block)
      promise?.complete(completion, from: originalExecutor)
    }
  }

  return promise
}

/// **internal use only**
private func flatPromise<T>(
  executor: Executor,
  after timeout: Double,
  cancellationToken: CancellationToken?,
  _ block: @escaping () throws -> Future<T>) -> Promise<T> {
  let promise = Promise<T>()

  cancellationToken?.add(cancellable: promise)

  executor.execute(
    after: timeout
  ) { [weak promise] (originalExecutor) in
    guard case .some = promise else { return }

    if cancellationToken?.isCancelled ?? false {
      promise?.cancel(from: originalExecutor)
    } else {
      do { promise?.complete(with: try block()) } catch { promise?.fail(error, from: originalExecutor) }
    }
  }

  return promise
}
