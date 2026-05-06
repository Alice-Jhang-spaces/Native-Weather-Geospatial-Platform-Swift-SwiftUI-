import SwiftUI

@main
struct WeatherAppMacApp: App {
    var body: some Scene {
        WindowGroup("Weather") {
            ContentView()
                .frame(minWidth: 460, minHeight: 600)
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = WeatherViewModel()
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                content
            }
            .navigationTitle("Weather")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await vm.useCurrentLocation() }
                    } label: {
                        Label("Use my location", systemImage: "location.fill")
                    }
                    .help("Use my current location")
                    .disabled(vm.loading)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.loading {
            Spacer(); ProgressView(); Spacer()
        } else if let selected = vm.selected, let weather = vm.weather {
            WeatherDetailView(place: selected, weather: weather)
        } else if !vm.results.isEmpty {
            List(vm.results) { r in
                Button { Task { await vm.pick(r) } } label: {
                    VStack(alignment: .leading) {
                        Text(r.name).font(.headline)
                        Text([r.admin1, r.country].compactMap { $0 }.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        } else if let error = vm.error {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 56))
                    .symbolRenderingMode(.multicolor)
                Text("Search a city or use your location").font(.title3)
                Button {
                    Task { await vm.useCurrentLocation() }
                } label: {
                    Label("Use my location", systemImage: "location.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("City", text: $vm.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onAppear { searchFocused = true }
                .onSubmit { Task { await vm.search() } }
            if !vm.query.isEmpty {
                Button {
                    vm.reset()
                } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding()
    }
}

struct WeatherDetailView: View {
    let place: GeoResult
    let weather: WeatherResponse

    var body: some View {
        let info = WeatherCode.describe(weather.current_weather.weathercode)
        ScrollView {
            VStack(spacing: 16) {
                Text(place.displayName).font(.title2).multilineTextAlignment(.center)
                Image(systemName: info.symbol)
                    .font(.system(size: 88))
                    .symbolRenderingMode(.multicolor)
                Text("\(Int(weather.current_weather.temperature.rounded()))°")
                    .font(.system(size: 72, weight: .thin))
                Text(info.label).font(.headline).foregroundStyle(.secondary)
                Text("Wind \(Int(weather.current_weather.windspeed)) km/h")
                    .font(.subheadline).foregroundStyle(.secondary)

                Divider().padding(.vertical, 8)

                Text("7-day forecast").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                ForEach(0..<weather.daily.time.count, id: \.self) { i in
                    let d = WeatherCode.describe(weather.daily.weathercode[i])
                    HStack {
                        Text(weather.daily.time[i]).frame(width: 110, alignment: .leading)
                        Image(systemName: d.symbol).symbolRenderingMode(.multicolor).frame(width: 30)
                        Spacer()
                        Text("\(Int(weather.daily.temperature_2m_min[i].rounded()))° / \(Int(weather.daily.temperature_2m_max[i].rounded()))°")
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }
            }
            .padding()
        }
    }
}
