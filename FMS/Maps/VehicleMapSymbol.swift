import SwiftUI

extension Vehicle {
    /// SF Symbol for fleet map pins based on vehicle type.
    var fleetMapSymbolName: String {
        let type = vehicleType.lowercased()
        let modelName = model.lowercased()
        let combined = "\(type) \(modelName)"

        if combined.contains("bike")
            || combined.contains("motor")
            || combined.contains("scooter")
            || combined.contains("2-wheel")
            || combined.contains("two wheel") {
            return "scooter"
        }
        if combined.contains("bus") || combined.contains("coach") {
            return "bus.fill"
        }
        if combined.contains("van") || combined.contains("tempo") {
            return "van.fill"
        }
        if combined.contains("truck")
            || combined.contains("lorry")
            || combined.contains("trailer")
            || combined.contains("heavy")
            || combined.contains("prime")
            || combined.contains("haul") {
            return "box.truck.fill"
        }
        if combined.contains("car")
            || combined.contains("sedan")
            || combined.contains("suv")
            || combined.contains("hatch")
            || combined.contains("wagon") {
            return "car.fill"
        }
        return "box.truck.fill"
    }

    var fleetMapSymbolIsAutomobile: Bool {
        fleetMapSymbolName == "car.fill"
    }
}

extension FleetVehicleLocation {
    var isMoving: Bool {
        activeTrip?.status == .inProgress
    }
}

struct VehicleMapMarker: View {
    let symbolName: String
    var tint: Color = AppTheme.brand
    var isMoving: Bool = false
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(tint)
            .symbolEffect(.pulse, options: .repeating, isActive: isMoving)
            .padding(size * 0.32)
            .background(.background, in: Circle())
            .overlay(Circle().stroke(tint, lineWidth: isMoving ? 2 : 1))
    }
}
