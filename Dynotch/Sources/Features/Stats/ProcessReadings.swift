import AppKit
import Darwin

/// The processes using the most CPU or memory (spec SY-6).
struct ProcessUsage: Identifiable, Equatable, Sendable {
    let id: pid_t
    let name: String
    /// Share of one core, 0…n (100% = one core busy).
    var cpu: Double
    var memory: UInt64
    let isApp: Bool
}

enum ProcessReadings {
    struct Sample: Sendable {
        /// CPU time used so far per process, nanoseconds.
        var cpuTime: [pid_t: UInt64]
        var memory: [pid_t: UInt64]
        var date: Date
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
        for pid in pids.prefix(Int(max(found, 0))) where pid > 0 {
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { continue }
            // Task times are in Mach time units.
            sample.cpuTime[pid] = UInt64(Double(info.pti_total_user + info.pti_total_system) * scale)
            sample.memory[pid] = info.pti_resident_size
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

    /// The top `limit` by CPU or by memory, named like Activity Monitor names them.
    @MainActor
    static func top(_ limit: Int, byMemory: Bool, cpu: [pid_t: Double], memory: [pid_t: UInt64]) -> [ProcessUsage] {
        let ranked = byMemory
            ? memory.sorted { $0.value > $1.value }.map(\.key)
            : cpu.sorted { $0.value > $1.value }.map(\.key)
        return ranked.prefix(limit).map { pid in
            let app = NSRunningApplication(processIdentifier: pid)
            return ProcessUsage(
                id: pid, name: app?.localizedName ?? name(of: pid), cpu: cpu[pid] ?? 0, memory: memory[pid] ?? 0,
                isApp: app != nil
            )
        }
    }

    private static func name(of pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buffer, UInt32(buffer.count))
        let name = String(cString: buffer)
        return name.isEmpty ? "Process \(pid)" : name
    }

    /// Apps are asked to quit; other processes get a terminate signal.
    @MainActor
    static func quit(_ process: ProcessUsage) {
        if let app = NSRunningApplication(processIdentifier: process.id) {
            app.terminate()
        } else {
            kill(process.id, SIGTERM)
        }
        DiagnosticsLog.append("stats", "quit requested for pid \(process.id)")
    }
}
