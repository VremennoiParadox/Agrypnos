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
    static let telegramInboundSeededKey = "agrypnos.telegramInbound.seeded"

    func loadTelegramInboundCursor() -> TelegramInboundCursor {
        TelegramInboundCursor(
            offset: Int64(defaults.integer(forKey: Self.telegramInboundOffsetKey)),
            seeded: defaults.bool(forKey: Self.telegramInboundSeededKey)
        )
    }

    func saveTelegramInboundCursor(_ cursor: TelegramInboundCursor) {
        defaults.set(cursor.offset, forKey: Self.telegramInboundOffsetKey)
        defaults.set(cursor.seeded, forKey: Self.telegramInboundSeededKey)
    }

    func resetTelegramInboundCursor() {
        defaults.removeObject(forKey: Self.telegramInboundOffsetKey)
        defaults.removeObject(forKey: Self.telegramInboundSeededKey)
    }
}
