import Foundation

nonisolated enum Tolerance: Equatable, Sendable {
    case strict
    case tolerant(abs: Double, rel: Double)

    static let defaultTolerant: Tolerance = .tolerant(abs: 1e-9, rel: 1e-6)

    var isStrict: Bool {
        if case .strict = self { return true }
        return false
    }
}
