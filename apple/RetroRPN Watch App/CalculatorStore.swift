import Foundation
import RetroRPNEngine

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
