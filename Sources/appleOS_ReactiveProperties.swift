//
//  Copyright (c) 2016-2019 Anton Mironov
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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  import Foundation

  /// `ReactiveProperties` is an adaptor for reactive properties.
  public struct ReactiveProperties<Object: NSObject&Retainer> {
    /// a getter that could be provided as customization point
    public typealias CustomGetter<T> = (Object) -> T?
    /// a setter that could be provided as customization point
    public typealias CustomSetter<T> = (Object, T) -> Void

    /// object that hosts reactive properties
    public var object: Object

    /// executor to update object on
    public var executor: Executor

    /// original exectutor this instance was created on
    public var originalExecutor: Executor?

    /// observation session used by this instance
    public var observationSession: ObservationSession?

    /// designated initalizer
    public init(
      object: Object,
      executor: Executor,
      originalExecutor: Executor?,
      observationSession: ObservationSession?) {
      self.object = object
      self.executor = executor
      self.originalExecutor = originalExecutor
      self.observationSession = observationSession
    }

    func reactiveProperties<O: NSObject&Retainer>(with object: O) -> ReactiveProperties<O> {
      return ReactiveProperties<O>(object: object,
                                   executor: executor,
                                   originalExecutor: originalExecutor,
                                   observationSession: observationSession)
    }
  }

  public extension ReactiveProperties {
    /// makes an `UpdatableProperty<T?>` for specified key path.
    ///
    /// `UpdatableProperty` is a kind of `Producer` so you can:
    /// * subscribe for updates
    /// * transform using `map`, `flatMap`, `filter`, `debounce`, `distinct`, ...
    /// * update manually with `update()` method
    /// * bind `Channel` to an `UpdatableProperty` using `Channel.bind`
    ///
    /// - Parameter keyPath: to observe.
    ///
    ///   **Make sure that keyPath refers to KVO-compliant property**.
    ///   * Make sure that properties defined in swift have dynamic attribute.
    ///   * Make sure that methods `class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String>`
    ///   return correct values for read-only properties
    /// - Parameter allowSettingSameValue: set to true if you want
    ///   to set a new value event if it is equal to an old one
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Parameter customGetter: provides a custom getter to use instead of value(forKeyPath:) call
    /// - Parameter customSetter: provides a custom getter to use instead of setValue(_: forKeyPath:) call
    /// - Returns: an `UpdatableProperty<T?>` bound to observe and update specified keyPath
    func updatable<T>(
      forKeyPath keyPath: String,
      allowSettingSameValue: Bool = false,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T?>? = nil,
      customSetter: CustomSetter<T?>? = nil
      ) -> ProducerProxy<T?, Void> {
      return object.updatable(forKeyPath: keyPath,
                              executor: executor,
                              from: originalExecutor,
                              observationSession: observationSession,
                              allowSettingSameValue: allowSettingSameValue,
                              channelBufferSize: channelBufferSize,
                              customGetter: customGetter,
                              customSetter: customSetter)
    }

    /// makes an `UpdatableProperty<T>` for specified key path.
    ///
    /// `UpdatableProperty` is a kind of `Producer` so you can:
    /// * subscribe for updates
    /// * transform using `map`, `flatMap`, `filter`, `debounce`, `distinct`, ...
    /// * update manually with `update()` method
    /// * bind `Channel` to an `UpdatableProperty` using `Channel.bind`
    ///
    /// - Parameter keyPath: to observe.
    ///
    ///   **Make sure that keyPath refers to KVO-compliant property**.
    ///   * Make sure that properties defined in swift have dynamic attribute.
    ///   * Make sure that methods `class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String>`
    ///   return correct values for read-only properties
    /// - Parameter onNone: is a policy of handling `None` (or `nil`) value
    ///   that can arrive from Key-Value observation.
    /// - Parameter allowSettingSameValue: set to true if you want
    ///   to set a new value event if it is equal to an old one
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Parameter customGetter: provides a custom getter to use instead of value(forKeyPath:) call
    /// - Parameter customSetter: provides a custom getter to use instead of setValue(_: forKeyPath:) call
    /// - Returns: an `UpdatableProperty<T>` bound to observe and update specified keyPath
    func updatable<T>(
      forKeyPath keyPath: String,
      onNone: UpdateWithNoneHandlingPolicy<T>,
      allowSettingSameValue: Bool = false,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T>? = nil,
      customSetter: CustomSetter<T>? = nil
      ) -> ProducerProxy<T, Void> {
      return object.updatable(forKeyPath: keyPath,
                              onNone: onNone,
                              executor: executor,
                              from: originalExecutor,
                              observationSession: observationSession,
                              allowSettingSameValue: allowSettingSameValue,
                              channelBufferSize: channelBufferSize,
                              customGetter: customGetter,
                              customSetter: customSetter)
    }

    /// makes an `Updating<T?>` for specified key path.
    ///
    /// `Updating` is a kind of `Channel` so you can:
    /// * subscribe for updates
    /// * transform using `map`, `flatMap`, `filter`, `debounce`, `distinct`, ...
    ///
    /// - Parameter keyPath: to observe.
    ///
    ///   **Make sure that keyPath refers to KVO-compliant property**.
    ///   * Make sure that properties defined in swift have dynamic attribute.
    ///   * Make sure that methods `class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String>`
    ///   return correct values for read-only properties
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Parameter customGetter: provides a custom getter to use instead of value(forKeyPath:) call
    /// - Returns: an `Updating<T?>` bound to observe and update specified keyPath
    func updating<T>(
      forKeyPath keyPath: String,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T>? = nil
      ) -> Channel<T?, Void> {
      return object.updating(forKeyPath: keyPath,
                             executor: executor,
                             from: originalExecutor,
                             observationSession: observationSession,
                             channelBufferSize: channelBufferSize,
                             customGetter: customGetter)
    }

    /// makes an `Updating<T>` for specified key path.
    ///
    /// `Updating` is a kind of `Channel` so you can:
    /// * subscribe for updates
    /// * transform using `map`, `flatMap`, `filter`, `debounce`, `distinct`, ...
    ///
    /// - Parameter keyPath: to observe.
    ///
    ///   **Make sure that keyPath refers to KVO-compliant property**.
    ///   * Make sure that properties defined in swift have dynamic attribute.
    ///   * Make sure that methods `class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String>`
    ///   return correct values for read-only properties
    /// - Parameter onNone: is a policy of handling `None` (or `nil`) value
    ///   that can arrive from Key-Value observation.
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Parameter customGetter: provides a custom getter to use instead of value(forKeyPath:) call
    /// - Returns: an `Updating<T>` bound to observe and update specified keyPath
    func updating<T>(
      forKeyPath keyPath: String,
      onNone: UpdateWithNoneHandlingPolicy<T>,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T>? = nil
      ) -> Channel<T, Void> {
      return object.updating(forKeyPath: keyPath,
                             onNone: onNone,
                             executor: executor,
                             from: originalExecutor,
                             observationSession: observationSession,
                             channelBufferSize: channelBufferSize,
                             customGetter: customGetter)
    }

    /// Makes a sink that wraps specified setter
    ///
    /// - Parameter setter: to use with sink
    /// - Returns: constructed sink
    func sink<T>(setter: @escaping CustomSetter<T>) -> Sink<T, Void> {
      return object.sink(executor: executor, setter: setter)
    }
  }

  public extension Retainer where Self: NSObject {

    /// Makes a `ReactiveProperties` bount to `self` that captures specified values
    ///
    /// - Parameter executor: to subscribe and update value on
    /// - Parameter originalExecutor: `Executor` you calling this method on.
    ///   Specifying this argument will allow to perform syncronous executions
    ///   on `strictAsync: false` `Executor`s.
    ///   Use default value or nil if you are not sure about an `Executor`
    ///   you calling this method on.
    /// - Parameter observationSession: is an object that helps to control observation
    /// - Returns: `ReactiveProperties` that capture specified values
    func reactiveProperties(
      executor: Executor,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil
      ) -> ReactiveProperties<Self> {
      return ReactiveProperties(object: self,
                                executor: executor,
                                originalExecutor: originalExecutor,
                                observationSession: observationSession)
    }
  }

  public extension ExecutionContext where Self: NSObject {

    /// Makes a `ReactiveProperties` bount to `self` that captures specified values
    ///
    /// - Parameter originalExecutor: `Executor` you calling this method on.
    ///   Specifying this argument will allow to perform syncronous executions
    ///   on `strictAsync: false` `Executor`s.
    ///   Use default value or nil if you are not sure about an `Executor`
    ///   you calling this method on.
    /// - Parameter observationSession: is an object that helps to control observation
    /// - Returns: `ReactiveProperties` that capture specified values
    func reactiveProperties(
      from originalExecutor: Executor? = .immediate,
      observationSession: ObservationSession? = nil
      ) -> ReactiveProperties<Self> {
      return reactiveProperties(executor: executor,
                                from: originalExecutor,
                                observationSession: observationSession)
    }

    /// Short and useful property that returns `ReactiveProperties` and covers `99%` of use cases
    var rp: ReactiveProperties<Self> { return reactiveProperties(from: executor) }
  }
#endif

#if os(macOS)

import AppKit
public extension ReactiveProperties {
  func anyUpdatable(
    forBindingName bindingName: NSBindingName,
    initialValue: Any?) -> ProducerProxy<Any?, Void> {
    return object.updatable(forBindingName: bindingName,
                            executor: executor,
                            from: originalExecutor,
                            observationSession: observationSession,
                            initialValue: initialValue)
  }

  func updatable<T>(
    forBindingName bindingName: NSBindingName,
    channelBufferSize: Int = 1,
    initialValue: T?,
    transformer: @escaping (Any?) -> T? = { $0 as? T },
    reveseTransformer: @escaping (T?) -> Any? = { $0 }
    ) -> ProducerProxy<T?, Void> {
    let typeerasedProducerProxy = object.updatable(forBindingName: bindingName,
                                                   executor: executor,
                                                   from: originalExecutor,
                                                   observationSession: observationSession,
                                                   initialValue: initialValue)

    var isTypesafeProxyUpdatingEnabled = true
    let typesafeProducerProxy = ProducerProxy<T?, Void>(
      updateExecutor: executor,
      bufferSize: channelBufferSize
    ) { [weak typeerasedProducerProxy] (_, event, originalExecutor) in
      isTypesafeProxyUpdatingEnabled = false
      guard let typeerasedProducerProxy = typeerasedProducerProxy else { return }
      switch event {
      case .update(let update):
        let transformedUpdate = reveseTransformer(update)
        typeerasedProducerProxy.update(transformedUpdate, from: originalExecutor)
      case .completion(let completion):
        typeerasedProducerProxy.complete(completion, from: originalExecutor)
      }
      isTypesafeProxyUpdatingEnabled = true
    }

    let handler = typeerasedProducerProxy.makeUpdateHandler(
      executor: .immediate
    ) { [weak typesafeProducerProxy] (update, originalExecutor) in
      guard
        isTypesafeProxyUpdatingEnabled,
        let typesafeProducerProxy = typesafeProducerProxy
        else { return }
      _ = typesafeProducerProxy.tryUpdateWithoutHandling(transformer(update), from: originalExecutor)
    }

    typesafeProducerProxy._asyncNinja_retainHandlerUntilFinalization(handler)
    return typesafeProducerProxy
  }
}

#endif
