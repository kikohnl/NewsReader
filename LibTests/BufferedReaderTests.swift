//
//  BufferedReaderTest.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import XCTest
import Lib

class BufferedReaderTests: XCTestCase {
    private func checkLine(buf: BufferedReader, exp: String?) {
        do {
            let line = try buf.readDataUpTo("\r\n", keepBound: false, endOfStreamIsBound: true)

            if exp == nil {
                XCTAssertNil(line)
            } else {
                XCTAssertNotNil(line)
                XCTAssertEqual(line!, (exp! as NSString).dataUsingEncoding(NSUTF8StringEncoding))
            }
        } catch BufferedReader.Error.ReadError {
            XCTAssert(false)
        } catch {
            XCTAssert(false)
        }
    }

    private func assertThrow(fc: (Void) throws -> Void) {
        do {
            try fc()
            XCTAssert(false)
        } catch {
            XCTAssert(true)
        }
    }

    func testReadLineNewline() {
        let buf = BufferedReader(fromString: "a\r\nbcd\r\ne\r\n\r\n")

        XCTAssertNotNil(buf)
        self.checkLine(buf!, exp: "a")
        self.checkLine(buf!, exp: "bcd")
        self.checkLine(buf!, exp: "e")
        self.checkLine(buf!, exp: "")
        self.checkLine(buf!, exp: nil)
    }

    func testReadLineNonNewline() {
        let buf = BufferedReader(fromString: "a\r\nbcd\r\ne")

        XCTAssertNotNil(buf)
        self.checkLine(buf!, exp: "a")
        self.checkLine(buf!, exp: "bcd")
        self.checkLine(buf!, exp: "e")
        self.checkLine(buf!, exp: nil)
    }
}
