import Foundation
import SwiftUI

enum AccountColor: String, CaseIterable, Identifiable, Codable {
    case blue
    case teal
    case indigo
    case green
    case orange
    case pink
    case purple
    case red

    var id: String { rawValue }

    var swiftUIColor: Color {
        switch self {
        case .blue:
            return Color(red: 0.0, green: 0.41, blue: 1.0)
        case .teal:
            return .teal
        case .indigo:
            return .indigo
        case .green:
            return .green
        case .orange:
            return .orange
        case .pink:
            return .pink
        case .purple:
            return .purple
        case .red:
            return .red
        }
    }

    var displayName: String {
        switch self {
        case .blue:
            return "Xanh dương"
        case .teal:
            return "Xanh ngọc"
        case .indigo:
            return "Chàm"
        case .green:
            return "Xanh lá"
        case .orange:
            return "Cam"
        case .pink:
            return "Hồng"
        case .purple:
            return "Tím"
        case .red:
            return "Đỏ"
        }
    }
}

struct ZaloAccount: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var dataStoreID: UUID
    var name: String
    var note: String
    var color: AccountColor
    var zoomScale: Double
    let createdAt: Date

    static let minZoomScale: Double = 0.60
    static let maxZoomScale: Double = 1.40

    static func clampedZoom(_ value: Double) -> Double {
        min(max(value, minZoomScale), maxZoomScale)
    }

    init(
        id: UUID = UUID(),
        dataStoreID: UUID = UUID(),
        name: String,
        note: String = "",
        color: AccountColor = .blue,
        zoomScale: Double = 1.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dataStoreID = dataStoreID
        self.name = name
        self.note = note
        self.color = color
        self.zoomScale = Self.clampedZoom(zoomScale)
        self.createdAt = createdAt
    }
}
