import Testing
@testable import ActorsStudio


@Test func testCachePeek() throws {
    let cache = ImageLoader()
    let url = URL(string: "example.com")!
    let img = cache.peek(url)
    #expect(img == nil)
}


@Test func example() throws {
    let result = try synchronize {
        await Task {
            sleep(2)
            return "Task I"
        }.value
//        performAsyncTask
    }
    print (#line, result)
    let r2 = try synchronize {
        await Task {
            sleep(1)
            return "Task II"
        }.value
//        performAsyncTask
    }
    print (#line, result, r2)
}

func performAsyncTask(completion: @Sendable @escaping (String) -> Void) {
    DispatchQueue.global().async {
        // Simulating a network call or heavy computation
        sleep(2)
        completion("Task Completed")
    }
}

import XCTest

// If Promise is in a separate module, import that module here.
// For this example, we assume the Promise class is accessible.
final class PromiseTests: XCTestCase {

    func testFulfillReturnsValue() {
        let promise = Promise<Int>()
        
        // Simulate asynchronous fulfillment
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            promise.fulfill(123)
        }
        
        do {
            let value = try promise.wait(timeout: 2)
            XCTAssertEqual(value, 123)
        } catch {
            XCTFail("Expected promise to fulfill, but got error: \(error)")
        }
    }
    
    func testRejectThrowsError() {
        let promise = Promise<Int>()
        let expectedError = NSError(domain: "TestDomain", code: 42, userInfo: nil)
        
        // Simulate asynchronous rejection
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            promise.reject(expectedError)
        }
        
        XCTAssertThrowsError(try promise.wait(timeout: 2)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "TestDomain")
            XCTAssertEqual(nsError.code, 42)
        }
    }
    
    func testTimeoutOccurs() {
        let promise = Promise<Int>()
        // Do not fulfill or reject to force a timeout

        XCTAssertThrowsError(try promise.wait(timeout: 1)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "PromiseError")
            XCTAssertEqual(nsError.code, 1)
        }
    }
    
    func testConcurrentAccess() {
        let promise = Promise<Int>()
        let group = DispatchGroup()
        let numberOfConcurrentWaiters = 10
        
        for _ in 1...numberOfConcurrentWaiters {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                do {
                    let value = try promise.wait(timeout: 3)
                    XCTAssertEqual(value, 999)
                } catch {
                    XCTFail("Concurrent access failed with error: \(error)")
                }
            }
        }
        
        // Fulfill the promise after a delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            promise.fulfill(999)
        }
        
        // Wait for all concurrent accesses to complete
        let waitResult = group.wait(timeout: .now() + 4)
        XCTAssertEqual(waitResult, .success, "Not all concurrent waits completed successfully")
    }
}
