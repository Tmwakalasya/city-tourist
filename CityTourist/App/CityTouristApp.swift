import SwiftUI

@main
struct CityTouristApp: App {
    /// The unit tests run inside this app. While they do, it stays idle: no
    /// saved state loaded into the shared directories, nothing written back,
    /// and no Explore feed spending Places quota on every test run.
    static let isRunningTests: Bool = {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }()

    @State private var store = AppStore(loadFromDisk: !CityTouristApp.isRunningTests)
    @State private var catalog = PlaceCatalog()
    @State private var weather = WeatherStore()
    @State private var routes = RouteStore()
    @State private var events = EventCatalog()
    @State private var shorts = PlaceShorts()
    @State private var authentication = AuthenticationStore()
    @State private var avatar = AvatarStore()

    var body: some Scene {
        WindowGroup {
            if Self.isRunningTests {
                Color.clear
            } else {
                RootTabView()
                    .environment(\.locale, store.profile.language.locale)
                    .environment(authentication)
                    .environment(avatar)
                    .task { await authentication.restoreSession() }
                    .environment(store)
                    .environment(catalog)
                    .environment(weather)
                    .environment(routes)
                    .environment(events)
                    .environment(shorts)
                    .tint(Brand.rausch)
            }
        }
    }
}
