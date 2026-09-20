import XCTest
#if SWIFT_PACKAGE
@testable import PeripheralKit
#endif

final class DrevoLayoutTests: XCTestCase {
    func testLayoutContainsEveryPhysicalKeyExactlyOnce() {
        XCTAssertEqual(DrevoTKLLayout.keys.count, 87)
        XCTAssertEqual(Set(DrevoTKLLayout.keys.map(\.id)).count, 87)
        XCTAssertEqual(Set(DrevoKeyID.allCases).count, 87)
        XCTAssertEqual(DrevoTKLLayout.byID.count, 87)
    }

    func testRowsMatchANSICompactTKLStructure() {
        let counts = Dictionary(grouping: DrevoTKLLayout.keys, by: \.y).mapValues(\.count)
        XCTAssertEqual(counts[0], 16)
        XCTAssertEqual(counts[1.75], 17)
        XCTAssertEqual(counts[2.75], 17)
        XCTAssertEqual(counts[3.75], 13)
        XCTAssertEqual(counts[4.75], 13)
        XCTAssertEqual(counts[5.75], 11)
    }

    func testFunctionAndNavigationKeysArePresent() {
        let required: Set<DrevoKeyID> = [
            .escape, .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8,
            .f9, .f10, .f11, .f12, .printScreen, .scrollLock, .pause,
            .insert, .home, .pageUp, .delete, .end, .pageDown,
        ]
        XCTAssertTrue(required.isSubset(of: Set(DrevoTKLLayout.keys.map(\.id))))
    }

    func testWideKeyGeometry() throws {
        XCTAssertEqual(try key(.backspace).width, 2)
        XCTAssertEqual(try key(.tab).width, 1.5)
        XCTAssertEqual(try key(.capsLock).width, 1.75)
        XCTAssertEqual(try key(.enter).width, 2.25)
        XCTAssertEqual(try key(.leftShift).width, 2.25)
        XCTAssertEqual(try key(.rightShift).width, 2.75)
        XCTAssertEqual(try key(.space).width, 6.25)
    }

    func testArrowClusterIsAnInvertedT() throws {
        let up = try key(.arrowUp)
        let left = try key(.arrowLeft)
        let down = try key(.arrowDown)
        let right = try key(.arrowRight)

        XCTAssertEqual(up.x, down.x)
        XCTAssertLessThan(up.y, down.y)
        XCTAssertEqual(left.y, down.y)
        XCTAssertEqual(right.y, down.y)
        XCTAssertLessThan(left.x, down.x)
        XCTAssertGreaterThan(right.x, down.x)
    }

    func testKeysStayInsideBoundsAndDoNotOverlap() {
        for key in DrevoTKLLayout.keys {
            XCTAssertGreaterThanOrEqual(key.x, 0, key.id.rawValue)
            XCTAssertGreaterThanOrEqual(key.y, 0, key.id.rawValue)
            XCTAssertLessThanOrEqual(key.x + key.width, DrevoTKLLayout.width, key.id.rawValue)
            XCTAssertLessThanOrEqual(key.y + key.height, DrevoTKLLayout.height, key.id.rawValue)
        }

        for firstIndex in DrevoTKLLayout.keys.indices {
            for secondIndex in DrevoTKLLayout.keys.indices where secondIndex > firstIndex {
                let first = DrevoTKLLayout.keys[firstIndex]
                let second = DrevoTKLLayout.keys[secondIndex]
                XCTAssertFalse(overlaps(first, second), "\(first.id) overlaps \(second.id)")
            }
        }
    }

    private func key(_ id: DrevoKeyID) throws -> DrevoKeyDescriptor {
        try XCTUnwrap(DrevoTKLLayout.byID[id])
    }

    private func overlaps(_ lhs: DrevoKeyDescriptor, _ rhs: DrevoKeyDescriptor) -> Bool {
        let horizontal = lhs.x < rhs.x + rhs.width && rhs.x < lhs.x + lhs.width
        let vertical = lhs.y < rhs.y + rhs.height && rhs.y < lhs.y + lhs.height
        return horizontal && vertical
    }
}
