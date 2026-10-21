import SwiftUI

/// Sunrise/sunset via the NOAA approximation, good to about a minute.
enum Sun {
    // A chosen place instead of CoreLocation, so the app never needs location access.
    static var latitude: Double { UserDefaults.standard.object(forKey: "sunLatitude") as? Double ?? 47.66 }
    static var longitude: Double { UserDefaults.standard.object(forKey: "sunLongitude") as? Double ?? 11.37 }
    static var placeName: String { UserDefaults.standard.string(forKey: "sunPlace") ?? "Kochel am See" }

    static func setPlace(name: String, latitude: Double, longitude: Double) {
        let d = UserDefaults.standard
        d.set(name, forKey: "sunPlace")
        d.set(latitude, forKey: "sunLatitude")
        d.set(longitude, forKey: "sunLongitude")
    }

    struct Times { let rise: Date; let set: Date }

    static func times(for day: Date, cal: Calendar = .de) -> Times? {
        guard let n = cal.ordinality(of: .day, in: .year, for: day),
              let rise = event(rising: true, dayOfYear: n, day: day, cal: cal),
              let set = event(rising: false, dayOfYear: n, day: day, cal: cal) else { return nil }
        return Times(rise: rise, set: set)
    }

    private static func event(rising: Bool, dayOfYear: Int, day: Date, cal: Calendar) -> Date? {
        let rad = Double.pi / 180
        let lngHour = longitude / 15
        let t = Double(dayOfYear) + ((rising ? 6 : 18) - lngHour) / 24
        let m = 0.9856 * t - 3.289
        var l = m + 1.916 * sin(m * rad) + 0.020 * sin(2 * m * rad) + 282.634
        l = l.truncatingRemainder(dividingBy: 360); if l < 0 { l += 360 }
        var ra = atan(0.91764 * tan(l * rad)) / rad
        ra = ra.truncatingRemainder(dividingBy: 360); if ra < 0 { ra += 360 }
        ra = (ra + floor(l / 90) * 90 - floor(ra / 90) * 90) / 15
        let sinDec = 0.39782 * sin(l * rad)
        let cosDec = cos(asin(sinDec))
        let cosH = (cos(90.833 * rad) - sinDec * sin(latitude * rad)) / (cosDec * cos(latitude * rad))
        guard (-1...1).contains(cosH) else { return nil }
        let h = (rising ? 360 - acos(cosH) / rad : acos(cosH) / rad) / 15
        var ut = (h + ra - 0.06571 * t - 6.622 - lngHour).truncatingRemainder(dividingBy: 24)
        if ut < 0 { ut += 24 }

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.year, .month, .day], from: day)
        guard let midnight = utc.date(from: comps) else { return nil }
        return midnight.addingTimeInterval(ut * 3600)
    }
}

enum SkyPhase {
    case night, dawn, day, dusk

    static func at(_ now: Date) -> SkyPhase {
        guard let sun = Sun.times(for: now) else { return .day }
        let window: TimeInterval = 50 * 60
        if abs(now.timeIntervalSince(sun.rise)) < window { return .dawn }
        if abs(now.timeIntervalSince(sun.set)) < window { return .dusk }
        return (now > sun.rise && now < sun.set) ? .day : .night
    }

    var colors: [Color] {
        switch self {
        case .night: [Color(hex: 0x27346E), Color(hex: 0x4B2C6F)]
        case .dawn: [Color(hex: 0x6B5BA8), Color(hex: 0xF29A6B)]
        case .day: [Color(hex: 0x3D86E0), Color(hex: 0x7FC0FF)]
        case .dusk: [Color(hex: 0x7D4A9E), Color(hex: 0xF2895A)]
        }
    }

    var symbol: String {
        switch self {
        case .night: "moon.stars.fill"
        case .dawn: "sunrise.fill"
        case .day: "sun.max.fill"
        case .dusk: "sunset.fill"
        }
    }
}

struct SkyBackground: View {
    let phase: SkyPhase

    var body: some View {
        LinearGradient(colors: phase.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .opacity(0.38)
            .mask(LinearGradient(colors: [.black, .black.opacity(0.35), .clear],
                                 startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.6)))
            .animation(.easeInOut(duration: 1.2), value: phase)
            .allowsHitTesting(false)
    }
}
