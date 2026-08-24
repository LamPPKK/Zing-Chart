import Cocoa
import FlutterMacOS
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testDeepLinkQueueKeepsLatestURLUntilConsumed() throws {
    let queue = ZingChartDeepLinkQueue()
    let first = try XCTUnwrap(URL(string: "zingchart://open?url=first"))
    let second = try XCTUnwrap(URL(string: "zingchart://open?url=second"))

    queue.enqueue(first)
    queue.enqueue(second)

    XCTAssertEqual(queue.pendingURL, second)
    XCTAssertEqual(queue.take(), second)
    XCTAssertNil(queue.pendingURL)
  }

}
