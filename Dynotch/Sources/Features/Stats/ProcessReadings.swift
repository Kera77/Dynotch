import AppKit
import Darwin

/// An app with all its helper processes, or a single process (spec SY-6).
struct ProcessUsage: Identifiable, Equatable, Sendable {
    /// The app's bundle path, or "pid:123".
    let id: String
    let name: String
    let pids: [pid_t]
    /// Share of one core, 0…n (100% = one core busy).
    var cpu: Double
    var memory: UInt64
    /// The app's bundle, for its icon.
    let appPath: String?
}

/// The processes of one app (or one process), summed.
struct ProcessGroup: Equatable, Sendable {
    let key: String
    var pids: [pid_t] = []
    var cpu = 0.0
    var memory: UInt64 = 0
    let app: String?
}

enum ProcessReadings {
    struct Sample: Sendable {
        /// CPU time used so far per process, nanoseconds.
        var cpuTime: [pid_t: UInt64]
        var memory: [pid_t: UInt64]
        var date: Date
        /// Each process's executable.
        var paths: [pid_t: String] = [:]
    }

    static func sample() -> Sample {
        var sample = Sample(cpuTime: [:], memory: [:], date: Date())
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return sample }
        var pids = [pid_t](repeating: 0, count: Int(count) + 32)
        let found = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let scale = Double(timebase.numer) / Double(max(timebase.denom, 1))
        var buffer = [CChar](repeating: 0, count: 4096)
        for pid in pids.prefix(Int(max(found, 0))) where pid > 0 {
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { continue }
            // Task times are in Mach time units.
            sample.cpuTime[pid] = UInt64(Double(info.pti_total_user + info.pti_total_system) * scale)
            sample.memory[pid] = info.pti_resident_size
            if proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 { sample.paths[pid] = String(cString: buffer) }
        }
        return sample
    }

    /// CPU use between two samples, per process.
    nonisolated static func cpu(from old: Sample, to new: Sample) -> [pid_t: Double] {
        let seconds = new.date.timeIntervalSince(old.date)
        guard seconds > 0 else { return [:] }
        var result: [pid_t: Double] = [:]
        for (pid, time) in new.cpuTime {
            guard let before = old.cpuTime[pid], time >= before else { continue }
            result[pid] = Double(time - before) / 1_000_000_000 / seconds
        }
        return result
    }

    /// The outermost app bundle of an executable: a browser's helpers belong to the browser.
    nonisolated static func appBundle(of path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return path.hasSuffix(".app") ? path : nil }
        return String(path[..<range.lowerBound]) + ".app"
    }

    /// Readings joined per app, like Activity Monitor's apps (spec SY-6).
    nonisolated static func grouped(
        cpu: [pid_t: Double], memory: [pid_t: UInt64], paths: [pid_t: String]
    ) -> [ProcessGroup] {
        var groups: [String: ProcessGroup] = [:]
        for pid in Set(memory.keys).union(cpu.keys) {
            let app = paths[pid].flatMap(appBundle(of:))
            let key = app ?? "pid:\(pid)"
            var group = groups[key] ?? ProcessGroup(key: key, app: app)
            group.pids.append(pid)
            group.cpu += cpu[pid] ?? 0
            group.memory += memory[pid] ?? 0
            groups[key] = group
        }
        return groups.values.map { group in
            var sorted = group
            sorted.pids.sort()
            return sorted
        }
    }

    /// The top `limit` apps and processes by CPU or memory.
    @MainActor
    static func top(_ limit: Int, byMemory: Bool, cpu: [pid_t: Double], sample: Sample) -> [ProcessUsage] {
        let groups = grouped(cpu: cpu, memory: sample.memory, paths: sample.paths)
        let ranked = groups.sorted { byMemory ? $0.memory > $1.memory : $0.cpu > $1.cpu }
        return ranked.prefix(limit).map { group in
            ProcessUsage(
                id: group.key, name: name(of: group), pids: group.pids, cpu: group.cpu, memory: group.memory, appPath: group.app
            )
        }
    }

    @MainActor
    private static func name(of group: ProcessGroup) -> String {
        if let app = group.app {
            return FileManager.default.displayName(atPath: app).replacingOccurrences(of: ".app", with: "")
        }
        guard let pid = group.pids.first else { return group.key }
        if let name = NSRunningApplication(processIdentifier: pid)?.localizedName { return name }
        var buffer = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buffer, UInt32(buffer.count))
        let name = String(cString: buffer)
        return name.isEmpty ? "Process \(pid)" : name
    }

    /// The app is asked to quit (its helpers go with it); other processes get a terminate signal.
    @MainActor
    static func quit(_ process: ProcessUsage) {
        let apps = NSWorkspace.shared.runningApplications.filter { app in
            process.appPath.map { app.bundleURL?.path == $0 } ?? false
        }
        if !apps.isEmpty {
            apps.forEach { $0.terminate() }
        } else {
            process.pids.forEach { kill($0, SIGTERM) }
        }
        DiagnosticsLog.append("stats", "quit requested for \(process.pids.count) process(es)")
    }
}
