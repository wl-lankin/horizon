import XCTest
@testable import Horizon

final class QuickAddTests: XCTestCase {
    private let cal = Calendar.de

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // Wed 21.10.2026 21:30
    private var now: Date { date(2026, 10, 21, 21, 30) }

    private func parse(_ s: String, now: Date? = nil) -> QuickAdd.Draft? {
        QuickAdd.parse(s, now: now ?? self.now, cal: cal)
    }

    private func check(_ s: String, _ title: String, start: Date, end: Date, allDay: Bool = false,
                       file: StaticString = #filePath, line: UInt = #line) {
        guard let d = parse(s) else { return XCTFail("nil for \(s)", file: file, line: line) }
        XCTAssertEqual(d.title, title, file: file, line: line)
        XCTAssertEqual(d.start, start, file: file, line: line)
        XCTAssertEqual(d.end, end, file: file, line: line)
        XCTAssertEqual(d.allDay, allDay, file: file, line: line)
    }

    func testExistingCases() {
        check("Fr 14 Uhr Zahnarzt", "Zahnarzt", start: date(2026, 10, 23, 14), end: date(2026, 10, 23, 15))
        check("morgen 9:30-11 Friseur", "Friseur", start: date(2026, 10, 22, 9, 30), end: date(2026, 10, 22, 11))
        check("23.10. Geburtstag Max", "Geburtstag Max", start: date(2026, 10, 23), end: date(2026, 10, 24), allDay: true)
        check("Elterngespräch um 10", "Elterngespräch", start: date(2026, 10, 22, 10), end: date(2026, 10, 22, 11))
        check("Zahnarzt", "Zahnarzt", start: date(2026, 10, 21), end: date(2026, 10, 22), allDay: true)
        check("Mo 10-11:30 Meeting mit Team", "Meeting mit Team", start: date(2026, 10, 26, 10), end: date(2026, 10, 26, 11, 30))
        check("übermorgen 18 Uhr Training für 2 Std", "Training", start: date(2026, 10, 23, 18), end: date(2026, 10, 23, 20))
        check("Mi 8 Uhr Joggen", "Joggen", start: date(2026, 10, 28, 8), end: date(2026, 10, 28, 9))
        check("Sitzung 20:00", "Sitzung", start: date(2026, 10, 22, 20), end: date(2026, 10, 22, 21))
    }

    func testNextWeekdayPrefix() {
        check("nächsten Fr Zahnarzt", "Zahnarzt", start: date(2026, 10, 23), end: date(2026, 10, 24), allDay: true)
    }

    func testCalendarHint() {
        let d = parse("Meeting #Arbeit Fr 10 Uhr")
        XCTAssertEqual(d?.calendarHint, "Arbeit")
        XCTAssertEqual(d?.title, "Meeting")
        XCTAssertEqual(d?.start, date(2026, 10, 23, 10))
        XCTAssertNil(d?.location)
        XCTAssertEqual(parse("#privat-2 Kino")?.calendarHint, "privat-2")
        XCTAssertEqual(parse("a #Eins #Zwei")?.calendarHint, "Eins")
    }

    func testLocation() {
        let d = parse("Zahnarzt Fr 14 Uhr @Bad Tölz")
        XCTAssertEqual(d?.location, "Bad Tölz")
        XCTAssertEqual(d?.title, "Zahnarzt")
        XCTAssertEqual(d?.start, date(2026, 10, 23, 14))
    }

    func testLocationStopsAtHashtag() {
        let d = parse("Zahnarzt @Bad Tölz #Privat")
        XCTAssertEqual(d?.location, "Bad Tölz")
        XCTAssertEqual(d?.calendarHint, "Privat")
        XCTAssertEqual(d?.title, "Zahnarzt")
    }

    func testLocationEndsBeforeDateWords() {
        let d = parse("Treffen @Raum 14 Uhr morgen")
        XCTAssertEqual(d?.location, "Raum")
        XCTAssertEqual(d?.start, date(2026, 10, 22, 14))

        let e = parse("Training @Halle 3")
        XCTAssertEqual(e?.location, "Halle 3")
        XCTAssertEqual(parse("Essen @Gasthof Morgenstern Sa 19 Uhr")?.location, "Gasthof Morgenstern")
        XCTAssertEqual(e?.allDay, true)
    }

    func testNextWeekAlone() {
        check("nächste Woche Projektplanung", "Projektplanung", start: date(2026, 10, 26), end: date(2026, 10, 27), allDay: true)
        check("kommende Woche Urlaub", "Urlaub", start: date(2026, 10, 26), end: date(2026, 10, 27), allDay: true)
        check("nächster Woche 9 Uhr Call", "Call", start: date(2026, 10, 26, 9), end: date(2026, 10, 26, 10))
    }

    func testNextWeekWithWeekday() {
        check("nächste Woche Di Zahnarzt", "Zahnarzt", start: date(2026, 10, 27), end: date(2026, 10, 28), allDay: true)
        check("Di nächste Woche Zahnarzt", "Zahnarzt", start: date(2026, 10, 27), end: date(2026, 10, 28), allDay: true)
        check("kommende Woche Sonntag 10 Uhr Brunch", "Brunch", start: date(2026, 11, 1, 10), end: date(2026, 11, 1, 11))
    }

    func testNextWeekFromSunday() {
        let sunday = date(2026, 10, 25, 12)
        let d = parse("nächste Woche Mo Sync", now: sunday)
        XCTAssertEqual(d?.start, date(2026, 10, 26))
    }

    func testRecurrenceKeywords() {
        XCTAssertEqual(parse("Sport täglich")?.recurrence, .daily)
        XCTAssertEqual(parse("Sport jeden Tag 7 Uhr")?.recurrence, .daily)
        XCTAssertEqual(parse("Putzen wöchentlich")?.recurrence, .weekly)
        XCTAssertEqual(parse("Miete monatlich")?.recurrence, .monthly)
        XCTAssertEqual(parse("Miete jeden Monat")?.recurrence, .monthly)
        XCTAssertEqual(parse("Steuer jährlich")?.recurrence, .yearly)
        XCTAssertEqual(parse("Steuer jedes Jahr")?.recurrence, .yearly)
        XCTAssertNil(parse("Zahnarzt")?.recurrence)
        XCTAssertEqual(parse("Sport JEDEN TAG")?.title, "Sport")
    }

    func testRecurrenceWeekday() {
        let d = parse("Chor jeden Mo 19 Uhr")
        XCTAssertEqual(d?.recurrence, .weekly)
        XCTAssertEqual(d?.title, "Chor")
        XCTAssertEqual(d?.start, date(2026, 10, 26, 19))
        let e = parse("Yoga jeden Mittwoch 8 Uhr")
        XCTAssertEqual(e?.recurrence, .weekly)
        XCTAssertEqual(e?.start, date(2026, 10, 28, 8))
        XCTAssertEqual(parse("Yoga jeden Monat")?.recurrence, .monthly)
    }

    func testMonthRollover() {
        let d = parse("31.10. Halloween", now: date(2026, 10, 30, 10))
        XCTAssertEqual(d?.start, date(2026, 10, 31))
        let e = parse("morgen Termin", now: date(2026, 10, 31, 10))
        XCTAssertEqual(e?.start, date(2026, 11, 1))
    }

    func testYearRollover() {
        let d = parse("5.1. Arzt", now: date(2026, 12, 28, 10))
        XCTAssertEqual(d?.start, date(2027, 1, 5))
        let e = parse("in 10 Tagen Arzt", now: date(2026, 12, 28, 10))
        XCTAssertEqual(e?.start, date(2027, 1, 7))
    }

    func testPastDateGoesToNextYear() {
        XCTAssertEqual(parse("1.3. Geburtstag")?.start, date(2027, 3, 1))
        XCTAssertEqual(parse("1.3.2026 Geburtstag")?.start, date(2026, 3, 1))
        XCTAssertEqual(parse("21.10. Heute")?.start, date(2026, 10, 21))
    }

    func testInvalidTimeIgnored() {
        let d = parse("Termin 25 Uhr")
        XCTAssertEqual(d?.allDay, true)
        XCTAssertEqual(d?.title, "Termin")
    }

    func testEmptyAndTitleFallback() {
        XCTAssertNil(parse(""))
        XCTAssertNil(parse("   "))
        XCTAssertEqual(parse("morgen")?.title, "Neuer Termin")
        XCTAssertEqual(parse("#Arbeit")?.title, "Neuer Termin")
    }

    func testCombined() {
        let d = parse("nächste Woche Di 9-10 Standup jeden Di #Arbeit @Büro")
        XCTAssertEqual(d?.title, "Standup")
        XCTAssertEqual(d?.calendarHint, "Arbeit")
        XCTAssertEqual(d?.location, "Büro")
        XCTAssertEqual(d?.recurrence, .weekly)
        XCTAssertEqual(d?.start, date(2026, 10, 27, 9))
        XCTAssertEqual(d?.end, date(2026, 10, 27, 10))
        XCTAssertEqual(d?.allDay, false)
    }

    func testLocationInTheMiddle() {
        let d = parse("Planung @Bad Tölz Fr 14 Uhr jeden Fr #Arbeit")
        XCTAssertEqual(d?.title, "Planung")
        XCTAssertEqual(d?.location, "Bad Tölz")
        XCTAssertEqual(d?.recurrence, .weekly)
        XCTAssertEqual(d?.calendarHint, "Arbeit")
        XCTAssertEqual(d?.start, date(2026, 10, 23, 14))

        let e = parse("Zahnarzt @Praxis Dr. Huber 9:30")
        XCTAssertEqual(e?.location, "Praxis Dr. Huber")
        XCTAssertEqual(e?.start, date(2026, 10, 22, 9, 30))
    }
}
