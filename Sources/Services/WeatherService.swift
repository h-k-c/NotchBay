import Foundation
import Combine
import WeatherKit
import CoreLocation

/// Fetches weather data using Apple WeatherKit
@MainActor
final class WeatherService: ObservableObject {
    static let shared = WeatherService()

    @Published var temperature: Double = 0
    @Published var condition: String = "—"
    @Published var symbolName: String = "cloud.sun.fill"
    @Published var humidity: Double = 0
    @Published var windSpeed: Double = 0
    @Published var hourlyForecast: [HourlyData] = []
    @Published var dailyForecast: [DailyData] = []
    @Published var cityName: String = ""

    private let weatherKitService = WeatherKit.WeatherService.shared
    private var timer: Timer?
    private static let defaultLocation = CLLocation(latitude: 37.3230, longitude: -122.0322)

    struct HourlyData: Identifiable {
        let id = UUID()
        let hour: String
        let temp: Double
        let symbol: String
    }

    struct DailyData: Identifiable {
        let id = UUID()
        let day: String
        let high: Double
        let low: Double
        let symbol: String
    }

    private init() {}

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Constants.weatherUpdateInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        Task {
            do {
                let location = Self.defaultLocation
                let forecast = try await weatherKitService.weather(for: location)

                await MainActor.run {
                    let current = forecast.currentWeather
                    self.temperature = current.temperature.value
                    self.condition = current.condition.description
                    self.symbolName = current.symbolName
                    self.humidity = current.humidity
                    self.windSpeed = current.wind.speed.value

                    // Hourly (next 6 hours)
                    self.hourlyForecast = forecast.hourlyForecast.prefix(6).map {
                        let hour = Self.hourFormatter.string(from: $0.date)
                        return HourlyData(
                            hour: hour,
                            temp: $0.temperature.value,
                            symbol: $0.symbolName
                        )
                    }

                    // Daily (next 5 days)
                    self.dailyForecast = forecast.dailyForecast.prefix(5).map {
                        DailyData(
                            day: Self.dayFormatter.string(from: $0.date),
                            high: $0.highTemperature.value,
                            low: $0.lowTemperature.value,
                            symbol: $0.symbolName
                        )
                    }
                }
            } catch {
                Logging.weather("Failed to fetch: \(error.localizedDescription)")
            }
        }
    }

    func displayTemperature() -> String {
        guard hasData else { return "—" }
        let rounded = Int(round(temperature))
        return "\(rounded)°"
    }

    private var hasData: Bool { symbolName != "cloud.sun.fill" || humidity > 0 }

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
}
