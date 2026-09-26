import Foundation

/// Every string the person sees, in Swedish, in one place.
enum Copy {
    // Tabs and titles
    static let messagesTab = "Meddelanden"
    static let terminalTab = "Terminal"
    static let settingsTab = "Inställningar"
    static let pairTitle = "Parkoppla"

    // Pairing
    static let pairLinkHeader = "Länk eller kod"
    static let pairLinkPlaceholder = "https://…/pair.html#…"
    static let pairFooter = "Kör python -m kernel shell pair --name phone på boxen och klistra in länken den skriver ut."
    static let kernelAddress = "Kärnans adress"
    static let kernelAddressFooter = "Koden saknar adress. Skriv adressen du når LifeOS på."
    static let deviceName = "Enhetens namn"
    static let pairButton = "Parkoppla"
    static let badCode = "Det ser inte ut som en länk eller kod från LifeOS."
    static let badAddress = "Adressen måste börja med https://."
    static let codeRefused = "Koden fungerade inte. Den kan vara använd eller för gammal. Skapa en ny på boxen."

    // Messages
    static let messagesTitle = "Meddelanden"
    static let emptyTitle = "Inga meddelanden"
    static let emptyText = "Det LifeOS skickar till appen hamnar här."
    static let copy = "Kopiera"

    // Replies
    static let replyPlaceholder = "Svara"
    static let replyAction = "Svara"
    static let send = "Skicka"
    static let sent = "Skickat"
    static let unsent = "Inte skickat"
    static let refused = "Avvisat"
    static let tryAgain = "Försök igen"
    static let delete = "Ta bort"

    // Terminal
    static let terminalTitle = "Terminal"
    static let terminalPlaceholder = "Skriv till assistenten"
    static let terminalEmptyTitle = "Tom terminal"
    static let terminalEmptyText = "Skriv en rad nedan. Assistenten svarar här."
    static let showOlder = "Visa äldre"
    static let you = "Du"
    static let assistant = "Assistenten"

    // Settings
    static let settingsTitle = "Inställningar"
    static let deviceSection = "Enhet"
    static let deviceID = "Id"
    static let save = "Spara"
    static let notificationsSection = "Notiser"
    static let notifications = "Notiser"
    static let notificationsOn = "På"
    static let notificationsOff = "Av"
    static let notificationsUnknown = "Okänt"
    static let openSettings = "Öppna Inställningar"
    static let unpair = "Koppla från"
    static let unpairQuestion = "Koppla från den här iPhonen?"
    static let unpairFooter = "Appen glömmer sin nyckel och sina meddelanden. Återkalla enheten på boxen med python -m kernel shell revoke."

    // Status lines
    static let offline = "Ingen kontakt med LifeOS. Appen försöker igen senare."
    static let notPaired = "Enheten är inte parkopplad längre. Parkoppla igen."
    static let unreadable = "Svaret från LifeOS gick inte att läsa."
    static let serverFailed = "LifeOS svarade med ett fel."
    static let tooLong = "Texten går inte att skicka. Den är tom eller för lång."
    static let saveFailed = "Svaret gick inte att spara på telefonen."
    static func server(_ sentence: String) -> String { "LifeOS svarade: \(sentence)" }
}
