import SwiftUI

final class WeatherModule: IslandModule {
    @ObservedObject private var service = WeatherService.shared

    init() {
        super.init(id: "weather", name: "天气", icon: "sun.max.fill", priority: 10)
    }

    override func compactView() -> AnyView {
        AnyView(WeatherCompact())
    }

    override func expandedView() -> AnyView {
        AnyView(WeatherExpanded())
    }

    override func isRelevant() -> Bool {
        false // Weather is default/background, not a scene trigger
    }

    override func startMonitoring() {
        service.start()
    }

    override func stopMonitoring() {
        service.stop()
    }
}

// MARK: - Compact View

struct WeatherCompact: View {
    @ObservedObject private var service = WeatherService.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: service.symbolName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)

            Text(service.displayTemperature())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)

            if !service.cityName.isEmpty {
                Text(service.cityName)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        
    }
}

// MARK: - Expanded View

struct WeatherExpanded: View {
    @ObservedObject private var service = WeatherService.shared

    var body: some View {
        VStack(spacing: 16) {
            // Current conditions
            HStack(spacing: 12) {
                Image(systemName: service.symbolName)
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.displayTemperature())
                        .font(.system(size: 32, weight: .light, design: .rounded))
                        .foregroundStyle(.white)

                    Text(service.condition)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Label(
                        "\(Int(round(service.humidity * 100)))%",
                        systemImage: "humidity.fill"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))

                    Label(
                        "\(Int(round(service.windSpeed))) km/h",
                        systemImage: "wind"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                }
            }

            Divider()
                .background(.white.opacity(0.1))

            // Hourly forecast
            if !service.hourlyForecast.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("逐小时")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(service.hourlyForecast) { hour in
                                VStack(spacing: 4) {
                                    Text(hour.hour)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))

                                    Image(systemName: hour.symbol)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .frame(height: 20)

                                    Text("\(Int(round(hour.temp)))°")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
            }

            Divider()
                .background(.white.opacity(0.1))

            // Daily forecast
            if !service.dailyForecast.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("5日预报")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))

                    VStack(spacing: 4) {
                        ForEach(service.dailyForecast) { day in
                            HStack(spacing: 12) {
                                Text(day.day)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(width: 30, alignment: .leading)

                                Image(systemName: day.symbol)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(width: 20)

                                Text("\(Int(round(day.low)))°")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(width: 30, alignment: .trailing)

                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.white.opacity(0.15))
                                        .frame(height: 4)

                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.white.opacity(0.5))
                                        .frame(width: geo.size.width * 0.5, height: 4)
                                }
                                .frame(height: 4)

                                Text("\(Int(round(day.high)))°")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 30, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
    }
}
