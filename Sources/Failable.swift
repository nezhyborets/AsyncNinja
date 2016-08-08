//
//  Copyright (c) 2016 Anton Mironov
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

import Foundation

public protocol _Failable { // hacking type system once
  associatedtype Success
  associatedtype Failure

  init(success: Success)
  init(error: Error)

  func onSuccess(_ handler: @noescape (Success) throws -> Void) rethrows
  func onFailure(_ handler: @noescape (Failure) throws -> Void) rethrows

  // (success or failure) * (try transfrom success to success) -> (success or failure)
  func liftSuccess<T>(transform: @noescape (Success) throws -> T) -> Failable<T>

  // (success or failure) * (try transfrom success to (success or failure)) -> (success or failure)
  func liftSuccess<T>(transform: @noescape (Success) throws -> Failable<T>) -> Failable<T>

  // (success or failure) * (try transfrom failure to success) -> (success or failure)
  func liftFailure(transform: @noescape (Failure) throws -> Success) -> Failable<Success>

  // (success or failure) * (transfrom failure to success) -> success
  func liftFailure(transform: @noescape (Failure) -> Success) -> Success
}


public enum Failable<T> : _Failable {
  public typealias Success = T
  public typealias Failure = Error

  case success(Success)
  case failure(Failure)

  public init(success: Success) {
    self = .success(success)
  }

  public init(error: Error) {
    self = .failure(error)
  }

  public func onSuccess(_ handler: @noescape (Success) throws -> Void) rethrows {
    if case let .success(successValue) = self {
      try handler(successValue)
    }
  }

  public func onFailure(_ handler: @noescape (Failure) throws -> Void) rethrows {
    if case let .failure(failureValue) = self {
      try handler(failureValue)
    }
  }

  public func liftSuccess<T>(transform: @noescape (Success) throws -> T) -> Failable<T> {
    return self.liftSuccess { .success(try transform($0)) }
  }

  public func liftSuccess<T>(transform: @noescape (Success) throws -> Failable<T>) -> Failable<T> {
    switch self {
    case let .success(successValue):
      return failable { try transform(successValue) }
    case let .failure(failureValue):
      return .failure(failureValue)
    }
  }

  public func liftFailure(transform: @noescape (Failure) throws -> Success) -> Failable<Success> {
    switch self {
    case let .success(successValue):
      return .success(successValue)
    case let .failure(error):
      do { return .success(try transform(error)) }
      catch { return .failure(error) }
    }
  }

  public func liftFailure(transform: @noescape (Failure) -> Success) -> Success {
    switch self {
    case let .success(successValue):
      return successValue
    case let .failure(error):
      return transform(error)
    }
  }
}

public func failable<T>(block: @noescape () throws -> T) -> Failable<T> {
  do { return Failable(success: try block()) }
  catch { return Failable(error: error) }
}

public func failable<T>(block: @noescape () throws -> Failable<T>) -> Failable<T> {
  do { return try block() }
  catch { return Failable(error: error) }
}

// public typealias FailableFuture<T> = Future<Failable<T>> // does not work properly yet

public extension Future where T : _Failable {

  public typealias Success = Value.Success
  public typealias Failure = Value.Failure

  public func liftSuccess<T>(executor: Executor, transform: (Success) throws -> T) -> Future<Failable<T>> {
    let promise = Promise<Failable<T>>()
    self.onValue(executor: executor) {
      promise.complete(value: $0.liftSuccess(transform: transform))
    }
    return promise
  }

  public func liftFailure(executor: Executor, transform: (Failure) -> Success) -> Future<Success> {
    let promise = Promise<Success>()
    self.onValue(executor: executor) { value -> Void in
      let nextValue = value.liftFailure(transform: transform)
      promise.complete(value: nextValue)
    }
    return promise
  }

  public func liftFailure(executor: Executor, transform: (Failure) throws -> Success) -> Future<Failable<Success>> {
    let promise = Promise<Failable<T.Success>>()
    self.onValue(executor: executor) { value -> Void in
      let nextValue = value.liftFailure(transform: transform)
      promise.complete(value: nextValue)
    }
    return promise
  }
}
