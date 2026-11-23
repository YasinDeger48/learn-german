import Foundation

func a1Core(_ token: String) -> String {
    token.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:„“\"()–…"))
}

func a1Normalize(_ text: String) -> String {
    let lowered = text.lowercased()
    let cleaned = lowered.unicodeScalars.map { scalar -> String in
        ".,!?;:„“\"()–…".unicodeScalars.contains(scalar) ? " " : String(scalar)
    }.joined()
    return cleaned.split(whereSeparator: { $0 == " " || $0 == "\n" }).joined(separator: " ")
}

func a1GermanNumber(_ n: Int) -> String {
    let ones = ["null", "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun", "zehn",
                "elf", "zwölf", "dreizehn", "vierzehn", "fünfzehn", "sechzehn", "siebzehn", "achtzehn", "neunzehn"]
    let tens = ["", "", "zwanzig", "dreißig", "vierzig", "fünfzig", "sechzig", "siebzig", "achtzig", "neunzig"]
    if n < 20 { return ones[n] }
    if n < 100 {
        let unit = n % 10
        let ten = tens[n / 10]
        if unit == 0 { return ten }
        return (unit == 1 ? "ein" : ones[unit]) + "und" + ten
    }
    if n < 1000 {
        let hundreds = n / 100
        let rest = n % 100
        let head = (hundreds == 1 ? "ein" : ones[hundreds]) + "hundert"
        return rest == 0 ? head : head + a1GermanNumber(rest)
    }
    if n < 1_000_000 {
        var head = a1GermanNumber(n / 1000)
        if head.hasSuffix("eins") { head = String(head.dropLast()) }
        let rest = n % 1000
        head += "tausend"
        return rest == 0 ? head : head + a1GermanNumber(rest)
    }
    return "\(n)"
}

/// 1998 → neunzehnhundertachtundneunzig, 2024 → zweitausendvierundzwanzig
func a1Year(_ year: Int) -> String {
    if year >= 1100 && year < 2000 {
        let rest = year % 100
        return a1GermanNumber(year / 100) + "hundert" + (rest == 0 ? "" : a1GermanNumber(rest))
    }
    return a1GermanNumber(year)
}

/// 3,50 € → drei Euro fünfzig
func a1Price(_ euro: Int, _ cent: Int) -> String {
    let e = euro == 1 ? "ein Euro" : "\(a1GermanNumber(euro)) Euro"
    return cent == 0 ? e : "\(e) \(a1GermanNumber(cent))"
}

/// Building blocks of a number below 1000: 347 → drei · hundert · sieben · und · vierzig
func a1NumberPieces(_ n: Int) -> [String] {
    var pieces: [String] = []
    let hundreds = n / 100
    let rest = n % 100
    if hundreds > 0 { pieces += [hundreds == 1 ? "ein" : a1GermanNumber(hundreds), "hundert"] }
    if rest > 0 {
        if rest < 20 || rest % 10 == 0 {
            pieces.append(a1GermanNumber(rest))
        } else {
            let unit = rest % 10
            pieces += [unit == 1 ? "ein" : a1GermanNumber(unit), "und", a1GermanNumber(rest - unit)]
        }
    }
    if pieces.isEmpty { pieces = ["null"] }
    return pieces
}

/// Accepted spellings: "hundert" for "einhundert", "tausend" for "eintausend".
func a1NumberAlternatives(_ word: String) -> [String] {
    var result: [String] = []
    if word.hasPrefix("einhundert") { result.append(String(word.dropFirst(3))) }
    if word.hasPrefix("eintausend") { result.append(String(word.dropFirst(3))) }
    return result
}

func a1Ordinal(_ n: Int) -> String {
    switch n {
    case 1: return "erste"
    case 3: return "dritte"
    case 7: return "siebte"
    case 8: return "achte"
    default: return n < 20 ? a1GermanNumber(n) + "te" : a1GermanNumber(n) + "ste"
    }
}

func a1HourWord(_ h: Int) -> String {
    let hour = ((h - 1) % 12 + 12) % 12 + 1
    return hour == 1 ? "eins" : a1GermanNumber(hour)
}

func a1TimePhrase(_ h: Int, _ m: Int) -> String {
    let now = a1HourWord(h)
    let next = a1HourWord(h + 1)
    switch m {
    case 0: return (h % 12 == 1 ? "ein" : now) + " Uhr"
    case 5: return "fünf nach \(now)"
    case 10: return "zehn nach \(now)"
    case 15: return "Viertel nach \(now)"
    case 20: return "zwanzig nach \(now)"
    case 25: return "fünf vor halb \(next)"
    case 30: return "halb \(next)"
    case 35: return "fünf nach halb \(next)"
    case 40: return "zwanzig vor \(next)"
    case 45: return "Viertel vor \(next)"
    case 50: return "zehn vor \(next)"
    default: return "fünf vor \(next)"
    }
}
