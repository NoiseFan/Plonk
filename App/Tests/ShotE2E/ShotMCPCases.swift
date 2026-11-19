import AppKit
import ImageIO

extension ShotCases {
    func mcpAnnotation(_ kind: String) throws {
        let files = FileManager.default
        let directory = files.temporaryDirectory.appendingPathComponent("plonk-mcp-e2e-\(UUID().uuidString)")
        try files.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: directory) }
        let client = Process()
        client.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        client.arguments = ["node", "mcp/test/e2e/annotation.mjs", kind, directory.path]
        try client.run()
        defer { if client.isRunning { client.terminate() } }
        _ = try desktop.wait("MCP annotation tool to finish", timeout: 35) { client.isRunning ? nil : true }
        try require(client.terminationStatus == 0, "MCP annotation exited with status \(client.terminationStatus).")
        let input = try mcpImage(directory.appendingPathComponent("source.png"))
        let output = try mcpImage(directory.appendingPathComponent("marked.png"))
        desktop.artifacts.recordExport(output)
        let probes: [CGPoint] = kind == "line"
            ? [CGPoint(x: 0.33, y: 0.415), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.67, y: 0.585)]
            : [CGPoint(x: 0.4, y: 0.5), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.6, y: 0.5)]
        for point in probes {
            let marked = try mcpSample(output, at: point)
            if kind == "line" {
                try require(Int(marked[0]) > Int(marked[1]) + 80 && Int(marked[0]) > Int(marked[2]) + 80,
                            "Expected red line at \(point).")
            } else {
                let source = try mcpSample(input, at: point)
                try require(marked == source, "Spotlight changed source pixels inside the union at \(point).")
            }
        }
        if kind == "spotlight" {
            let candidates = [CGPoint(x: 0.3, y: 0.5), CGPoint(x: 0.7, y: 0.5), CGPoint(x: 0.5, y: 0.3)]
            let dimmed = try candidates.contains { point in
                let original = try mcpSample(input, at: point)
                let marked = try mcpSample(output, at: point)
                return original.prefix(3).reduce(0) { $0 + Int($1) }
                    > marked.prefix(3).reduce(0) { $0 + Int($1) } + 25
            }
            try require(dimmed, "Expected reduced brightness outside the spotlight union.")
        }
    }

    private func mcpImage(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw E2EFailure("Cannot decode \(url.lastPathComponent).")
        }
        return image
    }

    private func mcpSample(_ image: CGImage, at point: CGPoint) throws -> [UInt8] {
        try pixel(image, x: Int(point.x * CGFloat(image.width)), y: Int(point.y * CGFloat(image.height)))
    }
}
