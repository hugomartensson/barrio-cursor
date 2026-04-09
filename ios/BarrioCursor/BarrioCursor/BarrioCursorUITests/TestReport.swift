import Foundation

/// Test report structure for capturing test results, screenshots, and errors.
/// Struct to avoid deinit-triggered SIGABRT (swift_task_deinitOnExecutorImpl) in the test runner.
struct TestReport {
    struct Step {
        let name: String
        var status: Status
        let timestamp: Date
        var error: String?
        var screenshot: String?
        
        enum Status: String {
            case started = "started"
            case passed = "passed"
            case failed = "failed"
            case skipped = "skipped"
        }
    }
    
    struct Screenshot {
        let filename: String
        let step: String
        let timestamp: Date
    }
    
    let testName: String
    let startTime: Date
    var endTime: Date?
    var steps: [Step] = []
    var screenshots: [Screenshot] = []
    var overallStatus: Status = .started
    
    enum Status: String {
        case started = "started"
        case passed = "passed"
        case failed = "failed"
    }
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var stepCount: Int {
        return steps.count
    }
    
    init(testName: String) {
        self.testName = testName
        self.startTime = Date()
    }
    
    mutating func startStep(_ name: String) {
        let step = Step(
            name: name,
            status: .started,
            timestamp: Date(),
            error: nil,
            screenshot: nil
        )
        steps.append(step)
    }
    
    mutating func completeStep(success: Bool, error: String? = nil) {
        guard var lastStep = steps.last else { return }
        lastStep.status = success ? .passed : .failed
        lastStep.error = error
        steps[steps.count - 1] = lastStep
        
        if !success {
            overallStatus = .failed
        }
    }
    
    mutating func addScreenshot(filename: String, step: String) {
        let screenshot = Screenshot(
            filename: filename,
            step: step,
            timestamp: Date()
        )
        screenshots.append(screenshot)
        
        // Link screenshot to current step if available
        if var lastStep = steps.last {
            lastStep.screenshot = filename
            steps[steps.count - 1] = lastStep
        }
    }
    
    mutating func finalize() {
        endTime = Date()
        if overallStatus == .started {
            overallStatus = .passed
        }
    }
    
    // MARK: - Report Generation
    
    func saveJSON(to url: URL) {
        let report: [String: Any] = [
            "testName": testName,
            "status": overallStatus.rawValue,
            "startTime": ISO8601DateFormatter().string(from: startTime),
            "endTime": endTime.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "duration": duration,
            "steps": steps.map { step in
                [
                    "name": step.name,
                    "status": step.status.rawValue,
                    "timestamp": ISO8601DateFormatter().string(from: step.timestamp),
                    "error": step.error ?? "",
                    "screenshot": step.screenshot ?? ""
                ]
            },
            "screenshots": screenshots.map { screenshot in
                [
                    "filename": screenshot.filename,
                    "step": screenshot.step,
                    "timestamp": ISO8601DateFormatter().string(from: screenshot.timestamp)
                ]
            },
            "summary": [
                "totalSteps": steps.count,
                "passedSteps": steps.filter { $0.status == .passed }.count,
                "failedSteps": steps.filter { $0.status == .failed }.count,
                "totalScreenshots": screenshots.count
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: report, options: .prettyPrinted)
            try jsonData.write(to: url)
        } catch {
            print("❌ Failed to save JSON report: \(error)")
        }
    }
    
    func saveMarkdown(to url: URL, screenshotsDir: URL) {
        var markdown = """
        # Test Report: \(testName)
        
        **Status:** \(overallStatus == .passed ? "✅ PASSED" : "❌ FAILED")  
        **Duration:** \(String(format: "%.2f", duration))s  
        **Started:** \(ISO8601DateFormatter().string(from: startTime))  
        **Completed:** \(endTime.map { ISO8601DateFormatter().string(from: $0) } ?? "N/A")
        
        ## Summary
        
        - **Total Steps:** \(steps.count)
        - **Passed:** \(steps.filter { $0.status == .passed }.count)
        - **Failed:** \(steps.filter { $0.status == .failed }.count)
        - **Screenshots:** \(screenshots.count)
        
        ## Test Steps
        
        """
        
        for (index, step) in steps.enumerated() {
            let statusIcon = step.status == .passed ? "✅" : (step.status == .failed ? "❌" : "⏳")
            markdown += "\n### Step \(index + 1): \(step.name)\n\n"
            markdown += "**Status:** \(statusIcon) \(step.status.rawValue.uppercased())\n"
            markdown += "**Timestamp:** \(ISO8601DateFormatter().string(from: step.timestamp))\n"
            
            if let error = step.error, !error.isEmpty {
                markdown += "\n**Error:**\n```\n\(error)\n```\n"
            }
            
            if let screenshot = step.screenshot {
                let screenshotPath = screenshotsDir.appendingPathComponent(screenshot).path
                markdown += "\n**Screenshot:**\n"
                markdown += "![\(step.name)](\(screenshotPath))\n"
            }
            
            markdown += "\n---\n"
        }
        
        markdown += "\n## Screenshots\n\n"
        for screenshot in screenshots {
            let screenshotPath = screenshotsDir.appendingPathComponent(screenshot.filename).path
            markdown += "### \(screenshot.step)\n"
            markdown += "![\(screenshot.step)](\(screenshotPath))\n\n"
        }
        
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("❌ Failed to save Markdown report: \(error)")
        }
    }
}
