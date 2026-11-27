import XCTest
@testable import Almanca

/// The writing and speaking score rules (TaskScore.swift) against graded sample answers, so a change to the rules
/// that breaks the order of the bands fails here. The samples are from ../icerik/gorev/puanlama_cevap_A1.txt
/// (tools/score_check.py checks all of them on the PC).
final class TaskScoreTests: XCTestCase {
    private func writing(_ text: String) throws -> Int {
        let task = try XCTUnwrap(WritingBank.task("a1-m1"), "writing task a1-m1 is missing")
        return TaskScorer.writing(task, text: text).percent
    }

    func testWritingBandsKeepTheirOrder() throws {
        let top = try writing("Sehr geehrte Frau Weber, leider bin ich krank und kann morgen nicht zum Deutschkurs kommen. "
            + "Können Sie mir bitte sagen, was die Hausaufgaben sind? Am Donnerstag komme ich wieder zum Kurs. "
            + "Vielen Dank für Ihre Antwort. Mit freundlichen Grüßen, Ayşe")
        let good = try writing("Sehr geehrte Frau Weber, ich bin leider krank und kann morgen nicht kommen. "
            + "Was sind die Hausaufgaben? Am Donnerstag bin ich wieder da. Viele Grüße, Ayşe")
        let weak = try writing("Hallo Frau Weber, ich bin krank. Morgen komme ich nicht. Was machen wir? Tschüss")
        let off = try writing("Hallo Tom, am Samstag ist meine Party. Kommst du?")

        XCTAssertGreaterThanOrEqual(top, 70)
        XCTAssertLessThan(off, 40)
        XCTAssertGreaterThanOrEqual(top, good)
        XCTAssertGreaterThan(good, weak)
        XCTAssertGreaterThan(weak, off)
    }

    func testKeyPhrasesAloneAreNoText() throws {
        // Only the key words of the points, far under the minimum length: the content counts much less.
        XCTAssertLessThan(try writing("krank Hausaufgaben Donnerstag"), 40)
    }

    func testSilenceGetsNoSpeakingPoints() throws {
        let task = try XCTUnwrap(SpeakingBank.tasks("A1").first, "no A1 speaking task")
        XCTAssertEqual(TaskScorer.speaking(task, heard: "ja", seconds: 30, unsure: []).percent, 0)
    }
}
