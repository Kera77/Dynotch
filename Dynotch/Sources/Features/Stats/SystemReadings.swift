import Darwin
import Foundation
import IOKit
import IOKit.ps

/// Raw counters read from the system (spec SY-1…SY-5); rates come from two readings.
enum SystemReadings {
    struct CPUTicks: Equatable, Sendable {
        var busy: UInt64
        var total: UInt64
    }

    static func cpuTicks() -> CPUTicks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        let user = UInt64(info.cpu_ticks.0), system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2), nice = UInt64(info.cpu_ticks.3)
        return CPUTicks(busy: user + system + nice, total: user + system + idle + nice)
    }

    /// Share of the CPU used between two readings, 0…1.
    nonisolated static func cpuLoad(from old: CPUTicks, to new: CPUTicks) -> Double {
        guard new.total > old.total, new.busy >= old.busy else { return 0 }
        return min(Double(new.busy - old.busy) / Double(new.total - old.total), 1)
    }

    struct Memory: Equatable, Sendable {
        /// Bytes, like Activity Monitor's "Memory Used": app memory, wired and compressed.
        var used: UInt64
        var total: UInt64
        var swapUsed: UInt64
        /// 1 normal, 2 warning, 4 critical (the kernel's memory pressure level).
        var pressure: Int
    }

    static func memory() -> Memory? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        let page = UInt64(getpagesize())
        let app = UInt64(stats.internal_page_count) - min(UInt64(stats.purgeable_count), UInt64(stats.internal_page_count))
        let used = (app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapUsed = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 ? swap.xsu_used : 0
        var level: Int32 = 1
        var levelSize = MemoryLayout<Int32>.size
        _ = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &levelSize, nil, 0)
        return Memory(used: used, total: ProcessInfo.processInfo.physicalMemory, swapUsed: swapUsed, pressure: Int(level))
    }

    struct Network: Equatable, Sendable {
        var received: UInt64
        var sent: UInt64
        /// The Mac's own IPv4 address on Wi-Fi or Ethernet.
        var address: String?
    }

    /// Wi-Fi and Ethernet only (en*): VPN tunnels would count the same traffic twice.
    static func network() -> Network {
        var result = Network(received: 0, sent: 0, address: nil)
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let first else { return result }
        defer { freeifaddrs(first) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            let name = String(cString: entry.ifa_name)
            guard name.hasPrefix("en"), let address = entry.ifa_addr else { continue }
            if address.pointee.sa_family == UInt8(AF_LINK), let data = entry.ifa_data {
                let counters = data.assumingMemoryBound(to: if_data.self).pointee
                result.received += UInt64(counters.ifi_ibytes)
                result.sent += UInt64(counters.ifi_obytes)
            } else if address.pointee.sa_family == UInt8(AF_INET), result.address == nil {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    result.address = String(cString: host)
                }
            }
        }
        return result
    }

    /// Bytes per second between two counters; the 32-bit interface counters wrap around.
    nonisolated static func rate(from old: UInt64, to new: UInt64, seconds: Double) -> Double {
        guard seconds > 0 else { return 0 }
        let delta = new >= old ? new - old : new &+ (UInt64(UInt32.max) + 1) &- old
        return Double(delta) / seconds
    }

    struct Disk: Equatable, Sendable {
        var free: Int64
        var total: Int64
        var read: UInt64
        var written: UInt64
    }

    static func disk() -> Disk {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys)
        var disk = Disk(
            free: values?.volumeAvailableCapacityForImportantUsage ?? 0, total: Int64(values?.volumeTotalCapacity ?? 0),
            read: 0, written: 0
        )
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS
        else { return disk }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            let statistics = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any]
            disk.read += (statistics?["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            disk.written += (statistics?["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
        }
        return disk
    }
}
