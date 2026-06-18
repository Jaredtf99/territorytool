import MapKit
import SwiftUI

struct TerritoryMapView: View {
    let geometry: TerritoryMapGeometry
    var compact = false

    var body: some View {
        Map(
            initialPosition: .camera(geometry.camera(compact: compact)),
            interactionModes: []
        ) {
            ForEach(geometry.polygons) { polygon in
                MapPolygon(coordinates: polygon.mapCoordinates)
                    .foregroundStyle(Color.accent.opacity(0.18))
                    .stroke(Color.accent, lineWidth: compact ? 2 : 3)
            }

            ForEach(geometry.polylines) { polyline in
                MapPolyline(coordinates: polyline.mapCoordinates)
                    .stroke(
                        Color.accent,
                        style: StrokeStyle(lineWidth: compact ? 2 : 3, lineCap: .round)
                    )
            }

            ForEach(geometry.markers) { marker in
                if compact {
                    Annotation("", coordinate: marker.mapCoordinate) {
                        Circle()
                            .fill(Color.accentColor)
                            .stroke(.white, lineWidth: 1)
                            .frame(width: 7, height: 7)
                            .shadow(radius: 1)
                    }
                    .annotationTitles(.hidden)
                } else {
                    Marker(
                        marker.title ?? "",
                        monogram: Text(marker.title ?? "•"),
                        coordinate: marker.mapCoordinate
                    )
                    .tint(Color.accentColor)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .allowsHitTesting(false)
        .accessibilityLabel(Text("territory.detail.map"))
    }
}

private extension TerritoryMapFeature {
    var mapCoordinates: [CLLocationCoordinate2D] {
        coordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }
}

private extension TerritoryMapMarker {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension TerritoryMapGeometry {
    func camera(compact: Bool) -> MapCamera {
        let northwest = MKMapPoint(
            CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.west)
        )
        let southeast = MKMapPoint(
            CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.east)
        )

        let minX = min(northwest.x, southeast.x)
        let minY = min(northwest.y, southeast.y)
        let width = max(abs(southeast.x - northwest.x), 100)
        let height = max(abs(southeast.y - northwest.y), 100)
        let centerPoint = MKMapPoint(
            x: minX + width / 2,
            y: minY + height / 2
        )
        let center = centerPoint.coordinate
        let metersPerPoint = MKMetersPerMapPointAtLatitude(center.latitude)
        let footprintMeters = max(width, height) * metersPerPoint
        let distanceMultiplier = compact ? 2.1 : 1.75

        return MapCamera(
            centerCoordinate: center,
            distance: max(footprintMeters * distanceMultiplier, compact ? 180 : 140),
            heading: 0,
            pitch: compact ? 48 : 55
        )
    }
}
