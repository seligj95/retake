import Foundation

enum AppVersion {
    /// Current app version — update this when releasing a new version.
    static let current = "1.0.0"

    /// Compare two semantic version strings. Returns:
    ///  - `.orderedAscending` if lhs < rhs (update available)
    ///  - `.orderedSame` if equal
    ///  - `.orderedDescending` if lhs > rhs
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lParts = lhs.split(separator: ".").compactMap { Int($0) }
        let rParts = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(lParts.count, rParts.count)
        for i in 0..<count {
            let l = i < lParts.count ? lParts[i] : 0
            let r = i < rParts.count ? rParts[i] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }
}
