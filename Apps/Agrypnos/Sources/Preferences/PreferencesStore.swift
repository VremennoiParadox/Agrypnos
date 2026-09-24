import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

final class PreferencesStore {
    static let key = "agrypnos.preferences.v1"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UserPreferences {
        guard let data = defaults.data(forKey: Self.key) else { return .default }
        return (try? JSONDecoder().decode(UserPreferences.self, from: data)) ?? .default
    }

    func save(_ preferences: UserPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: Self.key)
        }
        defaults.set(preferences.batteryFloorPercent, forKey: "batteryFloorPercent")
    }

    static let telegramInboundOffsetKey = "agrypnos.telegramInbound.offset"

    func loadTelegramInboundOffset() -> Int64 {
        Int64(defaults.integer(forKey: Self.telegramInboundOffsetKey))
    }

    func saveTelegramInboundOffset(_ value: Int64) {
        defaults.set(value, forKey: Self.telegramInboundOffsetKey)
    }
}
