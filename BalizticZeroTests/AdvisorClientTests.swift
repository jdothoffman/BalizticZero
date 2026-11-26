import XCTest
@testable import BalizticZero

final class AdvisorClientTests: XCTestCase {
    override func tearDown() {
        AdvisorURLProtocol.handler = nil
        super.tearDown()
    }

    func testReviewPostsTheImpactAndNotAPrompt() async throws {
        AdvisorURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/advise")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer dev-token")
            let raw = Self.body(of: request)
            let body = try? JSONSerialization.jsonObject(with: raw) as? [String: Any]
            XCTAssertEqual(body?["impactHighMOA"] as? Double ?? -1, 0.4, accuracy: 0.0001)
            XCTAssertEqual(body?["impactRightMOA"] as? Double ?? 1, -0.25, accuracy: 0.0001)
            XCTAssertNil(body?["prompt"])
            return (200, Data(Self.reviewJSON.utf8), [:])
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AdvisorURLProtocol.self]
        let advisor = RemoteBallisticAdvisor(session: URLSession(configuration: configuration))

        let review = try await advisor.review(sampleShot, baseURL: URL(string: "https://advisor.example")!, token: "dev-token")
        XCTAssertEqual(review.verdict, .withinCall)
        XCTAssertEqual(review.headline, "Inside what this wind call can explain.")
        XCTAssertEqual(review.causes.map(\.title), ["Wind", "Spin drift"])
        XCTAssertEqual(review.causes.first?.likelihood, .likely)
    }

    func testUnknownVerdictsAndFactorsStillDecode() throws {
        let json = #"{"review":{"verdict":"check_barrel","headline":"h","causes":[{"factor":"mirage_boil","likelihood":"certain","note":"n"}],"nextStep":"s","caution":""}}"#
        struct Wrapper: Decodable { var review: ShotReview }
        let review = try JSONDecoder().decode(Wrapper.self, from: Data(json.utf8)).review
        XCTAssertEqual(review.verdict, .unknown)
        XCTAssertFalse(review.verdict.needsAttention)
        XCTAssertEqual(review.causes.first?.title, "Mirage Boil")
        XCTAssertEqual(review.causes.first?.likelihood, .unknown)
    }

    func testRateLimitSaysWhenToTryAgain() async {
        AdvisorURLProtocol.handler = { _ in
            (429, Data(#"{"error":"too many requests; slow down"}"#.utf8), ["Retry-After": "20"])
        }
        let advisor = RemoteBallisticAdvisor(session: Self.stubbedSession())
        do {
            _ = try await advisor.review(sampleShot, baseURL: URL(string: "https://advisor.example")!, token: "t")
            XCTFail("expected a rate limit")
        } catch {
            XCTAssertEqual(error as? AdvisorError, .rateLimited(retryAfterSeconds: 20))
            XCTAssertEqual(error.localizedDescription, "Too many reviews in a row. Try again in 20 s.")
        }
    }

    func testAPlainTextReplyIsABadResponse() async {
        AdvisorURLProtocol.handler = { _ in (200, Data(#"{"text":"old server"}"#.utf8), [:]) }
        let advisor = RemoteBallisticAdvisor(session: Self.stubbedSession())
        do {
            _ = try await advisor.review(sampleShot, baseURL: URL(string: "https://advisor.example")!, token: "t")
            XCTFail("expected a bad response")
        } catch {
            XCTAssertEqual(error as? AdvisorError, .badResponse)
        }
    }

    func testTheAddressMustBeHTTPS() {
        XCTAssertEqual(try AdvisorError.validatedBaseURL(" https://advisor.example ").host(), "advisor.example")
        XCTAssertThrowsError(try AdvisorError.validatedBaseURL("http://advisor.example")) { error in
            XCTAssertEqual(error as? AdvisorError, .insecureAddress)
        }
        XCTAssertThrowsError(try AdvisorError.validatedBaseURL("")) { error in
            XCTAssertEqual(error as? AdvisorError, .notConfigured)
        }
        XCTAssertThrowsError(try AdvisorError.validatedBaseURL("advisor.example")) { error in
            XCTAssertEqual(error as? AdvisorError, .notConfigured)
        }
    }

    func testTheTokenMovesOutOfUserDefaults() throws {
        let suite = "advisor-token-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("legacy-token", forKey: "advisorToken")
        let store = MemoryTokenStore()

        XCTAssertEqual(store.loadMovingLegacyDefault(key: "advisorToken", defaults: defaults), "legacy-token")
        XCTAssertEqual(store.read(), "legacy-token")
        XCTAssertNil(defaults.string(forKey: "advisorToken"))
    }

    func testTheTokenStaysInDefaultsIfTheKeychainWriteFails() throws {
        let suite = "advisor-token-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("legacy-token", forKey: "advisorToken")
        let store = MemoryTokenStore(failsWrites: true)

        XCTAssertEqual(store.loadMovingLegacyDefault(key: "advisorToken", defaults: defaults), "legacy-token")
        XCTAssertEqual(defaults.string(forKey: "advisorToken"), "legacy-token")
    }

    func testReviewResultMeasuresTheMissAgainstTheWind() {
        let result = ShotReviewResult(
            review: ShotReview(verdict: .withinCall, headline: "h", causes: [], nextStep: "s", caution: ""),
            reviewedAt: .now, rangeYards: 800,
            impactHighMOA: 0.5, impactRightMOA: -0.3,
            windDriftInches: -34.5, spinDriftInches: 3.2
        )
        XCTAssertEqual(result.missHighInches, 4.189, accuracy: 0.001)
        XCTAssertEqual(result.missRightInches, -2.513, accuracy: 0.001)
        XCTAssertEqual(result.windShare ?? 0, 2.513 / 34.5, accuracy: 0.001)

        var calm = result
        calm.windDriftInches = 0.2
        XCTAssertNil(calm.windShare)
    }

    func testImpactPlotRingFitsTheImpact() {
        XCTAssertEqual(ImpactPlot.ringRadius(highMOA: 0, rightMOA: 0, unit: .mil), 0.3)
        XCTAssertEqual(ImpactPlot.ringRadius(highMOA: 0, rightMOA: 0, unit: .moa), 1)
        // 0.3 MRAD left is about 1.03 MOA, which needs the 0.5 MRAD ring with some room.
        XCTAssertEqual(ImpactPlot.ringRadius(highMOA: 0, rightMOA: -0.3 * AngularScale.moaPerMil, unit: .mil), 0.5)
        XCTAssertEqual(ImpactPlot.ringRadius(highMOA: 4, rightMOA: 3, unit: .moa), 10)
        XCTAssertEqual(ImpactPlot.ringLabel(0.3, unit: .mil), "0.3 MRAD")
    }

    func testCoordinatesAreRoundedBeforeTheyLeaveThePhone() {
        XCTAssertEqual(CalculatorStore.coarse(38.89768), 38.90, accuracy: 1e-9)
        XCTAssertEqual(CalculatorStore.coarse(-77.03653), -77.04, accuracy: 1e-9)
    }

    func testReviewSurfacesTheServerMessage() async {
        AdvisorURLProtocol.handler = { _ in
            (401, Data(#"{"error":"unauthorized"}"#.utf8), [:])
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AdvisorURLProtocol.self]
        let advisor = RemoteBallisticAdvisor(session: URLSession(configuration: configuration))

        do {
            _ = try await advisor.review(sampleShot, baseURL: URL(string: "https://advisor.example/v1/advise")!, token: "nope")
            XCTFail("expected the server message")
        } catch {
            XCTAssertEqual(error.localizedDescription, "unauthorized")
        }
    }

    private static let reviewJSON = #"""
    {"review":{"verdict":"within_call","headline":"Inside what this wind call can explain.",
    "causes":[{"factor":"wind","likelihood":"likely","note":"A small lull covers it."},
    {"factor":"spin_drift","likelihood":"unlikely","note":"Already in the dial."}],
    "nextStep":"Hold the same dial and fire one more.","caution":"One shot cannot true velocity."}}
    """#

    private static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AdvisorURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: 1024)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private var sampleShot: AdvisorShot {
        AdvisorShot(
            rangeYards: 800, azimuthDegrees: 0, inclineDegrees: 0,
            latitudeDegrees: 38.9, longitudeDegrees: -77,
            temperatureF: 59, stationPressureInHg: 29.92, humidityPercent: 40, altitudeFeet: 300,
            windSpeedMph: 10, windFromDegrees: 90,
            comeUpMOA: 18.2, windageMOA: 3.4,
            spinDriftInches: 4, coriolisHorizontalInches: 1, coriolisVerticalInches: 0.5,
            aerodynamicWindageInches: 28,
            impactHighMOA: 0.4, impactRightMOA: -0.25
        )
    }
}

private final class AdvisorURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data, [String: String]))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data, headers) = handler(request)
        let fields = headers.merging(["Content-Type": "application/json"]) { current, _ in current }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: fields)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class MemoryTokenStore: AdvisorTokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?
    private let failsWrites: Bool

    init(failsWrites: Bool = false) {
        self.failsWrites = failsWrites
    }

    func read() -> String? {
        lock.withLock { token }
    }

    func write(_ token: String) {
        guard !failsWrites else { return }
        lock.withLock { self.token = token.isEmpty ? nil : token }
    }
}

final class ImpactTargetPickerTests: XCTestCase {
    func testDragsSnapToTheStepAndStayOnTheField() {
        let snapped = ImpactTargetPicker.snapped(CGPoint(x: 0.337, y: -0.121), step: 0.05, span: 1)
        XCTAssertEqual(snapped.x, 0.35, accuracy: 1e-9)
        XCTAssertEqual(snapped.y, -0.10, accuracy: 1e-9)

        let outside = ImpactTargetPicker.snapped(CGPoint(x: 3.2, y: -9), step: 0.05, span: 1)
        XCTAssertEqual(outside.x, 1, accuracy: 1e-9)
        XCTAssertEqual(outside.y, -1, accuracy: 1e-9)

        // No negative zero, so an untouched axis reads as on call.
        XCTAssertEqual(ImpactTargetPicker.snapped(CGPoint(x: -0.01, y: 0.01), step: 0.05, span: 1).x.sign, .plus)
    }

    func testEveryZoomHasWholeGridAndSnapSteps() {
        for unit in [ClickUnit.mil, .moa] {
            for scale in ImpactTargetPicker.scales(for: unit) {
                let rings = scale.span / scale.grid
                let snapsPerGrid = scale.grid / scale.snap
                XCTAssertEqual(rings, rings.rounded(), accuracy: 1e-9, "\(unit) span \(scale.span)")
                XCTAssertEqual(snapsPerGrid, snapsPerGrid.rounded(), accuracy: 1e-9, "\(unit) span \(scale.span)")
            }
        }
    }
}
