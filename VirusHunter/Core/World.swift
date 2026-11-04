import Foundation

/// The outbreak map: the player picks a country, and each of its 10 main cities is one
/// Infection Level. Clearing all five organs of the patient in a city moves the outbreak to the next city.
struct Country: Identifiable, Equatable {
    let id: String        // ISO region code, or "WORLD"
    let name: String
    let flag: String
    let cities: [String]  // exactly `Organ.maxInfection` cities, in play order

    static let world = Country(id: "WORLD", name: "World Tour", flag: "🌍", cities: [
        "London", "New York", "Tokyo", "Paris", "Dubai", "Istanbul", "Cairo", "Rio de Janeiro", "Sydney", "Singapore"])

    static let all: [Country] = [
        Country(id: "PK", name: "Pakistan", flag: "🇵🇰", cities: [
            "Islamabad", "Lahore", "Karachi", "Peshawar", "Quetta", "Multan", "Faisalabad", "Rawalpindi", "Hyderabad", "Sialkot"]),
        Country(id: "IN", name: "India", flag: "🇮🇳", cities: [
            "New Delhi", "Mumbai", "Bengaluru", "Kolkata", "Chennai", "Hyderabad", "Ahmedabad", "Pune", "Jaipur", "Lucknow"]),
        Country(id: "BD", name: "Bangladesh", flag: "🇧🇩", cities: [
            "Dhaka", "Chattogram", "Khulna", "Rajshahi", "Sylhet", "Barishal", "Rangpur", "Mymensingh", "Cumilla", "Gazipur"]),
        Country(id: "SA", name: "Saudi Arabia", flag: "🇸🇦", cities: [
            "Riyadh", "Jeddah", "Mecca", "Medina", "Dammam", "Khobar", "Taif", "Tabuk", "Abha", "Buraidah"]),
        Country(id: "AE", name: "United Arab Emirates", flag: "🇦🇪", cities: [
            "Abu Dhabi", "Dubai", "Sharjah", "Ajman", "Al Ain", "Ras Al Khaimah", "Fujairah", "Umm Al Quwain", "Khor Fakkan", "Kalba"]),
        Country(id: "TR", name: "Türkiye", flag: "🇹🇷", cities: [
            "Ankara", "Istanbul", "Izmir", "Bursa", "Antalya", "Konya", "Adana", "Gaziantep", "Kayseri", "Trabzon"]),
        Country(id: "EG", name: "Egypt", flag: "🇪🇬", cities: [
            "Cairo", "Alexandria", "Giza", "Luxor", "Aswan", "Port Said", "Suez", "Mansoura", "Tanta", "Hurghada"]),
        Country(id: "ID", name: "Indonesia", flag: "🇮🇩", cities: [
            "Jakarta", "Surabaya", "Bandung", "Medan", "Semarang", "Makassar", "Yogyakarta", "Denpasar", "Palembang", "Malang"]),
        Country(id: "GB", name: "United Kingdom", flag: "🇬🇧", cities: [
            "London", "Manchester", "Birmingham", "Liverpool", "Edinburgh", "Glasgow", "Leeds", "Bristol", "Cardiff", "Belfast"]),
        Country(id: "US", name: "United States", flag: "🇺🇸", cities: [
            "Washington, D.C.", "New York", "Los Angeles", "Chicago", "Houston", "Miami", "San Francisco", "Seattle", "Las Vegas", "Boston"]),
        Country(id: "CA", name: "Canada", flag: "🇨🇦", cities: [
            "Ottawa", "Toronto", "Montreal", "Vancouver", "Calgary", "Edmonton", "Winnipeg", "Quebec City", "Halifax", "Victoria"]),
        Country(id: "DE", name: "Germany", flag: "🇩🇪", cities: [
            "Berlin", "Hamburg", "Munich", "Cologne", "Frankfurt", "Stuttgart", "Düsseldorf", "Leipzig", "Dresden", "Bremen"]),
        world,
    ]

    /// The country for a saved code (or the device region), falling back to the World Tour.
    static func find(_ code: String?) -> Country {
        all.first { $0.id == code?.uppercased() } ?? world
    }

    /// People infected when the outbreak reaches a city (grows city by city).
    static func outbreakSize(_ level: Int) -> Int { 8_000 + 12_000 * max(1, level) + 1_700 * ((level * 7) % 5) }

    /// City for an Infection Level (1-based).
    func city(_ level: Int) -> String { cities[max(0, min(cities.count - 1, level - 1))] }
}

extension SaveData {
    var country: Country { Country.find(countryCode) }

    /// Cities fully cleared: all five organs beaten at that Infection Level.
    var citiesCleared: Int { Organ.all.map { clearedInfection($0.id) }.min() ?? 0 }

    /// The city with the active outbreak, as an Infection Level (1...10).
    var currentCity: Int { min(Organ.maxInfection, citiesCleared + 1) }

    /// Organs of Patient Zero cleared in a city.
    func organsCleared(inCity level: Int) -> Int { Organ.all.filter { clearedInfection($0.id) >= level }.count }

    /// People still infected in a city: each organ cleared cures a fifth of them.
    func infected(inCity level: Int) -> Int {
        let total = Country.outbreakSize(level), n = Organ.all.count
        return total * (n - organsCleared(inCity: level)) / n
    }

    /// Can this organ be played at this Infection Level (city)?
    func canPlay(_ organID: Int, level: Int) -> Bool {
        if level == 1 { return organID <= unlockedStage }
        return level <= unlockedInfection(organID)
    }

    /// The next organ to clear in the active city (nil once every city is saved).
    var nextMission: Organ? {
        let level = currentCity
        if citiesCleared >= Organ.maxInfection { return nil }
        return Organ.all.first { clearedInfection($0.id) < level && canPlay($0.id, level: level) }?.at(infection: level)
    }
}
