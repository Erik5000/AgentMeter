import XCTest
@testable import AgentMeter

final class DualBarIconLayoutTests: XCTestCase {
    func test_loading_usesSpinnerEvenWhenCodexColumnsWouldBeEmpty() {
        XCTAssertEqual(
            DualBarIconLayout.resolve(
                isLoading: true,
                showsCodex: true,
                hasProviderValues: false
            ),
            .loading
        )
    }

    func test_codexEnabledWithNoValues_usesIdlePlaceholderInsteadOfEmptyMeters() {
        XCTAssertEqual(
            DualBarIconLayout.resolve(
                isLoading: false,
                showsCodex: true,
                hasProviderValues: false
            ),
            .idle
        )
    }

    func test_codexEnabledWithAnyValue_keepsPairedColumns() {
        XCTAssertEqual(
            DualBarIconLayout.resolve(
                isLoading: false,
                showsCodex: true,
                hasProviderValues: true
            ),
            .pairedColumns
        )
    }

    func test_codexHidden_keepsSingleColumnEvenWithoutProviderValues() {
        XCTAssertEqual(
            DualBarIconLayout.resolve(
                isLoading: false,
                showsCodex: false,
                hasProviderValues: false
            ),
            .singleColumn
        )
    }
}
