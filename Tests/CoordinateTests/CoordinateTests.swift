import XCTest
import CoreLocation
@testable import AndromedaCoordinates

final class CoordinateTests: XCTestCase {
    let nagoya = CLLocationCoordinate2D(latitude: 35.170900, longitude: 136.881500)
    let tokyo = CLLocationCoordinate2D(latitude: 35.681236, longitude: 139.767125)
    let beijing = CLLocationCoordinate2D(latitude: 39.908823, longitude: 116.397470)
    func equal(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.latitude, b.latitude, file: file, line: line)
        XCTAssertEqual(a.longitude, b.longitude, file: file, line: line)
    }
    func testNagoyaUnchangedEvenWhenCorrectionOn() {
        equal(CoordTransform.gcj02ToWgs84(nagoya), nagoya)
        equal(CoordTransform.wgs84ToGcj02(nagoya), nagoya)
        equal(CoordinatePolicy.mapToWGS84(nagoya, correctionEnabled: true), nagoya)
    }
    func testTokyoUnchanged() {
        equal(CoordinatePolicy.mapToWGS84(tokyo, correctionEnabled: true), tokyo)
        equal(CoordinatePolicy.mapToWGS84(tokyo, correctionEnabled: false), tokyo)
    }
    func testJapanAndNeighborsAreOutsideGuard() {
        for (lat, lon) in [(43.06,141.35),(34.69,135.50),(32.75,129.88),(26.21,127.68),
                           (24.34,124.16),(24.45,122.94),(27.09,142.19),(37.56,126.97),
                           (25.03,121.56),(22.28,114.16),(22.19,113.54)] {
            let c = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            XCTAssertFalse(ChinaCoordinateRegion.contains(c))
            equal(CoordinatePolicy.mapToWGS84(c, correctionEnabled: true), c)
        }
    }
    func testChinaOffPreservesWGS84() {
        equal(CoordinatePolicy.mapToWGS84(beijing, correctionEnabled: false), beijing)
        equal(CoordinatePolicy.wgs84ToMap(beijing, correctionEnabled: false), beijing)
    }
    func testChineseConversionKnownVector() {
        let gcj = CoordinatePolicy.wgs84ToMap(beijing, correctionEnabled: true)
        XCTAssertEqual(gcj.latitude, 39.9102265, accuracy: 0.000001)
        XCTAssertEqual(gcj.longitude, 116.4037136, accuracy: 0.000001)
        let restored = CoordinatePolicy.mapToWGS84(gcj, correctionEnabled: true)
        XCTAssertLessThan(CLLocation(latitude: restored.latitude, longitude: restored.longitude)
            .distance(from: CLLocation(latitude: beijing.latitude, longitude: beijing.longitude)), 2)
    }
    func testMainlandCitiesAndHainan() {
        for (lat,lon) in [(39.9,116.4),(31.23,121.47),(30.57,104.07),(23.13,113.26),(19.2,109.7)] {
            XCTAssertTrue(ChinaCoordinateRegion.contains(CLLocationCoordinate2D(latitude: lat, longitude: lon)))
        }
    }
    func testGPXPreservesTrackIncludingMiddlePoint() throws {
        let xml = "<gpx><trk><trkseg><trkpt lat='35.170900' lon='136.881500'/><trkpt lat='35.171' lon='136.882'/><trkpt lat='35.681236' lon='139.767125'/></trkseg></trk></gpx>"
        let parsed = try XCTUnwrap(GPXParser.parse(data: Data(xml.utf8)))
        XCTAssertEqual(parsed.allCoordinates.count, 3)
        equal(parsed.allCoordinates[0], nagoya)
        equal(parsed.allCoordinates[2], tokyo)
        XCTAssertEqual(parsed.allCoordinates[1].longitude, 136.882)
    }
    func testChineseGPXIsNotDecoded() throws {
        let xml = "<gpx><rte><rtept lat='39.908823' lon='116.397470'/></rte></gpx>"
        let parsed = try XCTUnwrap(GPXParser.parse(data: Data(xml.utf8)))
        equal(try XCTUnwrap(parsed.allCoordinates.first), beijing)
    }
    func testInvalidGPXDoesNotReusePreviousCoordinates() throws {
        let xml = "<gpx><wpt lat='35.1709' lon='136.8815'/><wpt lat='bad' lon='0'/><trkpt lat='91' lon='0'/></gpx>"
        let parsed = try XCTUnwrap(GPXParser.parse(data: Data(xml.utf8)))
        XCTAssertEqual(parsed.allCoordinates.count, 1)
        equal(parsed.allCoordinates[0], nagoya)
    }
    func testRouteEndpointsAndSpeed() {
        let end = CLLocationCoordinate2D(latitude: nagoya.latitude + 0.001, longitude: nagoya.longitude)
        let slow = RouteGeometry.interpolate([nagoya,end], speed: 1.4, interval: 1)
        let fast = RouteGeometry.interpolate([nagoya,end], speed: 5.5, interval: 1)
        equal(slow.first!,nagoya); equal(slow.last!,end)
        XCTAssertGreaterThan(slow.count,fast.count)
        for pair in zip(slow,slow.dropFirst()).dropLast() {
            let d = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                .distance(from: CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude))
            XCTAssertEqual(d,1.4,accuracy:0.01)
        }
    }
    func testShortSegmentsCarryDistance() {
        let points = (0...20).map { CLLocationCoordinate2D(latitude: 35 + Double($0) * 0.000001, longitude: 136) }
        let result = RouteGeometry.interpolate(points, speed: 1, interval: 1)
        XCTAssertEqual(result.count,4)
        equal(result.first!,points.first!); equal(result.last!,points.last!)
    }
    func testEmptyDuplicateAndInvalidSpeed() {
        XCTAssertTrue(RouteGeometry.interpolate([],speed:1,interval:1).isEmpty)
        XCTAssertEqual(RouteGeometry.interpolate([nagoya,nagoya],speed:1,interval:1).count,1)
        XCTAssertEqual(RouteGeometry.interpolate([nagoya,tokyo],speed:0,interval:1).count,2)
    }
}
