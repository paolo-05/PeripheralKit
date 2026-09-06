import XCTest
import CoreGraphics
#if SWIFT_PACKAGE
@testable import PeripheralKit
#endif

final class EngineTests: XCTestCase {
    func testXcodeAndCocoaArgumentsLaunchTheApp() {
        XCTAssertEqual(LaunchMode.resolve(arguments: ["-NSDocumentRevisionsDebugMode", "YES", "--settings"]), .application)
        XCTAssertEqual(LaunchMode.resolve(arguments: ["--safe-mode"]), .application)
        XCTAssertEqual(LaunchMode.resolve(arguments: []), .application)
    }

    func testExplicitCLICommandsUseCLI() {
        XCTAssertEqual(LaunchMode.resolve(arguments: ["devices"]), .commandLine)
        XCTAssertEqual(LaunchMode.resolve(arguments: ["on", "--config", "example.json"]), .commandLine)
    }

    func testRuleMatchesButtonAndForegroundApplication() {
        let rule = Rule(name: "Safari", trigger: .mouseButton(4), conditions: [.application("com.apple.Safari")], actions: [.previousSpace])
        let engine = RuleEngine()
        XCTAssertEqual(engine.match(InputEvent(trigger: .mouseButton(4), applicationBundleID: "com.apple.Safari"), rules: [rule]), rule)
        XCTAssertNil(engine.match(InputEvent(trigger: .mouseButton(4), applicationBundleID: "com.apple.finder"), rules: [rule]))
        XCTAssertNil(engine.match(InputEvent(trigger: .mouseButton(5), applicationBundleID: "com.apple.Safari"), rules: [rule]))
    }

    func testUnknownSourceNeverMatchesDeviceCondition() {
        let reference = PeripheralDeviceReference(vendorID: 0x1532, productID: 0x84, serialNumber: "ABC")
        let rule = Rule(name: "Razer", trigger: .mouseButton(4), conditions: [.device(reference)], actions: [.previousSpace])
        XCTAssertNil(RuleEngine().match(InputEvent(trigger: .mouseButton(4)), rules: [rule]))
        let device = PeripheralDevice(id: "a", vendorID: 0x1532, productID: 0x84, serialNumber: "ABC", productName: "Other name", manufacturer: "Razer", locationID: 1, usagePage: 1, usage: 2)
        XCTAssertTrue(reference.matches(device))
        XCTAssertFalse(PeripheralDeviceReference(vendorID: 0x1532, productID: 0x84, serialNumber: "DEF").matches(device))
        XCTAssertFalse(PeripheralDeviceReference(vendorID: 0x1532, productID: 0x84, locationID: 2).matches(device))
    }

    func testDisabledRuleSkippedAndFirstMatchWins() {
        var disabled = AppConfiguration().rules[0]
        disabled.enabled = false
        let second = Rule(name: "Second", trigger: .mouseButton(4), actions: [.missionControl])
        XCTAssertEqual(RuleEngine().match(InputEvent(trigger: .mouseButton(4)), rules: [disabled, second])?.name, "Second")
    }

    func testConsumedReleaseSurvivesDisablingRemapping() {
        var router = MouseEventRouter(rules: AppConfiguration().rules, enabled: true)
        XCTAssertTrue(router.route(button: 4, down: true, application: nil).consume)
        router.enabled = false
        router.rules = []
        XCTAssertTrue(router.route(button: 4, down: false, application: nil).consume)
        XCTAssertFalse(router.route(button: 4, down: true, application: nil).consume)
        XCTAssertFalse(router.route(button: 4, down: false, application: nil).consume)
    }

    func testPassThroughStillDispatchesAndDoesNotConsumeRelease() {
        var rule = AppConfiguration().rules[0]
        rule.consumeOriginalEvent = false
        var router = MouseEventRouter(rules: [rule], enabled: true)
        let decision = router.route(button: 4, down: true, application: nil)
        XCTAssertFalse(decision.consume)
        XCTAssertEqual(decision.rule, rule)
        XCTAssertFalse(router.route(button: 4, down: false, application: nil).consume)
    }

    func testCaptureIgnoresPrimaryButtonsAndConsumesOneCompleteClick() {
        var router = MouseEventRouter(recording: true)
        XCTAssertNil(router.route(button: 1, down: true, application: nil).capturedButton)
        XCTAssertTrue(router.recording)
        XCTAssertEqual(router.route(button: 5, down: true, application: nil).capturedButton, 5)
        XCTAssertFalse(router.recording)
        XCTAssertTrue(router.route(button: 5, down: false, application: nil).consume)
        XCTAssertFalse(router.route(button: 4, down: true, application: nil).consume)
    }

    func testRepeatedDownDoesNotExecuteTwice() {
        var router = MouseEventRouter(rules: AppConfiguration().rules, enabled: true)
        XCTAssertNotNil(router.route(button: 4, down: true, application: nil).rule)
        let repeated = router.route(button: 4, down: true, application: nil)
        XCTAssertTrue(repeated.consume)
        XCTAssertNil(repeated.rule)
    }

    func testCancelledCapturePassesThrough() {
        var router = MouseEventRouter(recording: true)
        router.recording = false
        XCTAssertEqual(router.route(button: 5, down: true, application: nil), InputDecision())
    }

    func testSystemAndDisplayPoliciesRemainIndependent() {
        var configuration = AppConfiguration()
        configuration.displaySleepEnabled = false
        var policy = SleepPolicy()
        policy.receive(.displaysDidSleep)
        XCTAssertFalse(policy.shouldSleep(configuration: configuration))
        policy.receive(.systemWillSleep)
        XCTAssertTrue(policy.shouldSleep(configuration: configuration))
        policy.receive(.displaysDidWake)
        XCTAssertTrue(policy.shouldSleep(configuration: configuration))
        policy.receive(.systemDidWake)
        XCTAssertFalse(policy.shouldSleep(configuration: configuration))
    }

    @MainActor
    func testActionDispatchUsesPairedTaggedEventsInOrder() throws {
        var events: [CGEvent] = []
        let executor = ActionEngine(post: { event, _ in events.append(event) }, canPost: { true })
        try executor.execute([.previousSpace, .nextSpace, .missionControl])
        XCTAssertEqual(events.map(\.type), [.keyDown, .keyUp, .keyDown, .keyUp, .keyDown, .keyUp])
        XCTAssertEqual(events.map { $0.getIntegerValueField(.keyboardEventKeycode) }, [123, 123, 124, 124, 126, 126])
        XCTAssertTrue(events.allSatisfy { $0.flags.contains(.maskControl) })
        XCTAssertTrue(events.allSatisfy { $0.getIntegerValueField(.eventSourceUserData) == InputEventEngine.syntheticMarker })
    }

    @MainActor
    func testSpaceShortcutEntersHIDStreamBeforeSessionHotkeyRouting() throws {
        var destinations: [CGEventTapLocation] = []
        let executor = ActionEngine(post: { _, destination in destinations.append(destination) }, canPost: { true })
        try executor.execute([.previousSpace, .nextSpace])
        XCTAssertEqual(destinations, Array(repeating: .cghidEventTap, count: 4))
    }

    @MainActor
    func testDeniedPostingReportsErrorWithoutSendingPartialShortcut() {
        var posted = false
        let executor = ActionEngine(post: { _, _ in posted = true }, canPost: { false })
        XCTAssertThrowsError(try executor.execute([.nextSpace]))
        XCTAssertFalse(posted)
    }

    @MainActor
    func testCustomShortcutModifiersAndInvalidKey() throws {
        var events: [CGEvent] = []
        let executor = ActionEngine(post: { event, _ in events.append(event) }, canPost: { true })
        try executor.execute([.shortcut(KeyboardShortcut(keyCode: 36, control: false, option: true, shift: true, command: true))])
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].flags, [.maskAlternate, .maskShift, .maskCommand])
        XCTAssertThrowsError(try executor.execute([.shortcut(KeyboardShortcut(keyCode: 200))]))
    }
}

final class ConfigurationTests: XCTestCase {
    func testConfigurationRoundTripPreservesRGBAndRules() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ConfigurationStore(directory: root)
        var config = try store.load()
        config.rgb.mouse.mode = .static
        config.rgb.mouse.color = "#123456"
        config.remappingEnabled = true
        try store.save(config)
        XCTAssertEqual(try store.load(), config)
    }

    func testCorruptConfigIsNotOverwrittenByLoad() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = ConfigurationStore(directory: root)
        let bytes = Data("broken".utf8)
        try bytes.write(to: store.url)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: store.url), bytes)
    }

    func testRejectsPrimaryButtonAndFutureSchema() throws {
        var config = AppConfiguration()
        config.rules[0].trigger = .mouseButton(1)
        XCTAssertThrowsError(try config.validate())
        config = AppConfiguration()
        config.schemaVersion = 2
        XCTAssertThrowsError(try config.validate())
    }

    func testSnapshotNotOverwrittenOnRepeatedSleep() {
        var cache = RGBStateCache()
        let original = Configuration()
        cache.capture(original)
        var changed = original
        changed.mouse.color = "#112233"
        cache.capture(changed)
        XCTAssertEqual(cache.configuration, original)
        cache.clear()
        XCTAssertNil(cache.configuration)
    }
}

private final class MockRGBAdapter: RGBDeviceAdapter, @unchecked Sendable {
    let id: String
    var name: String { id }
    private let lock = NSLock()
    private var calls: [PowerState] = []
    private var configs: [Configuration] = []
    private var wakeFailures: Int
    init(id: String = "mock", wakeFailures: Int = 0) { self.id = id; self.wakeFailures = wakeFailures }
    func isEnabled(in configuration: Configuration) -> Bool { configuration.mouse.enabled }
    func apply(_ state: PowerState, configuration: Configuration) throws {
        try lock.withLock {
            calls.append(state)
            configs.append(configuration)
            if state == .awake && wakeFailures > 0 {
                wakeFailures -= 1
                throw PeripheralKitError.deviceNotFound(name)
            }
        }
    }
    var states: [PowerState] { lock.withLock { calls } }
    var configurations: [Configuration] { lock.withLock { configs } }
}

final class RGBSleepTests: XCTestCase, @unchecked Sendable {
    func testRestorationRetriesOnlyFailedDevicesAndKeepsSnapshot() async {
        let slow = MockRGBAdapter(id: "slow", wakeFailures: 2)
        let ready = MockRGBAdapter(id: "ready")
        let coordinator = RGBSleepCoordinator(adapters: [slow, ready], wait: { _ in }, log: { _, _ in })
        let original = AppConfiguration()
        await coordinator.transition(toSleep: true, configuration: original)
        var changed = original
        changed.rgb.mouse.color = "#112233"
        await coordinator.transition(toSleep: true, configuration: changed)
        await coordinator.transition(toSleep: false, configuration: changed)
        await coordinator.finishPendingRestoration()
        XCTAssertEqual(slow.states, [.sleeping, .awake, .awake, .awake])
        XCTAssertEqual(ready.states, [.sleeping, .awake])
        XCTAssertTrue(slow.configurations.allSatisfy { $0 == original.rgb })
        let snapshot = await coordinator.cachedConfiguration()
        XCTAssertNil(snapshot)
    }

    func testRetryBudgetIsBoundedAndFailureRetainsSnapshot() async {
        let adapter = MockRGBAdapter(wakeFailures: 20)
        let coordinator = RGBSleepCoordinator(adapters: [adapter], wait: { _ in }, log: { _, _ in })
        await coordinator.transition(toSleep: true, configuration: AppConfiguration())
        await coordinator.transition(toSleep: false, configuration: AppConfiguration())
        await coordinator.finishPendingRestoration()
        XCTAssertEqual(adapter.states.filter { $0 == .awake }.count, 5)
        let snapshot = await coordinator.cachedConfiguration()
        XCTAssertNotNil(snapshot)
    }

    func testNewSleepCancelsDelayedWake() async {
        let adapter = MockRGBAdapter()
        let coordinator = RGBSleepCoordinator(adapters: [adapter], wait: { _ in try await Task.sleep(for: .seconds(60)) }, log: { _, _ in })
        await coordinator.transition(toSleep: true, configuration: AppConfiguration())
        await coordinator.transition(toSleep: false, configuration: AppConfiguration())
        await coordinator.transition(toSleep: true, configuration: AppConfiguration())
        await coordinator.finishPendingRestoration()
        XCTAssertEqual(adapter.states, [.sleeping, .sleeping])
    }

    func testDisabledAdapterAndRestoreToggle() async {
        let adapter = MockRGBAdapter()
        let coordinator = RGBSleepCoordinator(adapters: [adapter], wait: { _ in }, log: { _, _ in })
        var config = AppConfiguration()
        config.rgb.mouse.enabled = false
        await coordinator.transition(toSleep: true, configuration: config)
        config.restoreOnWake = false
        await coordinator.transition(toSleep: false, configuration: config)
        XCTAssertTrue(adapter.states.isEmpty)
        let snapshot = await coordinator.cachedConfiguration()
        XCTAssertNil(snapshot)
    }
}
