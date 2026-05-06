//
//  VehicleLocationMapView.swift
//  pan3car
//
//  Created by Codex on 2026/5/7.
//

import CoreLocation
import MapKit
import Observation
import SwiftUI

struct VehicleLocationMapView: View {
    let location: VehicleLocationSnapshot

    @State private var locationService = VehicleLocationService()
    @State private var cameraPosition: MapCameraPosition
    @State private var walkingRoute: MKRoute?
    @State private var routeErrorMessage: String?

    private let destinationCoordinate: CLLocationCoordinate2D

    init(location: VehicleLocationSnapshot) {
        self.location = location

        let coordinate = location.coordinate ?? CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        destinationCoordinate = coordinate
        _cameraPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
                )
            )
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                Marker("车辆位置", systemImage: "car.fill", coordinate: destinationCoordinate)
                    .tint(.cyan)

                UserAnnotation()

                if let walkingRoute {
                    MapPolyline(walkingRoute.polyline)
                        .stroke(.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(edges: .bottom)

            VStack(alignment: .leading, spacing: 14) {
                locationSummary

                if let routeErrorMessage {
                    Text(routeErrorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 12) {
                    Button {
                        locationService.requestCurrentLocation()
                    } label: {
                        Label(locationService.actionTitle, systemImage: "location.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        openWalkingNavigation()
                    } label: {
                        Label("步行导航", systemImage: "figure.walk")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
            }
            .padding(18)
            .liquidGlass(cornerRadius: 28)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .navigationTitle("车辆位置")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            locationService.requestCurrentLocation()
        }
        .task(id: locationService.locationUpdateID) {
            await updateWalkingRoute()
        }
        .accessibilityIdentifier("vehicle.location.map")
    }

    private var locationSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("车辆位置", systemImage: "car.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            Text(location.address)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(location.coordinateText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Divider()
                .overlay(Color.primary.opacity(0.08))

            Label(locationService.statusText, systemImage: locationService.statusIcon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(locationService.statusTint)

            if let detailedAddress = locationService.detailedAddress {
                Text(detailedAddress)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func updateWalkingRoute() async {
        routeErrorMessage = nil

        guard let userCoordinate = locationService.coordinate else {
            walkingRoute = nil
            return
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
        request.transportType = .walking

        do {
            let response = try await MKDirections(request: request).calculate()
            walkingRoute = response.routes.first
            fitRouteOrDestination(userCoordinate: userCoordinate)
        } catch {
            walkingRoute = nil
            routeErrorMessage = "暂时无法生成步行路线，可直接打开系统地图导航。"
            fitRouteOrDestination(userCoordinate: userCoordinate)
        }
    }

    private func fitRouteOrDestination(userCoordinate: CLLocationCoordinate2D) {
        if let walkingRoute {
            cameraPosition = .rect(walkingRoute.polyline.boundingMapRect.padded(by: 0.28))
        } else {
            cameraPosition = .rect(MKMapRect(coordinates: [userCoordinate, destinationCoordinate]).padded(by: 0.36))
        }
    }

    private func openWalkingNavigation() {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
        destination.name = "车辆位置"

        MKMapItem.openMaps(
            with: [MKMapItem.forCurrentLocation(), destination],
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
            ]
        )
    }
}

@MainActor
@Observable
private final class VehicleLocationService: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let geocoder = CLGeocoder()

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var coordinate: CLLocationCoordinate2D?
    var detailedAddress: String?
    var locationErrorMessage: String?
    var isLocating = false
    var locationUpdateID = UUID()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        authorizationStatus = manager.authorizationStatus
    }

    var statusText: String {
        if let locationErrorMessage {
            return locationErrorMessage
        }

        switch authorizationStatus {
        case .notDetermined:
            return "需要定位权限，用于计算你到车辆的步行路线"
        case .restricted, .denied:
            return "定位权限未开启，请在系统设置中允许胖3助手访问位置"
        case .authorizedAlways, .authorizedWhenInUse:
            if let detailedAddress {
                return "已获取当前位置"
            }
            return isLocating ? "正在获取详细定位..." : "可以获取当前位置"
        @unknown default:
            return "定位状态未知"
        }
    }

    var statusIcon: String {
        switch authorizationStatus {
        case .restricted, .denied:
            "location.slash.fill"
        case .authorizedAlways, .authorizedWhenInUse:
            "location.fill"
        default:
            "location.circle.fill"
        }
    }

    var statusTint: Color {
        switch authorizationStatus {
        case .restricted, .denied:
            .orange
        case .authorizedAlways, .authorizedWhenInUse:
            .green
        default:
            .secondary
        }
    }

    var actionTitle: String {
        switch authorizationStatus {
        case .notDetermined:
            "开启定位"
        case .restricted, .denied:
            "定位未开"
        default:
            isLocating ? "定位中" : "重新定位"
        }
    }

    func requestCurrentLocation() {
        locationErrorMessage = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isLocating = true
            manager.requestLocation()
        case .restricted, .denied:
            isLocating = false
            authorizationStatus = manager.authorizationStatus
        @unknown default:
            isLocating = false
            locationErrorMessage = "定位状态暂不可用"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            requestCurrentLocation()
        } else if authorizationStatus == .restricted || authorizationStatus == .denied {
            isLocating = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        coordinate = location.coordinate
        isLocating = false
        locationUpdateID = UUID()

        Task {
            await reverseGeocode(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        locationErrorMessage = "当前位置获取失败，请稍后重试"
    }

    private func reverseGeocode(_ location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            detailedAddress = placemarks.first?.formattedAddress
        } catch {
            detailedAddress = "已获取坐标，暂未解析出详细地址"
        }
    }
}

private extension VehicleLocationSnapshot {
    var coordinate: CLLocationCoordinate2D? {
        let normalized = coordinateText
            .replacingOccurrences(of: "°", with: "")
            .replacingOccurrences(of: "N", with: "")
            .replacingOccurrences(of: "E", with: "")
            .replacingOccurrences(of: "S", with: "")
            .replacingOccurrences(of: "W", with: "")

        let parts = normalized
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count == 2,
              var latitude = Double(parts[0]),
              var longitude = Double(parts[1]) else {
            return nil
        }

        if coordinateText.contains("S") {
            latitude *= -1
        }

        if coordinateText.contains("W") {
            longitude *= -1
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension CLPlacemark {
    var formattedAddress: String {
        [
            administrativeArea,
            locality,
            subLocality,
            thoroughfare,
            subThoroughfare,
            name
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }
}

private extension MKMapRect {
    init(coordinates: [CLLocationCoordinate2D]) {
        let points = coordinates.map(MKMapPoint.init)
        let firstPoint = points.first ?? MKMapPoint(CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737))

        self = points.dropFirst().reduce(
            MKMapRect(origin: firstPoint, size: MKMapSize(width: 1, height: 1))
        ) { rect, point in
            rect.union(MKMapRect(origin: point, size: MKMapSize(width: 1, height: 1)))
        }
    }

    func padded(by percentage: Double) -> MKMapRect {
        let insetX = -size.width * percentage
        let insetY = -size.height * percentage
        return insetBy(dx: insetX, dy: insetY)
    }
}

#Preview {
    NavigationStack {
        VehicleLocationMapView(location: .init(
            address: "上海市浦东新区世纪大道附近",
            coordinateText: "31.2304°N, 121.4737°E"
        ))
    }
}
