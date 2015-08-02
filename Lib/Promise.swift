//
//  Promise.swift
//  NewsReader
//
//  Created by Florent Bruneau on 18/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

private enum State<T> {
    case Success(T)
    case Error(ErrorType)
    case Cancelled
    case Running
}

public enum PromiseError : ErrorType {
    case UncaughtError(ErrorType, Int)
    case Cancelled
}

private struct PromiseHandler<T> {
    private typealias SuccessHandler = (T) throws -> Void
    private typealias ErrorHandler = (ErrorType) throws -> Void

    private let successHandler : SuccessHandler?
    private let errorHandler : ErrorHandler?
    private let onSuccess : (Void) -> Void
    private let onError : (ErrorType) -> Void

    private func succeed(arg: T) {
        do {
            try self.successHandler?(arg)
            self.onSuccess()
        } catch let e {
            self.onError(e)
        }
    }

    private func fail(res: ErrorType) {
        if let errorHandler = self.errorHandler {
            do {
                try errorHandler(res)
                self.onSuccess()
            } catch let e {
                self.onError(e)
            }
        } else {
            switch (res) {
            case PromiseError.UncaughtError(let sub, let depth):
                self.onError(PromiseError.UncaughtError(sub, depth + 1))

            default:
                self.onError(PromiseError.UncaughtError(res, 1))
            }
        }
    }
}

/// A promise object represent an operation that is expected to finish in the future
///
/// A promise object can be used in order to associate action to the termination of
/// an asynchronous operation. This feature is mainly inspired by the Javascript
/// feature introduced in ES6.
///
/// A promise wraps the result of an operation. That result may not be known at
/// the creation of the promise object. The promise let prives a _promise_ that
/// the value will be provided whenever it is known.
///
/// In order to achieve this, the promise let other register callback to be called
/// whenever the result is known. If the result is already known the callback is
/// called immediately.
///
/// A promise can be in one of the four following states:
///  - Running: the action is still in progress, the result is unknown
///  - Success: the action has successfully ended
///  - Error: the action failed
///  - Cancelled: the action has been cancelled. In the point of the view of 
///    the user, this is equivalent to failing with error `.Cancelled`
///
/// Once the promise has left the `Running` state, it is in its definitive state
///
/// Promise allow chaining. A registered callback may return a new promise or
/// throw an error, that will then be propagated to the chained objects. A callback
/// can be registered using the `.then()` and the `.thenChain()` methods. The first
/// one takes a synchronous Void callback. In both case the callback may throw
/// an error that will be propagated in the promise chain.
///
/// Error are treated like exception, in that they propagate as long as they
/// have not been caught using a error handler. Error handler can be registered
/// using the `.otherwise()`, `.then(otherwise:)` or `.otherwiseChain()` methods.
/// When an error is not caught in a chain, it is wrapped in an `.UncaughtError`
/// error letting you known how many chaining layer the error traversed before
/// being caught.
///
/// - note: `.then().otherwise()` and `.then(otherwise:)` are not equivalent since
///   in case of error, in the former case, the error will traverse one chaining
///   layer before being caught while in the second one it is caught in the first
///   chaining layer.
public class Promise<T> {
    public typealias SuccessHandler = (T) throws -> Void
    public typealias ErrorHandler = (ErrorType) throws -> Void

    public typealias Constructor = ((T) -> Void, (ErrorType) -> Void) throws -> Void
    public typealias Cancellor = (Void) -> Void

    private var handlers : [PromiseHandler<T>] = []
    private var state = State<T>.Running
    private let onCancel : Cancellor?

    private init(action: Constructor, onOptCancel: Cancellor?) {
        self.onCancel = onOptCancel
        do {
            try action(self.onSuccess, self.onError)
        } catch let e {
            self.onError(e)
        }
    }

    /// Create a promise for having the result of the given action.
    ///
    /// The action is a callback that receives the two function to call, one
    /// to register a success result, one to register an error. If the action
    /// throws an error, it is automatically registered as a failure.
    ///
    /// - parameter action: the action whose result is wrapped by the promise
    public convenience init(action: Constructor) {
        self.init(action: action, onOptCancel: nil)
    }

    /// Create a promise with a cancellable action.
    ///
    /// The action is a callback that receives the two function to call, one
    /// to register a success result, one to register an error. If the action
    /// throws an error, it is automatically registered as a failure.
    ///
    /// The additional `onCancel` parameter is called when the promise is 
    /// cancelled by the user.
    ///
    /// - parameter action: the action whose result is wrapped by the promise
    /// - parameter onCancel: the callback to call to cancel the action
    public convenience init(action: Constructor, onCancel: Cancellor) {
        self.init(action: action, onOptCancel: onCancel)
    }

    /// Create a promise that has already succeeded
    ///
    /// - parameter success: the result of the promise
    public convenience init(success: T) {
        self.init(action: {
            (onSuccess, onError) in

            onSuccess(success)
        })
    }

    /// Create a promise that has already failed
    ///
    /// - parameter failed: the error of the promise
    public convenience init(failure: ErrorType) {
        self.init(action: {
            (onSuccess, onError) in

            onError(failure)
        })
    }

    private func onSuccess(res: T) {
        switch (self.state) {
        case .Running:
            self.state = .Success(res)
            for handler in self.handlers {
                handler.succeed(res)
            }
            self.handlers.removeAll()

        case .Cancelled:
            break

        default:
            assert (false)
        }
    }

    private func onError(res: ErrorType) {
        switch (self.state) {
        case .Running:
            self.state = .Error(res)
            for handler in self.handlers {
                handler.fail(res)
            }
            self.handlers.removeAll()

        case .Cancelled:
            break

        default:
            assert (false)
        }
    }

    /// Cancel a running promise.
    ///
    /// This cause the promise to fail with the `.Cancelled` error. If the
    /// action is cancellable, its `onCancel` is called.
    public func cancel() {
        guard case .Running = self.state else {
            return
        }

        self.state = .Cancelled
        self.onCancel?()
        for handler in self.handlers {
            handler.fail(PromiseError.Cancelled)
        }
        self.handlers.removeAll()
    }

    private func registerHandler(success: SuccessHandler?, error: ErrorHandler?) -> Promise<Void> {
        var ph : PromiseHandler<T>?
        let promise = Promise<Void>(action: {
            (onSuccess, onError) in

            ph = PromiseHandler(successHandler: success, errorHandler: error, onSuccess: onSuccess, onError: onError)
        }, onCancel: { self.cancel() })

        assert (ph != nil)

        switch (self.state) {
        case .Success(let result):
            ph?.succeed(result)

        case .Error(let result):
            ph?.fail(result)

        case .Cancelled:
            ph?.fail(PromiseError.Cancelled)

        case .Running:
            self.handlers.append(ph!)
        }
        return promise
    }

    /// Register a callback to be called when the result of the action is known.
    ///
    /// The registered function will be called whenever the result of the promise
    /// is known. If the promise fails, then no callback will the called and the
    /// returned promise will fail, receiving an `UncaughtError` wrapping the
    /// error.
    ///
    /// - note: Several handlers may be registered on the same promise. In that
    ///    case, they are called in their registration order.
    ///
    /// - parameter handler: the callback to call when the promise succeed
    /// - returns: a promise that will be successful if the current promise is
    ///    successful and `handler` does not fails, or fail if the current
    ///    promise fails or `handlers` fails.
    public func then(handler: SuccessHandler) -> Promise<Void> {
        return self.registerHandler(handler, error: nil)
    }

    /// Register a pair of callback and error handler to be called when the
    /// result of the action is known.
    ///
    /// The registered functions will be called whenever the result of the promise
    /// is known. The `handler` is called in case of success, while the `otherwise`
    /// callback is called in case of error.
    ///
    /// - note: Several handlers may be registered on the same promise. In that
    ///    case, they are called in their registration order.
    ///
    /// - parameter handler: the callback to call when the promise succeed
    /// - returns: a promise that will be successful if the current promise is
    ///    successful and `handler` or `otherwise` does not fails, or fail if
    ///    the called function fails.
    public func then(handler: SuccessHandler, otherwise: ErrorHandler) -> Promise<Void> {
        return self.registerHandler(handler, error: otherwise)
    }

    /// Register a callback to be called when the action fails.
    ///
    /// The registered function will be called whenever the promise fails.
    /// If the promise succeeds, then no callback will the called.
    ///
    /// - note: Several handlers may be registered on the same promise. In that
    ///    case, they are called in their registration order.
    ///
    /// - parameter handler: the callback to call when the promise fails
    /// - returns: a promise that will be successful if the current promise is
    ///    successful or if the current promise fails and `handler` does not
    ///    fail, or fail if the current promise fails and `handlers` fails.
    public func otherwise(handler: ErrorHandler) -> Promise<Void> {
        return self.registerHandler(nil, error: handler)
    }

    /// Register a new action to executed in case of success of the promise.
    ///
    /// Chains a new promise when the current promise succeed. This allows chaining
    /// asynchronous actions. When the current promise succeeds, `handler` is
    /// called and returns a new promise. This function wraps that new promise
    /// so that it can be waited for even before `handler` is executed.
    ///
    /// If the current promise fails, then the returned promise will fail
    /// receiving an `UncaughtError`
    ///
    /// - note: Several handlers may be registered on the same promise. In that
    ///    case, they are called in their registration order.
    ///
    /// - parameter handler: the callback to call when the promise succeed
    /// - returns: a promise that will be successful if the current promise is
    ///    successful and the promise retruned by `handler` is successful, or
    ///    fail if the current promise fails or `handlers` fails or the promise
    ///    returned by `handler` fails.
    public func thenChain<OnSubSuccess>(handler: (T) throws -> Promise<OnSubSuccess>) -> Promise<OnSubSuccess> {
        var subPromise : Promise<OnSubSuccess>?

        return Promise<OnSubSuccess>(action: {
            (onSubSuccess, onSubError) in
            self.then() {
                (result) in

                do {
                    subPromise = try handler(result)
                    subPromise!.then(onSubSuccess, otherwise: onSubError)
                } catch let e {
                    onSubError(e)
                }
            }
        }, onCancel: {
            if let promise = subPromise {
                promise.cancel()
            } else {
                self.cancel()
            }
        })
    }

    /// Register a new action to executed in case of error of the promise.
    ///
    /// Chains a new promise when the current promise fails. This allows chaining
    /// asynchronous actions. When the current promise fails, `handler` is
    /// called and returns a new promise. This function wraps that new promise
    /// so that it can be waited for even before `handler` is executed.
    ///
    /// If the current promise fails, then the returned promise will fail
    /// receiving an `UncaughtError`
    ///
    /// - note: Several handlers may be registered on the same promise. In that
    ///    case, they are called in their registration order.
    /// - warning: if the current promise is successful, it won't be chained to
    ///    the returned promise.
    ///
    /// - parameter handler: the callback to call when the promise fails
    /// - returns: a promise that will be successful if the current promise is
    ///    failed and the promise returned by `handler` is successful, or
    ///    fails if `handlers` fails or the promise returned by `handler` fails.
    public func otherwiseChain<OnSubSuccess>(handler: (ErrorType) throws -> Promise<OnSubSuccess>) -> Promise<OnSubSuccess> {
        var subPromise : Promise<OnSubSuccess>?

        return Promise<OnSubSuccess>(action: {
            (onSubSuccess, onSubError) in
            self.otherwise() {
                (result) in

                do {
                    subPromise = try handler(result)
                    subPromise!.then(onSubSuccess, otherwise: onSubError)
                } catch let e {
                    onSubError(e)
                }
            }
        }, onCancel: {
            if let promise = subPromise {
                promise.cancel()
            } else {
                self.cancel()
            }
        })
    }
}