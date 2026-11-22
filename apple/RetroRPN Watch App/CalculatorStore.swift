import Foundation
import RetroRPNEngine

enum StackOrder {
    private static let key = "retrorpn.stackXOnTop"

    /// False draws the manual's stack, with X at the bottom. True puts X on top.
    static var xOnTop: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

enum CalculatorStore {
    private static let key = "retrorpn.state"

    static func load() -> RPNCalculator.Model? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? decoder.decode(RPNCalculator.Model.self, from: data)
    }

    static func save(_ model: RPNCalculator.Model) {
        guard let data = try? encoder.encode(model) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        return decoder
    }
}
