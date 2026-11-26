//  Andromeda LocSim - Route Extension
//  Created by son3ra1n.

import SwiftUI
import MapKit
import AlertKit

struct RouteSimSheet: View {
    @ObservedObject var routeSimulator: RouteSimulator
    @Binding var mapRegion: MKCoordinateRegion?
    @Binding var isPresented: Bool
    
    @State private var startText: String = ""
    @State private var endText: String = ""
    @State private var startCoord: CLLocationCoordinate2D? = nil
    @State private var endCoord: CLLocationCoordinate2D? = nil
    @State private var selectedMode: TravelMode = .driving
    @State private var isSearchingStart: Bool = false
    @State private var isSearchingEnd: Bool = false
    @State private var startResults: [MKMapItem] = []
    @State private var endResults: [MKMapItem] = []
    @State private var activeField: ActiveField = .none
    @State private var routeReady: Bool = false
    @State private var speedMultiplier: Double = 1.0
    @State private var showGPXPicker: Bool = false
    @State private var importedGPX: [CLLocationCoordinate2D]? = nil
    
    @State private var mapPickingField: ActiveField?
    @State private var previewRegion: MKCoordinateRegion?
    @State private var routeError: String?

    enum ActiveField: String, Identifiable {
        case none, start, end
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Route Status (when simulating)
                    if routeSimulator.isSimulating {
                        simulationStatusCard
                    } else {
                        // MARK: - Start Point
                        locationCard(
                            title: "Start Point",
                            icon: "play.circle.fill",
                            iconColor: .green,
                            text: $startText,
                            isSearching: isSearchingStart,
                            results: startResults,
                            selectedCoord: startCoord,
                            field: .start
                        )
                        
                        // Arrow between cards
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        
                        // MARK: - End Point
                        locationCard(
                            title: "Destination",
                            icon: "flag.checkered.circle.fill",
                            iconColor: .red,
                            text: $endText,
                            isSearching: isSearchingEnd,
                            results: endResults,
                            selectedCoord: endCoord,
                            field: .end
                        )
                        
                        // MARK: - Travel Mode
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Travel Mode")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                ForEach(TravelMode.allCases, id: \.self) { mode in
                                    Button(action: {
                                        selectedMode = mode
                                        invalidateRoute()
                                        if startCoord != nil && endCoord != nil { calculateRoute() }
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: mode.icon)
                                                .font(.title2)
                                            Text(mode.rawValue)
                                                .font(.caption)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedMode == mode ?
                                                      Color.accentColor.opacity(0.2) :
                                                      Color(UIColor.secondarySystemBackground))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedMode == mode ?
                                                        Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                    }
                                    .foregroundColor(selectedMode == mode ? .accentColor : .primary)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // MARK: - Speed Multiplier
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Speed")
                                    .font(.headline)
                                Spacer()
                                Text("\(String(format: "%.1f", speedMultiplier))x (\(formattedSpeed))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            Slider(value: $speedMultiplier, in: 0.5...10.0, step: 0.5)
                                .padding(.horizontal)
                                .onChange(of: speedMultiplier) { _ in
                                    if routeReady, importedGPX == nil {
                                        routeSimulator.updateSpeedMultiplier(speedMultiplier)
                                    } else if startCoord != nil && endCoord != nil {
                                        calculateRoute()
                                    }
                                }
                        }
                        
                        // MARK: - Calculate Button
                                Button(action: calculateRoute) {
                                    HStack {
                                        if routeSimulator.isCalculatingRoute {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                                        }
                                        Text(routeSimulator.isCalculatingRoute ? "Calculating..." : "Calculate Routes")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill((startCoord != nil && endCoord != nil) ?
                                                  Color.indigo : Color.gray)
                                    )
                                    .foregroundColor(.white)
                                    .font(.headline)
                                }
                        .disabled(startCoord == nil || endCoord == nil || routeSimulator.isCalculatingRoute)
                        .padding(.horizontal)
                        
                        // MARK: - Route Selection (shown after calculation)
                        if routeReady {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "map.fill")
                                        .foregroundColor(.accentColor)
                                    Text(importedGPX == nil ? "Select Route" : "GPX Route")
                                        .font(.headline)
                                    Spacer()
                                    Text(importedGPX == nil ? "\(routeSimulator.availableRoutes.count) route(s)" : "\(importedGPX?.count ?? 0) points")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                
                                CustomMapView(
                                    tappedCoordinate: .constant(nil), moveToRegion: $previewRegion,
                                    routePolyline: routeSimulator.routePolyline,
                                    allRoutePolylines: routeSimulator.allRoutePolylines,
                                    selectedRouteIndex: routeSimulator.selectedRouteIndex,
                                    acceptsTaps: false
                                )
                                .frame(height: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                                Text("Review the route. Your GPS location changes only when you press Start Route Simulation.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)

                                ForEach(Array(routeSimulator.availableRoutes.enumerated()), id: \.element.id) { idx, option in
                                    routeOptionCard(option: option, index: idx)
                                }
                                
                                // Start button
                                Button(action: startRoute) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("Start Route Simulation")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.green)
                                    )
                                    .foregroundColor(.white)
                                    .font(.headline)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Andromeda Navigation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        routeSimulator.stopSimulation()
                        routeReady = false
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                    .opacity(routeSimulator.isSimulating ? 1 : 0)
                    .disabled(!routeSimulator.isSimulating)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showGPXPicker = true }) {
                        Image(systemName: "doc.badge.plus")
                            .foregroundColor(.indigo)
                            .font(.title3)
                    }
                    .opacity(routeSimulator.isSimulating ? 0 : 1)
                    .disabled(routeSimulator.isSimulating)
                }
            }
            .fullScreenCover(item: $mapPickingField) { field in
                RoutePointPicker(
                    isStart: field == .start,
                    initialSelection: field == .start ? startCoord : endCoord,
                    nearbyCoordinate: field == .start ? endCoord : startCoord
                ) { coordinate in
                    selectMapPoint(coordinate, field: field)
                }
            }
            .alert("Route unavailable", isPresented: Binding(
                get: { routeError != nil }, set: { if !$0 { routeError = nil } }
            )) {
                Button("OK", role: .cancel) { routeError = nil }
            } message: {
                Text(routeError ?? "")
            }
            .sheet(isPresented: $showGPXPicker) {
                GPXDocumentPicker { url in
                    guard let result = GPXParser.parse(url: url), !result.isEmpty else {
                        UIApplication.shared.alert(body: "Failed to parse GPX file or file is empty.")
                        return
                    }
                    
                    let coords = result.allCoordinates
                    if coords.count >= 2 {
                        invalidateRoute()
                        importedGPX = coords
                        // Keep the complete WGS-84 track for simulation.
                        startCoord = coords.first
                        endCoord = coords.last
                        startText = "GPX Start"
                        endText = "GPX End (\(coords.count) points)"
                        
                        // Fit map to route
                        let centerLat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
                        let centerLon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
                        mapRegion = MKCoordinateRegion(
                            center: CoordinatePolicy.wgs84ToMap(CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)),
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                        
                        AlertKitAPI.present(title: "GPX Loaded! \(coords.count) pts", icon: .done, style: .iOS17AppleMusic, haptic: .success)
                    }
                }
            }
        }
    }
    
    // MARK: - Route Option Card
    private func routeOptionCard(option: RouteOption, index: Int) -> some View {
        let isSelected = routeSimulator.selectedRouteIndex == index
        let routeColors: [Color] = [.blue, .orange, .purple, .pink]
        let color = routeColors[index % routeColors.count]
        
        return Button(action: {
            routeSimulator.selectRoute(at: index)
            // Show this route on map
            showRouteOnMap()
        }) {
            HStack(spacing: 12) {
                // Color indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 6, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(option.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if index == 0 {
                            Text("FASTEST")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "ruler")
                                .font(.caption2)
                            Text(option.distanceText)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(option.etaText)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .font(.caption2)
                            Text("\(option.route.polyline.pointCount) pts")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    // Simulated ETA with speed multiplier
                    if speedMultiplier != 1.0 {
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.caption2)
                            Text("At \(String(format: "%.1f", speedMultiplier))x: \(routeSimulator.estimatedTime)")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? color : Color.white.opacity(0.2), lineWidth: 2)
            )
        }
        .foregroundColor(.primary)
        .padding(.horizontal)
    }
    
    // MARK: - Simulation Status Card
    private var simulationStatusCard: some View {
        VStack(spacing: 16) {
            // Progress
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: selectedMode.icon)
                        .foregroundColor(.accentColor)
                    Text("Route in Progress")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(routeSimulator.progress * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
                
                ProgressView(value: routeSimulator.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                
                HStack {
                    Text("Point \(routeSimulator.currentPointIndex)/\(routeSimulator.totalPoints)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("ETA: \(routeSimulator.estimatedTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            
            // Controls
            HStack(spacing: 20) {
                Button(action: {
                    routeSimulator.togglePause()
                }) {
                    HStack {
                        Image(systemName: routeSimulator.isPaused ? "play.fill" : "pause.fill")
                        Text(routeSimulator.isPaused ? "Resume" : "Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.orange)
                    )
                    .foregroundColor(.white)
                    .font(.headline)
                }
                
                Button(action: {
                    routeSimulator.stopSimulation()
                    routeReady = false
                    AlertKitAPI.present(
                        title: "Route Stopped",
                        icon: .done,
                        style: .iOS17AppleMusic,
                        haptic: .success
                    )
                }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.red)
                    )
                    .foregroundColor(.white)
                    .font(.headline)
                }
            }
            
            // Current position info
            if let pos = routeSimulator.currentPosition {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text(String(format: "%.5f, %.5f", pos.latitude, pos.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Location Card
    @ViewBuilder
    private func locationCard(
        title: String,
        icon: String,
        iconColor: Color,
        text: Binding<String>,
        isSearching: Bool,
        results: [MKMapItem],
        selectedCoord: CLLocationCoordinate2D?,
        field: ActiveField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                Spacer()
                if selectedCoord != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            
            HStack {
                TextField("Search address...", text: text, onCommit: {
                    searchLocation(query: text.wrappedValue, field: field)
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onTapGesture {
                    activeField = field
                }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Button(action: {
                    searchLocation(query: text.wrappedValue, field: field)
                }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            
            Button {
                mapPickingField = field
            } label: {
                Label("Choose on Map", systemImage: "map")
            }
            .padding(.horizontal)

            if selectedCoord != nil {
                HStack {
                    Image(systemName: "mappin")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.4f, %.4f", selectedCoord!.latitude, selectedCoord!.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            // Search Results
            if activeField == field && !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results.prefix(5), id: \.self) { item in
                        Button(action: {
                            selectLocation(item, field: field)
                        }) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(iconColor)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name ?? "Unknown")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    if let addr = item.placemark.title {
                                        Text(addr)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                        Divider().padding(.leading, 40)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Computed
    private var formattedSpeed: String {
        let baseSpeed = selectedMode.speed * speedMultiplier
        let kmh = baseSpeed * 3.6
        return "\(Int(kmh)) km/h"
    }
    
    // MARK: - Actions
    private func searchLocation(query: String, field: ActiveField) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        activeField = field
        
        if field == .start { isSearchingStart = true }
        else { isSearchingEnd = true }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                if field == .start { isSearchingStart = false }
                else { isSearchingEnd = false }
                
                if let items = response?.mapItems {
                    if field == .start { startResults = items }
                    else { endResults = items }
                }
            }
        }
    }
    
    private func selectLocation(_ item: MKMapItem, field: ActiveField) {
        invalidateRoute()
        importedGPX = nil
        let coord = item.placemark.coordinate
        
        if field == .start {
            startCoord = coord
            startText = item.name ?? "Selected"
            startResults = []
        } else {
            endCoord = coord
            endText = item.name ?? "Selected"
            endResults = []
        }
        
        activeField = .none
        routeReady = false
    }
    
    private func invalidateRoute() {
        routeReady = false
        routeError = nil
        routeSimulator.clearRoutePreview()
    }

    private func selectMapPoint(_ coordinate: CLLocationCoordinate2D, field: ActiveField) {
        invalidateRoute()
        importedGPX = nil
        activeField = .none
        // Keep MapKit coordinates here. RouteSimulator normalizes the resulting route once.
        if field == .start {
            startCoord = coordinate
            startText = NSLocalizedString("Map start point", comment: "")
            startResults = []
        } else {
            endCoord = coordinate
            endText = NSLocalizedString("Map destination", comment: "")
            endResults = []
        }
        if startCoord != nil && endCoord != nil { calculateRoute() }
    }

    private func calculateRoute() {
        invalidateRoute()
        if let coords = importedGPX {
            routeSimulator.loadGPXRoute(coords, mode: selectedMode, speedMult: speedMultiplier)
            routeReady = true
            showRouteOnMap()
            return
        }
        guard let start = startCoord, let end = endCoord else { return }
        guard start.latitude != end.latitude || start.longitude != end.longitude else {
            routeError = NSLocalizedString("Choose two different points.", comment: "")
            return
        }
        
        routeSimulator.calculateRoutes(from: start, to: end, mode: selectedMode, speedMult: speedMultiplier) { success, error in
            if success {
                routeReady = true
                showRouteOnMap()
            } else {
                routeError = error ?? NSLocalizedString("Failed to calculate route", comment: "")
            }
        }
    }
    
    private func showRouteOnMap() {
        // Show all routes on map, zoom to fit
        if let selectedPolyline = routeSimulator.routePolyline {
            let rect = selectedPolyline.boundingMapRect
            let region = MKCoordinateRegion(rect.insetBy(dx: -rect.size.width * 0.2, dy: -rect.size.height * 0.2))
            mapRegion = region
            previewRegion = region
        }
    }
    
    private func startRoute() {
        guard routeReady, !routeSimulator.isCalculatingRoute else { return }
        routeSimulator.startSimulation(altitude: 0.0)
        
        AlertKitAPI.present(
            title: "Route Started!",
            icon: .done,
            style: .iOS17AppleMusic,
            haptic: .success
        )
    }
}


/// A modal draft editor: no simulation manager or parent GPS binding is available here.
private struct RoutePointPicker: View {
    @Environment(\.dismiss) private var dismiss
    let isStart: Bool
    let onSelect: (CLLocationCoordinate2D) -> Void
    @State private var selection: CLLocationCoordinate2D?
    private let initialCenter: CLLocationCoordinate2D?

    init(isStart: Bool, initialSelection: CLLocationCoordinate2D?,
         nearbyCoordinate: CLLocationCoordinate2D?, onSelect: @escaping (CLLocationCoordinate2D) -> Void) {
        self.isStart = isStart
        self.onSelect = onSelect
        _selection = State(initialValue: initialSelection)
        initialCenter = initialSelection ?? nearbyCoordinate ?? CLLocationManager().location?.coordinate
    }

    var body: some View {
        NavigationView {
            RoutePointDraftMap(selection: $selection, initialCenter: initialCenter)
                .ignoresSafeArea(edges: .bottom)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 10) {
                        Text("Tap the map to choose a point. This does not change your GPS location.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        if let coordinate = selection {
                            Text(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
                                .font(.caption.monospacedDigit())
                        }
                        Button {
                            guard let coordinate = selection else { return }
                            onSelect(coordinate)
                            dismiss()
                        } label: {
                            Text("Use This Point").frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selection == nil)
                    }
                    .padding()
                    .background(.regularMaterial)
                }
                .navigationTitle(isStart ? "Choose Start Point" : "Choose Destination")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

/// Only mutates a draft coordinate. Deliberately has no LocSim or RouteSimulator dependency.
private struct RoutePointDraftMap: UIViewRepresentable {
    @Binding var selection: CLLocationCoordinate2D?
    let initialCenter: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.showsUserLocation = true
        if let center = initialCenter {
            map.setRegion(MKCoordinateRegion(center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)), animated: false)
        }
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        if let coordinate = selection {
            if let pin = context.coordinator.pin {
                pin.coordinate = coordinate
            } else {
                let pin = MKPointAnnotation()
                pin.coordinate = coordinate
                pin.title = NSLocalizedString("Selected point", comment: "")
                context.coordinator.pin = pin
                map.addAnnotation(pin)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject {
        var parent: RoutePointDraftMap
        var pin: MKPointAnnotation?
        init(_ parent: RoutePointDraftMap) { self.parent = parent }
        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let map = gesture.view as? MKMapView else { return }
            parent.selection = map.convert(gesture.location(in: map), toCoordinateFrom: map)
        }
    }
}
