//
//  PromiseTests.swift
//  NewsReader
//
//  Created by Florent Bruneau on 18/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import XCTest
import NewsReader

private enum Error : ErrorType {
    case Fail
}

private func preparePromise(action: (String) -> Void) -> ((Void) -> Void, (ErrorType) -> Void) {
    var onSuccess : ((Void) -> Void)?
    var onError : ((ErrorType) -> Void)?
    let promise = Promise<Void>() {
        (s, e) in

        onSuccess = s
        onError = e
    }

    promise.then({
        action("1")
    }).then({
        action("1.1")
    }).otherwise({
        (_) in

        action("1.1.2")
    }).then({
        action("1.1.2.1")
    })

    promise.otherwise({
        (_) in

        action("2")
    }).then({
        action("2.1")

        throw Error.Fail
    }).otherwise({
        (_) in

        action("2.1.2")
    })

    return (onSuccess!, onError!)
}

class PromiseTests : XCTestCase {
    func testBase() {
        var out : [String] = []

        out.removeAll()
        preparePromise({ (s) in out.append(s) }).0()
        XCTAssertEqual(out, [ "1", "1.1", "1.1.2.1", "2.1", "2.1.2" ])

        out.removeAll()
        preparePromise({ (s) in out.append(s) }).1(Error.Fail)
        XCTAssertEqual(out, [ "1.1.2", "1.1.2.1", "2", "2.1", "2.1.2" ])
    }

    func testChain() {
        var out : [String] = []
        var onSuccess : ((Void) -> Void)?
        let promise = Promise<Void>() {
            (s, _) in
            onSuccess = s
        }

        promise.then({
            out.append("1")
        }).thenChain({
            out.append("2")
            return Promise<Void>(action: {
                (s, _) in

                onSuccess = s
            })
        }).then({
            out.append("3")
        })

        XCTAssert(onSuccess != nil)
        XCTAssertEqual(out, [])
        if let cb = onSuccess {
            onSuccess = nil
            cb()
        }
        XCTAssertEqual(out, ["1", "2"])

        XCTAssert(onSuccess != nil)
        onSuccess?()
        XCTAssertEqual(out, ["1", "2", "3"])
    }
}