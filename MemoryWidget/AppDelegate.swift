//
//  AppDelegate.swift
//  MemoryWidget
//
//  Created by Robert Rusinek on 01/03/2026.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var history: [Double] = Array(repeating: 0, count: 20)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        statusItem.menu = menu

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemory()
            }
        }
        updateMemory()
    }

    func updateMemory() {
        let (used, total) = getMemoryUsage()
        let percent = used / total

        history.removeFirst()
        history.append(percent)

        if let button = statusItem.button {
            let usedGB = String(format: "%.1f", used / 1_073_741_824)
            let totalGB = String(format: "%.0f", total / 1_073_741_824)
            let graph = drawGraph(history: history, size: NSSize(width: 30, height: 16))
            button.image = graph
            button.imagePosition = .imageLeft
            button.title = " \(usedGB)/\(totalGB) GB"
        }
    }

    func drawGraph(history: [Double], size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let context = NSGraphicsContext.current!.cgContext
        let height = size.height
        let barWidth = size.width / CGFloat(history.count)

        context.setFillColor(NSColor.clear.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        for (i, value) in history.enumerated() {
            let barHeight = CGFloat(value) * height
            let x = CGFloat(i) * barWidth

            let color: NSColor = value > 0.8 ? .systemRed : value > 0.6 ? .systemOrange : .systemGreen
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: x, y: 0, width: barWidth - 1, height: barHeight))
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    nonisolated func getMemoryUsage() -> (Double, Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (0, 1) }

        let pageSize = Double(vm_page_size)
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        let used = total - Double(stats.free_count + stats.external_page_count) * pageSize

        return (used, total)
    }
}
