import Foundation
import SwiftUI

// MARK: - Date Extensions

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: self)
    }
    
    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
    
    var fullFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter.string(from: self)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self).capitalized
    }
    
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }
}

// MARK: - Number Extensions

extension Double {
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        let formatted = formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
        return "\(formatted) ₸"
    }
    
    var signedCurrencyFormatted: String {
        let sign = self >= 0 ? "+" : ""
        return "\(sign)\(self.currencyFormatted)"
    }
}

// MARK: - View Extensions

extension View {
    func glassBackground() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("CardBG"))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            )
    }
    
    func gradientCard(colors: [Color]) -> some View {
        self
            .padding(16)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            )
    }
}

// MARK: - Color Extensions

/// Namespaced app color palette to avoid duplicate global Color extensions.
enum AppColors {
    static let appBackground = Color("AppBG")
    static let cardBackground = Color("CardBG")
    static let accentPurple = Color("AccentPurple")
    static let accentBlue = Color("AccentBlue")
    static let accentGreen = Color("AccentGreen")
    static let accentOrange = Color("AccentOrange")
    static let accentPink = Color("AccentPink")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
}

// MARK: - Gradient Presets

struct AppGradients {
    static let purple = [Color(hex: "667eea"), Color(hex: "764ba2")]
    static let blue = [Color(hex: "4facfe"), Color(hex: "00f2fe")]
    static let green = [Color(hex: "43e97b"), Color(hex: "38f9d7")]
    static let orange = [Color(hex: "fa709a"), Color(hex: "fee140")]
    static let pink = [Color(hex: "f093fb"), Color(hex: "f5576c")]
    static let dark = [Color(hex: "1a1a2e"), Color(hex: "16213e")]
    static let income = [Color(hex: "43e97b"), Color(hex: "38f9d7")]
    static let expense = [Color(hex: "fa709a"), Color(hex: "fee140")]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
