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

/// Promise is a future that may be manually completed by owner
final public class Promise<Success>: Future<Success>, Completable, CachableCompletable {
  public typealias CompletingType = Future<Success>

  private var _container: ThreadSafeContainer
  private let _releasePool = ReleasePool()

  /// Returns either completion for complete `Promise` or nil otherwise
  override public var completion: Fallible<Success>? {
    return (_container.head as! AbstractPromiseState<Success>).completion
  }

  /// Designated initializer of promise
  private init(head: InitialPromiseState<Success>) {
    _container = makeThreadSafeContainer(head: head)
    super.init()
  }

  override public convenience init() {
    self.init(head: InitialPromiseState<Success>(notifyFirstSubscription: { _ in }))
  }

  convenience init(
    lazy: Bool,
    cancellationToken: CancellationToken?,
    initializer: @escaping (_ promise: Promise<Success>) -> Void
    ) {
    self.init(head: lazy
      ? InitialPromiseState<Success>(notifyFirstSubscription: initializer)
      : InitialPromiseState<Success>(notifyFirstSubscription: { _ in }) )
    cancellationToken?.add(cancellable: self)
    if !lazy {
      initializer(self)
    }
  }

  convenience init<Context: ExecutionContext>(
    context: Context,
    lazy: Bool,
    cancellationToken: CancellationToken?,
    initializer: @escaping (_ strongContext: Context, _ promise: Promise<Success>) -> Void
    ) {
    self.init(lazy: lazy, cancellationToken: cancellationToken) { [weak context] (promise) in
      if let context = context {
        initializer(context, promise)
      }
    }
    context.addDependent(completable: self)
  }

  /// **internal use only**
  override public func makeCompletionHandler(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> AnyObject? {
    var handler: PromiseHandler<Success>? = nil

    let (oldHead, _) = _container.updateHead {
      return ($0 as! AbstractPromiseState<Success>)
        .subscribe(owner: self, handler: &handler, executor: executor, block)
    }

    (oldHead as! AbstractPromiseState<Success>).didSubscribe(owner: self, executor: executor, block)

    return handler
  }

  /// Completes promise with value and returns true.
  /// Returns false if promise was completed before.
  ///
  /// - Parameter completion: value to complete future with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  /// - Returns: true if `Promise` was completed with specified value
  public func tryComplete(
    _ completion: Fallible<Success>,
    from originalExecutor: Executor? = nil
    ) -> Bool {
    let (oldHead, newHead) = _container.updateHead {
      return ($0 as! AbstractPromiseState<Success>).complete(completion: completion)
    }
    let didComplete = (oldHead !== newHead)
    guard didComplete else { return false }

    var nextItem = oldHead as! AbstractPromiseState<Success>?
    while let currentItem = nextItem {
      nextItem = currentItem.didComplete(owner: self, completion: completion, from: originalExecutor)
    }
    _releasePool.drain()

    return true
  }

  /// **internal use only**
  override public func _asyncNinja_retainUntilFinalization(_ releasable: Releasable) {
    if !self.isComplete {
      _releasePool.insert(releasable)
    }
  }

  /// **internal use only**
  override public func _asyncNinja_notifyFinalization(_ block: @escaping () -> Void) {
    if self.isComplete {
      block()
    } else {
      _releasePool.notifyDrain(block)
    }
  }
}

/// **internal use only**
fileprivate class AbstractPromiseState<Success> {
  var completion: Fallible<Success>? { return nil }

  func subscribe(
    owner: Promise<Success>,
    handler: inout PromiseHandler<Success>?,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> AbstractPromiseState<Success> {
    return self
  }

  func didSubscribe(
    owner: Promise<Success>,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>,
    _ originalExecutor: Executor) -> Void) {
  }

  func complete(completion: Fallible<Success>) -> AbstractPromiseState<Success> {
    return CompletedPromiseState<Success>(completion: completion)
  }

  func didComplete(
    owner: Promise<Success>,
    completion: Fallible<Success>,
    from originalExecutor: Executor?
    ) -> AbstractPromiseState<Success>? {
    return nil
  }
}

fileprivate class InitialPromiseState<Success>: AbstractPromiseState<Success> {
  let notifyFirstSubscription: (_ owner: Promise<Success>) -> Void
  init(notifyFirstSubscription: @escaping (_ owner: Promise<Success>) -> Void) {
    self.notifyFirstSubscription = notifyFirstSubscription
  }

  override func subscribe(
    owner: Promise<Success>,
    handler: inout PromiseHandler<Success>?,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> AbstractPromiseState<Success> {
    let localHandler = PromiseHandler(executor: executor, block: block, owner: owner)
    handler = localHandler
    return SubscribedPromiseState(handler: localHandler, next: nil)
  }

  override func didSubscribe(
    owner: Promise<Success>,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>,
    _ originalExecutor: Executor) -> Void) {
    notifyFirstSubscription(owner)
  }
}

/// **internal use only**
fileprivate  class SubscribedPromiseState<Success>: AbstractPromiseState<Success> {
  weak private var handler: PromiseHandler<Success>?
  let next: SubscribedPromiseState<Success>?

  init(handler: PromiseHandler<Success>, next: SubscribedPromiseState<Success>?) {
    self.handler = handler
    self.next = next
  }

  override func subscribe(
    owner: Promise<Success>,
    handler: inout PromiseHandler<Success>?,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> AbstractPromiseState<Success> {
    let localHandler = PromiseHandler(executor: executor, block: block, owner: owner)
    handler = localHandler
    return SubscribedPromiseState(handler: localHandler, next: self)
  }

  override func didComplete(
    owner: Promise<Success>,
    completion: Fallible<Success>,
    from originalExecutor: Executor?
    ) -> AbstractPromiseState<Success>? {
    if let handler = self.handler {
      handler.handle(completion, from: originalExecutor)
      handler.releaseOwner()
    }
    return next
  }
}

/// **internal use only**
fileprivate  class CompletedPromiseState<Success>: AbstractPromiseState<Success> {
  override var completion: Fallible<Success>? { return _completion }
  let _completion: Fallible<Success>

  init(completion: Fallible<Success>) {
    _completion = completion
  }

  override func subscribe(
    owner: Promise<Success>,
    handler: inout PromiseHandler<Success>?,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> AbstractPromiseState<Success> {
    return self
  }

  override func didSubscribe(
    owner: Promise<Success>,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void) {
    let localCompletion = _completion
    executor.execute(from: nil) { (originalExecutor) in
      block(localCompletion, originalExecutor)
    }
  }

  override func complete(completion: Fallible<Success>) -> AbstractPromiseState<Success> {
    return self
  }
}

/// **Internal use only**
///
/// Each subscription to a future value will be expressed in such handler.
/// Future will accumulate handlers until completion or deallocacion.
final fileprivate class PromiseHandler<Success> {
  typealias Block = (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
  let executor: Executor
  let block: Block
  var owner: Promise<Success>?

  init(executor: Executor,
       block: @escaping Block,
       owner: Promise<Success>) {
    self.executor = executor
    self.block = block
    self.owner = owner
  }

  func handle(_ value: Fallible<Success>, from originalExecutor: Executor?) {
    self.executor.execute(
      from: originalExecutor
    ) { (originalExecutor) in
      self.block(value, originalExecutor)
    }
  }

  func releaseOwner() {
    self.owner = nil
  }
}
