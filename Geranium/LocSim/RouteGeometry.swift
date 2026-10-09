import CoreLocation

enum RouteGeometry {
    static func interpolate(_ coords: [CLLocationCoordinate2D], speed: Double,
                            interval: Double) -> [CLLocationCoordinate2D] {
        guard coords.count >= 2, speed.isFinite, interval.isFinite,
              speed > 0, interval > 0 else { return coords }
        let step = speed * interval
        guard step.isFinite else { return coords }
        var result = [coords[0]]
        var carry = 0.0
        for i in 1..<coords.count {
            let from = coords[i - 1], to = coords[i]
            let distance = CLLocation(latitude: from.latitude, longitude: from.longitude)
                .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
            guard distance.isFinite, distance > 0 else { continue }
            var next = step - carry
            while next <= distance {
                let fraction = next / distance
                result.append(CLLocationCoordinate2D(
                    latitude: from.latitude + (to.latitude - from.latitude) * fraction,
                    longitude: from.longitude + (to.longitude - from.longitude) * fraction))
                next += step
            }
            carry = distance - (next - step)
        }
        if let last = coords.last,
           result.last!.latitude != last.latitude || result.last!.longitude != last.longitude {
            result.append(last)
        }
        return result
    }
}
