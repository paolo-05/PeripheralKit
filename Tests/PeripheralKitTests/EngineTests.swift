import XCTest
import CoreGraphics
#if SWIFT_PACKAGE
@testable import PeripheralKit
private typealias TestRGBColor = PeripheralKit.RGBColor
#else
private typealias TestRGBColor = RGBColor
#endif

@MainActor
private final class MockDeskLightTransport: DeskLightTransport {
    struct Command { let id: UUID; let on: Bool; let color: TestRGBColor }
    var commands: [Command] = []
    var completion: ((Result<Void, Error>) -> Void)?
    func send(to id: UUID, on: Bool, color: TestRGBColor, completion: @escaping (Result<Void, Error>) -> Void) {
        commands.append(Command(id: id, on: on, color: color))
        self.completion = completion
    }
    func cancel() {
        let callback = completion
        completion = nil
        callback?(.failure(CancellationError()))
    }
    func complete(_ result: Result<Void, Error> = .success(())) {
        let callback = completion
        completion = nil
        callback?(result)
    }
}

@MainActor
final class DeskLightSleepTests: XCTestCase {
    private func configuration(on: Bool? = true) -> AppConfiguration {
        var config = AppConfiguration()
        config.deskLight = DeskLightConfiguration(identifier: UUID(), name: "Test", color: "#112233", sleepEnabled: true, requestedOn: on, requestedColor: "#123456")
        return config
    }

    func testLegacyDeskLightLoadsWithoutEnablingAutomationOrAssumingPower() throws {
        let json = ##"{"identifier":"C02C24A8-BF9D-23A3-5B82-28F0903DCC4E","name":"Triones","color":"#FF00DE"}"##
        let light = try JSONDecoder().decode(DeskLightConfiguration.self, from: Data(json.utf8))
        XCTAssertNil(light.sleepEnabled)
        XCTAssertNil(light.requestedOn)
        XCTAssertNil(light.requestedColor)
    }

    func testDisplayAndSystemOverlapRestoresLastRequestedColorOnce() async {
        let transport = MockDeskLightTransport()
        let coordinator = DeskLightSleepCoordinator(transport: transport, wait: { _ in }, log: { _, _ in })
        var config = configuration()
        config.rgbEnabled = false // BLE automation is independent of USB.
        var policy = SleepPolicy()
        coordinator.update(configuration: config, policy: policy)
        await coordinator.finishScheduledCommand()
        XCTAssertTrue(transport.commands.isEmpty)
        policy.receive(.displaysDidSleep)
        coordinator.update(configuration: config, policy: policy)
        await coordinator.finishScheduledCommand()
        transport.complete()
        policy.receive(.systemWillSleep)
        coordinator.update(configuration: config, policy: policy)
        policy.receive(.systemDidWake)
        coordinator.update(configuration: config, policy: policy)
        XCTAssertEqual(transport.commands.map(\.on), [false])
        policy.receive(.displaysDidWake)
        coordinator.update(configuration: config, policy: policy)
        await coordinator.finishScheduledCommand()
        XCTAssertEqual(transport.commands.map(\.on), [false, true])
        XCTAssertEqual(transport.commands.last?.color, try? RGBColor(hex: "#123456"))
    }

    func testOffOrUnknownLightIsNeverRelit() async {
        for state: Bool? in [false, nil] {
            let transport = MockDeskLightTransport()
            let coordinator = DeskLightSleepCoordinator(transport: transport, wait: { _ in }, log: { _, _ in })
            let config = configuration(on: state)
            coordinator.update(configuration: config, policy: SleepPolicy(systemSleeping: true))
            await coordinator.finishScheduledCommand()
            coordinator.update(configuration: config, policy: SleepPolicy())
            await coordinator.finishScheduledCommand()
            XCTAssertTrue(transport.commands.isEmpty)
        }
    }

    func testWakeRetriesAreBounded() async {
        let transport = MockDeskLightTransport()
        let coordinator = DeskLightSleepCoordinator(transport: transport, wait: { _ in }, log: { _, _ in })
        let config = configuration()
        coordinator.update(configuration: config, policy: SleepPolicy(systemSleeping: true))
        await coordinator.finishScheduledCommand()
        transport.complete()
        coordinator.update(configuration: config, policy: SleepPolicy())
        for _ in 0..<3 {
            await coordinator.finishScheduledCommand()
            transport.complete(.failure(PeripheralKitError.deviceNotFound("test")))
        }
        await coordinator.finishScheduledCommand()
        XCTAssertEqual(transport.commands.map(\.on), [false, true, true, true])
    }

    func testManualOffInvalidatesWakeCallbackAndRetries() async {
        let transport = MockDeskLightTransport()
        let coordinator = DeskLightSleepCoordinator(transport: transport, wait: { _ in }, log: { _, _ in })
        var config = configuration()
        coordinator.update(configuration: config, policy: SleepPolicy(systemSleeping: true))
        await coordinator.finishScheduledCommand()
        transport.complete()
        coordinator.update(configuration: config, policy: SleepPolicy())
        await coordinator.finishScheduledCommand()
        let stale = transport.completion
        config.deskLight?.requestedOn = false
        coordinator.manual(config.deskLight!, on: false)
        stale?(.failure(PeripheralKitError.deviceNotFound("test")))
        await coordinator.finishScheduledCommand()
        transport.complete()
        coordinator.update(configuration: config, policy: SleepPolicy(systemSleeping: true))
        coordinator.update(configuration: config, policy: SleepPolicy())
        await coordinator.finishScheduledCommand()
        XCTAssertEqual(transport.commands.map(\.on), [false, true, false])
    }

    func testDisableOrForgetDuringWakeCancelsRetries() async {
        for forget in [false, true] {
            let transport = MockDeskLightTransport()
            let coordinator = DeskLightSleepCoordinator(transport: transport, wait: { _ in }, log: { _, _ in })
            var config = configuration()
            coordinator.update(configuration: config, policy: SleepPolicy(systemSleeping: true))
            await coordinator.finishScheduledCommand()
            transport.complete()
            coordinator.update(configuration: config, policy: SleepPolicy())
            await coordinator.finishScheduledCommand()
            let stale = transport.completion
            if forget { config.deskLight = nil } else { config.deskLight?.sleepEnabled = false }
            coordinator.update(configuration: config, policy: SleepPolicy())
            stale?(.failure(PeripheralKitError.deviceNotFound("test")))
            await coordinator.finishScheduledCommand()
            XCTAssertEqual(transport.commands.map(\.on), [false, true])
        }
    }

    func testNewSleepCancelsDelayedWake() async {
        let transport = MockDeskLightTransport()
        let coordinator = DeskLightSleepCoordinator(transport: transport, wait: { delay in
            if delay > 0 { try await Task.sleep(for: .seconds(60)) }
        }, log: { _, _ in })
        let config = configuration()
        coordinator.update(configuration: config, policy: SleepPolicy(systemSleeping: true))
        await coordinator.finishScheduledCommand()
        transport.complete()
        coordinator.update(configuration: config, policy: SleepPolicy())
        coordinator.update(configuration: config, policy: SleepPolicy(systemSleeping: true))
        await coordinator.finishScheduledCommand()
        XCTAssertEqual(transport.commands.map(\.on), [false, false])
    }

    func testRestoreDisabledDoesNotRelight() async {
        let transport = MockDeskLightTransport()
        let coordinator = DeskLightSleepCoordinator(transport: transport, wait: { _ in }, log: { _, _ in })
        var config = configuration()
        config.restoreOnWake = false
        coordinator.update(configuration: config, policy: SleepPolicy(systemSleeping: true))
        await coordinator.finishScheduledCommand()
        transport.complete()
        coordinator.update(configuration: config, policy: SleepPolicy())
        await coordinator.finishScheduledCommand()
        XCTAssertEqual(transport.commands.map(\.on), [false])
    }

    func testDisablingRestoreDuringWakeCancelsFurtherAttempts() async {
        let transport = MockDeskLightTransport()
        let coordinator = DeskLightSleepCoordinator(transport: transport, wait: { _ in }, log: { _, _ in })
        var config = configuration()
        coordinator.update(configuration: config, policy: SleepPolicy(systemSleeping: true))
        await coordinator.finishScheduledCommand()
        transport.complete()
        coordinator.update(configuration: config, policy: SleepPolicy())
        await coordinator.finishScheduledCommand()
        let stale = transport.completion
        config.restoreOnWake = false
        coordinator.update(configuration: config, policy: SleepPolicy())
        stale?(.failure(PeripheralKitError.deviceNotFound("test")))
        await coordinator.finishScheduledCommand()
        XCTAssertEqual(transport.commands.map(\.on), [false, true])
    }

    func testRequestedStateAndColorPersistAndInvalidColorIsRejected() throws {
        let config = configuration(on: false)
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(decoded, config)
        var invalid = config
        invalid.deskLight?.requestedColor = "invalid"
        XCTAssertThrowsError(try invalid.validate())
    }
}

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
        XCTAssertEqual(events.map(\.type), Array(repeating: [CGEventType.flagsChanged, .keyDown, .keyUp, .flagsChanged], count: 3).flatMap { $0 })
        XCTAssertEqual(events.map { $0.getIntegerValueField(.keyboardEventKeycode) }, [59, 123, 123, 59, 59, 124, 124, 59, 59, 126, 126, 59])
        XCTAssertTrue(events.filter { $0.type == .keyDown || $0.type == .keyUp }.allSatisfy { $0.flags.contains(.maskControl) })
        XCTAssertTrue([3, 7, 11].allSatisfy { events[$0].flags.isEmpty })
        XCTAssertTrue(events.allSatisfy { $0.getIntegerValueField(.eventSourceUserData) == InputEventEngine.syntheticMarker })
    }

    @MainActor
    func testSpaceShortcutEntersHIDStreamBeforeSessionHotkeyRouting() throws {
        var destinations: [CGEventTapLocation] = []
        let executor = ActionEngine(post: { _, destination in destinations.append(destination) }, canPost: { true })
        try executor.execute([.previousSpace, .nextSpace])
        XCTAssertEqual(destinations, Array(repeating: .cghidEventTap, count: 8))
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
        XCTAssertEqual(events.map { $0.getIntegerValueField(.keyboardEventKeycode) }, [58, 56, 55, 36, 36, 55, 56, 58])
        XCTAssertEqual(events[3].flags, [.maskAlternate, .maskShift, .maskCommand])
        XCTAssertEqual(events[5].flags, [.maskAlternate, .maskShift])
        XCTAssertEqual(events[6].flags, [.maskAlternate])
        XCTAssertTrue(events[7].flags.isEmpty)
        XCTAssertThrowsError(try executor.execute([.shortcut(KeyboardShortcut(keyCode: 200))]))
    }
}

final class ConfigurationTests: XCTestCase {
    func testGradientInterpolationWrapsSmoothlyToFirstColor() throws {
        let gradient = try RGBGradient(colors: ["#FF0000", "#0000FF"], duration: 4)
        XCTAssertEqual(gradient.color(at: 0).hex, "#FF0000")
        XCTAssertEqual(gradient.color(at: 1).hex, "#800080")
        XCTAssertEqual(gradient.color(at: 2).hex, "#0000FF")
        XCTAssertEqual(gradient.color(at: 3).hex, "#800080")
        XCTAssertEqual(gradient.color(at: 4).hex, "#FF0000")
        XCTAssertEqual(gradient.color(at: 8).hex, "#FF0000")
    }

    func testGradientValidationAndConfigurationCompatibility() throws {
        XCTAssertThrowsError(try RGBGradient(colors: ["#FFFFFF"], duration: 12))
        XCTAssertThrowsError(try RGBGradient(colors: ["#FFFFFF", "invalid"], duration: 12))
        XCTAssertThrowsError(try RGBGradient(colors: ["#FFFFFF", "#000000"], duration: .infinity))
        XCTAssertThrowsError(try RGBGradient(colors: ["#FFFFFF", "#000000"], duration: 0))
        let old = try JSONDecoder().decode(MouseConfiguration.self, from: Data(##"{"enabled":true,"mode":"spectrum","color":"#00FF00"}"##.utf8))
        XCTAssertNil(old.spectrumColors)
        var config = AppConfiguration()
        config.rgb.mouse.spectrumColors = ["#FF0000", "#0000FF", "#00FF00"]
        config.rgb.mouse.spectrumDurationSeconds = 20
        try config.validate()
        XCTAssertEqual(try JSONDecoder().decode(AppConfiguration.self, from: JSONEncoder().encode(config)), config)
    }
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
    let wakeReapplyDelays: [Double]
    init(id: String = "mock", wakeFailures: Int = 0, wakeReapplyDelays: [Double] = []) { self.id = id; self.wakeFailures = wakeFailures; self.wakeReapplyDelays = wakeReapplyDelays }
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

private actor WakeReapplyGate {
    private var entered = false
    private var entrance: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?

    func wait(_ delay: Double) async {
        guard delay == 2 else { return }
        entered = true
        entrance?.resume()
        entrance = nil
        await withCheckedContinuation { release = $0 }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { entrance = $0 }
    }

    func resume() {
        release?.resume()
        release = nil
    }
}

final class RGBSleepTests: XCTestCase, @unchecked Sendable {
    func testReconnectDoesNotChangeSleepExclusion() async {
        let mouse = MockRGBAdapter(id: RGBProfileTarget.mouse.adapterID)
        let gate = WakeReapplyGate()
        let coordinator = RGBSleepCoordinator(adapters: [mouse], wait: { _ in await gate.wait(2) }, log: { _, _ in })
        var config = AppConfiguration()
        config.rgb.mouse.enabled = false
        await coordinator.reconnect([mouse.id], configuration: config.rgb)
        await gate.waitUntilEntered()
        await coordinator.transition(toSleep: true, configuration: config)
        XCTAssertTrue(mouse.states.isEmpty)
        await gate.resume()
        await coordinator.shutdown()
    }

    func testLogoGradientLeavesNativeWheelEffectUnchanged() async {
        let mouse = MockRGBAdapter(id: RGBProfileTarget.mouse.adapterID, wakeFailures: 10)
        let coordinator = RGBSleepCoordinator(adapters: [mouse], cycleWait: { _ in }, log: { _, _ in })
        var config = Configuration()
        config.mouse.logo = MouseZoneConfiguration(mode: .spectrum, color: "#FF0000", spectrumColors: ["#FF0000", "#0000FF"])
        await coordinator.resumeSavedMouseCycle(config)
        await coordinator.finishCurrentMouseCycle()
        XCTAssertEqual(mouse.configurations.count, 3)
        XCTAssertTrue(mouse.configurations.allSatisfy { $0.mouse.mode == .spectrum && $0.mouse.logo?.mode == .static })
    }

    func testReconnectRetriesOnlySelectedAdapterAndPreservesSavedColors() async {
        let keyboard = MockRGBAdapter(id: RGBProfileTarget.keyboard.adapterID)
        let mouse = MockRGBAdapter(id: RGBProfileTarget.mouse.adapterID, wakeFailures: 2)
        let coordinator = RGBSleepCoordinator(adapters: [keyboard, mouse], wait: { _ in }, log: { _, _ in })
        var config = Configuration()
        config.mouse.mode = .static
        config.mouse.color = "#123456"
        await coordinator.reconnect([mouse.id], configuration: config)
        await coordinator.finishPendingRestoration()
        XCTAssertTrue(keyboard.states.isEmpty)
        XCTAssertEqual(mouse.states.count, 3)
        XCTAssertEqual(mouse.configurations.last?.mouse.color, "#123456")
    }

    func testReconnectWhileSleepingDoesNotRelight() async {
        let mouse = MockRGBAdapter(id: RGBProfileTarget.mouse.adapterID)
        let coordinator = RGBSleepCoordinator(adapters: [mouse], wait: { _ in }, log: { _, _ in })
        await coordinator.transition(toSleep: true, configuration: AppConfiguration())
        await coordinator.reconnect([mouse.id], configuration: Configuration())
        await coordinator.finishPendingRestoration()
        XCTAssertEqual(mouse.states, [.sleeping])
    }

    func testGradientStopsAfterBoundedDeviceFailures() async {
        let mouse = MockRGBAdapter(id: RGBProfileTarget.mouse.adapterID, wakeFailures: 10)
        let coordinator = RGBSleepCoordinator(adapters: [mouse], cycleWait: { _ in }, log: { _, _ in })
        var config = Configuration()
        config.mouse.spectrumColors = ["#FF0000", "#0000FF"]
        await coordinator.resumeSavedMouseCycle(config)
        await coordinator.finishCurrentMouseCycle()
        XCTAssertEqual(mouse.states.count, 3)
    }

    func testSleepInvalidatesPendingGradientFrame() async {
        let mouse = MockRGBAdapter(id: RGBProfileTarget.mouse.adapterID)
        let gate = WakeReapplyGate()
        let coordinator = RGBSleepCoordinator(adapters: [mouse], cycleWait: { _ in await gate.wait(2) }, log: { _, _ in })
        var config = AppConfiguration()
        config.rgb.mouse.spectrumColors = ["#FF0000", "#0000FF"]
        _ = await coordinator.applyProfile(config.rgb, target: .mouse)
        await gate.waitUntilEntered()
        let finishing = Task { await coordinator.finishCurrentMouseCycle() }
        await coordinator.transition(toSleep: true, configuration: config)
        await gate.resume()
        await finishing.value
        XCTAssertEqual(mouse.states, [.awake, .sleeping])
    }

    func testNewStaticProfileInvalidatesPendingGradientFrame() async {
        let mouse = MockRGBAdapter(id: RGBProfileTarget.mouse.adapterID)
        let gate = WakeReapplyGate()
        let coordinator = RGBSleepCoordinator(adapters: [mouse], cycleWait: { _ in await gate.wait(2) }, log: { _, _ in })
        var config = Configuration()
        config.mouse.spectrumColors = ["#FF0000", "#0000FF"]
        _ = await coordinator.applyProfile(config, target: .mouse)
        await gate.waitUntilEntered()
        let finishing = Task { await coordinator.finishCurrentMouseCycle() }
        config.mouse.mode = .static
        config.mouse.color = "#123456"
        _ = await coordinator.applyProfile(config, target: .mouse)
        await gate.resume()
        await finishing.value
        XCTAssertEqual(mouse.states, [.awake, .awake])
        XCTAssertEqual(mouse.configurations.last?.mouse.color, "#123456")
    }

    func testTargetedApplyOnlyWritesSelectedDeviceEvenWhenAutomationExcluded() async {
        let keyboard = MockRGBAdapter(id: RGBProfileTarget.keyboard.adapterID)
        let mouse = MockRGBAdapter(id: RGBProfileTarget.mouse.adapterID)
        let coordinator = RGBSleepCoordinator(adapters: [keyboard, mouse], log: { _, _ in })
        var config = Configuration()
        config.keyboard.enabled = false
        config.mouse.enabled = false
        let result = await coordinator.applyProfile(config, target: .mouse)
        XCTAssertEqual(result.successes, [mouse.id])
        XCTAssertTrue(keyboard.states.isEmpty)
        XCTAssertEqual(mouse.states, [.awake])
    }

    func testTargetedApplyPreservesOtherDevicePendingWake() async {
        let keyboard = MockRGBAdapter(id: RGBProfileTarget.keyboard.adapterID)
        let mouse = MockRGBAdapter(id: RGBProfileTarget.mouse.adapterID)
        let coordinator = RGBSleepCoordinator(adapters: [keyboard, mouse], wait: { delay in
            if delay == 1 { try await Task.sleep(for: .seconds(60)) }
        }, log: { _, _ in })
        let config = AppConfiguration()
        await coordinator.transition(toSleep: true, configuration: config)
        await coordinator.transition(toSleep: false, configuration: config)
        var changed = config.rgb
        changed.mouse.color = "#123456"
        _ = await coordinator.applyProfile(changed, target: .mouse)
        await coordinator.finishPendingRestoration()
        XCTAssertEqual(mouse.states, [.sleeping, .awake])
        XCTAssertEqual(keyboard.states, [.sleeping, .awake])
        XCTAssertEqual(mouse.configurations.last?.mouse.color, "#123456")
        XCTAssertEqual(keyboard.configurations.last?.keyboard, config.rgb.keyboard)
    }

    func testManualProfileReplacesPendingWakeReapply() async {
        let adapter = MockRGBAdapter(wakeReapplyDelays: [2, 5])
        let gate = WakeReapplyGate()
        let coordinator = RGBSleepCoordinator(adapters: [adapter], wait: { await gate.wait($0) }, log: { _, _ in })
        let original = AppConfiguration()
        await coordinator.transition(toSleep: true, configuration: original)
        let wake = Task {
            await coordinator.transition(toSleep: false, configuration: original)
            await coordinator.finishPendingRestoration()
        }
        await gate.waitUntilEntered()
        var updated = original.rgb
        updated.mouse.color = "#123456"
        let result = await coordinator.applyProfile(updated)
        await gate.resume()
        await wake.value
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(adapter.states, [.sleeping, .awake, .awake])
        XCTAssertEqual(adapter.configurations.last, updated)
        let cached = await coordinator.cachedConfiguration()
        XCTAssertNil(cached)
    }

    func testManualProfileDoesNotRelightWhileSleeping() async {
        let adapter = MockRGBAdapter()
        let coordinator = RGBSleepCoordinator(adapters: [adapter], log: { _, _ in })
        await coordinator.transition(toSleep: true, configuration: AppConfiguration())
        let result = await coordinator.applyProfile(Configuration())
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(adapter.states, [.sleeping])
    }

    func testManualProfileReportsPartialFailureAndSkipsExcludedDevices() async {
        let failed = MockRGBAdapter(id: "failed", wakeFailures: 1)
        let ready = MockRGBAdapter(id: "ready")
        let coordinator = RGBSleepCoordinator(adapters: [failed, ready], log: { _, _ in })
        let result = await coordinator.applyProfile(Configuration())
        XCTAssertEqual(result.successes, ["ready"])
        XCTAssertEqual(result.failures.count, 1)
        var excluded = Configuration()
        excluded.mouse.enabled = false
        let skipped = await coordinator.applyProfile(excluded)
        XCTAssertTrue(skipped.successes.isEmpty)
        XCTAssertEqual(ready.states, [.awake])
    }

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

    func testKeyboardReappliesAfterSuccessWithoutRepeatingMouse() async {
        let keyboard = MockRGBAdapter(id: "keyboard", wakeReapplyDelays: [2, 5])
        let mouse = MockRGBAdapter(id: "mouse")
        let coordinator = RGBSleepCoordinator(adapters: [keyboard, mouse], wait: { _ in }, log: { _, _ in })
        let original = AppConfiguration()
        await coordinator.transition(toSleep: true, configuration: original)
        await coordinator.transition(toSleep: false, configuration: original)
        await coordinator.finishPendingRestoration()
        XCTAssertEqual(keyboard.states, [.sleeping, .awake, .awake, .awake])
        XCTAssertEqual(mouse.states, [.sleeping, .awake])
        XCTAssertTrue(keyboard.configurations.allSatisfy { $0 == original.rgb })
        let snapshot = await coordinator.cachedConfiguration()
        XCTAssertNil(snapshot)
    }

    func testNewSleepCancelsKeyboardReapplyAfterFirstSuccessfulWrite() async {
        let keyboard = MockRGBAdapter(wakeReapplyDelays: [2, 5])
        let gate = WakeReapplyGate()
        let coordinator = RGBSleepCoordinator(adapters: [keyboard], wait: { await gate.wait($0) }, log: { _, _ in })
        await coordinator.transition(toSleep: true, configuration: AppConfiguration())
        let wake = Task {
            await coordinator.transition(toSleep: false, configuration: AppConfiguration())
            await coordinator.finishPendingRestoration()
        }
        await gate.waitUntilEntered()
        await coordinator.transition(toSleep: true, configuration: AppConfiguration())
        await gate.resume()
        await wake.value
        XCTAssertEqual(keyboard.states, [.sleeping, .awake, .sleeping])
        let snapshot = await coordinator.cachedConfiguration()
        XCTAssertNotNil(snapshot)
    }

    func testLateKeyboardEnumerationStillRecovers() async {
        let keyboard = MockRGBAdapter(wakeFailures: 5)
        let coordinator = RGBSleepCoordinator(adapters: [keyboard], wait: { _ in }, log: { _, _ in })
        await coordinator.transition(toSleep: true, configuration: AppConfiguration())
        await coordinator.transition(toSleep: false, configuration: AppConfiguration())
        await coordinator.finishPendingRestoration()
        XCTAssertEqual(keyboard.states.filter { $0 == .awake }.count, 6)
        let snapshot = await coordinator.cachedConfiguration()
        XCTAssertNil(snapshot)
    }

    func testRetryBudgetIsBoundedAndFailureRetainsSnapshot() async {
        let adapter = MockRGBAdapter(wakeFailures: 20)
        let coordinator = RGBSleepCoordinator(adapters: [adapter], wait: { _ in }, log: { _, _ in })
        await coordinator.transition(toSleep: true, configuration: AppConfiguration())
        await coordinator.transition(toSleep: false, configuration: AppConfiguration())
        await coordinator.finishPendingRestoration()
        XCTAssertEqual(adapter.states.filter { $0 == .awake }.count, 7)
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

final class ExtendedConfigurationTests: XCTestCase {
    func testApplicationRuleOverridesGlobalAndFallsBackOutsideApp() {
        let global = Rule(name: "Global", trigger: .mouseButton(4), actions: [.previousSpace])
        let specific = Rule(name: "Finder", trigger: .mouseButton(4), conditions: [.application("com.apple.finder")], actions: [.missionControl])
        let engine = RuleEngine()
        XCTAssertEqual(engine.match(InputEvent(trigger: .mouseButton(4), applicationBundleID: "com.apple.finder"), rules: [global, specific])?.id, specific.id)
        XCTAssertEqual(engine.match(InputEvent(trigger: .mouseButton(4), applicationBundleID: "com.apple.Safari"), rules: [global, specific])?.id, global.id)
    }

    func testScenesAndIndependentZonesRoundTrip() throws {
        var config = AppConfiguration()
        config.rgb.mouse.logo = MouseZoneConfiguration(mode: .static, color: "#FF0000")
        config.scenes = [RGBScene(name: "Sera", rgb: config.rgb, deskColor: "#FF00FF", deskOn: false)]
        try config.validate()
        let copy = try JSONDecoder().decode(AppConfiguration.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(config, copy)
        XCTAssertEqual(try copy.rgb.mouse.logo?.effect(), .static(try RGBColor(hex: "#FF0000")))
        XCTAssertEqual(try copy.rgb.mouse.primary.effect(), .spectrum)
    }

    func testInvalidSceneAndLogoAreRejected() {
        var config = AppConfiguration()
        config.rgb.mouse.logo = MouseZoneConfiguration(mode: .static, color: "invalid")
        XCTAssertThrowsError(try config.validate())
        config = AppConfiguration()
        config.scenes = [RGBScene(name: " ", rgb: Configuration())]
        XCTAssertThrowsError(try config.validate())
    }
}
