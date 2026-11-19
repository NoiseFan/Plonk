import AppKit
import ApplicationServices

struct E2EBlocked: Error {
    let reason: String
    init(_ reason: String) { self.reason = reason }
}

func run() throws -> Bool {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments == ["--list"] {
        ShotCases.ids.forEach { print($0) }
        return true
    }
    if arguments == ["--permissions"] || arguments == ["--request-permissions"] {
        if arguments == ["--request-permissions"] {
            let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            if !AXIsProcessTrustedWithOptions(prompt as CFDictionary) {
                print("Approve the test driver in System Settings, then rerun --permissions.")
            } else if !CGPreflightPostEventAccess() {
                _ = CGRequestPostEventAccess()
            }
        }
        print("Driver: \(CommandLine.arguments[0])")
        let accessibility = AXIsProcessTrusted()
        let events = CGPreflightPostEventAccess()
        print("Accessibility: \(accessibility ? "granted" : "missing")")
        print("Post events: \(events ? "granted" : "missing")")
        print("Screen Recording (display evidence): \(CGPreflightScreenCaptureAccess() ? "granted" : "missing")")
        return accessibility && events
    }
    guard let path = arguments.first else { throw E2EFailure("Missing Plonk.app path.") }
    let requested = Array(arguments.dropFirst())
    let ids = requested.isEmpty ? ShotCases.ids : ShotCases.ids.filter { requested.contains($0) }
    guard Set(requested).isSubset(of: Set(ShotCases.ids)) else {
        throw E2EFailure("Unknown case. Use --list to see implemented cases.")
    }
    guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else {
        throw E2EFailure("Grant Accessibility and event posting access to the test driver. Use ./scripts/test-e2e.sh --permissions for its path and permission status.")
    }
    guard NSRunningApplication.runningApplications(withBundleIdentifier: "dev.plonk.app").isEmpty else {
        throw E2EFailure("Quit the running Plonk instance before starting the desktop suite.")
    }

    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    application.finishLaunching()

    let bundle = URL(fileURLWithPath: path)
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.arguments = ["-AppleLanguages", "(en)"]
    var launchResult: Result<NSRunningApplication, Error>?
    NSWorkspace.shared.openApplication(at: bundle, configuration: configuration) { process, error in
        DispatchQueue.main.async {
            launchResult = process.map(Result.success) ?? .failure(error ?? E2EFailure("Plonk did not launch."))
        }
    }
    let deadline = Date(timeIntervalSinceNow: 15)
    while launchResult == nil && deadline.timeIntervalSinceNow > 0 {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.025))
    }
    guard let launchResult else { throw E2EFailure("Timed out launching Plonk.") }
    let process = try launchResult.get()
    defer { process.terminate() }

    let artifacts = ShotArtifacts()
    let desktop = try Desktop(plonk: process, artifacts: artifacts)
    let cases = ShotCases(desktop: desktop)
    _ = try desktop.wait("Plonk launch", timeout: 15) { process.isFinishedLaunching ? true : nil }

    var passed = true
    for id in ids {
        artifacts.begin()
        let pasteboard = PasteboardSnapshot()
        defer { pasteboard.restore() }
        do {
            try cases.run(id)
            print("PASS \(id)")
        } catch let blocker as E2EBlocked {
            passed = false
            reportFailure(artifacts, id: id, status: "BLOCKED", details: blocker.reason)
        } catch {
            passed = false
            reportFailure(artifacts, id: id, status: "FAIL", details: String(describing: error))
        }
    }
    return passed
}

private func reportFailure(_ artifacts: ShotArtifacts, id: String, status: String, details: String) {
    print("\(status) \(id): \(details)")
    do {
        let directory = try artifacts.writeFailure(id: id, status: status, details: details)
        print("  Evidence: \(directory.path)")
    } catch {
        print("  Could not record failure evidence: \(error)")
    }
}

do {
    exit(try run() ? 0 : 1)
} catch {
    FileHandle.standardError.write(Data("E2E setup: \(error)\n".utf8))
    exit(2)
}
