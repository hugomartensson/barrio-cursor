import Foundation
import Network

/// Strip scope/zone ID from host (e.g. "172.20.10.10%bridge100" → "172.20.10.10") so URLs are valid.
private func hostForURL(_ host: String) -> String {
    if let percent = host.firstIndex(of: "%") {
        return String(host[..<percent])
    }
    return host
}

/// Thread-safe one-shot flag for ensuring a continuation resumes exactly once.
private final class OnceFlag: @unchecked Sendable {
    private var _done = false
    private let lock = NSLock()
    
    /// Returns `true` the first time it's called; `false` thereafter.
    func trySet() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _done { return false }
        _done = true
        return true
    }
    
    var isDone: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _done
    }
}

actor NetworkDiscoveryService {
    static let shared = NetworkDiscoveryService()
    
    private let userDefaults = UserDefaults.standard
    private let savedIPKey = "barrio_server_ip"
    private let savedPortKey = "barrio_server_port"
    
    private init() {}
    
    // MARK: - Public API (fully automatic discovery — no manual server entry)
    
    func getAPIBaseURL() async -> String {
        #if DEBUG
        #if targetEnvironment(simulator)
        print("📡 NetworkDiscovery: Running in SIMULATOR")
        #else
        print("📡 NetworkDiscovery: Running on DEVICE")
        #endif
        #endif
        
        // 1. Try saved IP (instant if still valid). On device, never use saved 127.0.0.1.
        #if !targetEnvironment(simulator)
        if getSavedIP() == "127.0.0.1" {
            #if DEBUG
            print("📡 NetworkDiscovery: Ignoring saved 127.0.0.1 on device (use discovered Mac IP)")
            #endif
            clearSavedIP()
        }
        #endif
        if let savedIPRaw = getSavedIP(), let savedPort = getSavedPort() {
            let savedIP = hostForURL(savedIPRaw)
            let url = "http://\(savedIP):\(savedPort)/api"
            #if DEBUG
            print("📡 NetworkDiscovery: Trying saved IP \(savedIP):\(savedPort)")
            #endif
            if await testConnection(url: url) {
                #if DEBUG
                print("✅ NetworkDiscovery: Using saved IP")
                #endif
                return url
            }
            #if DEBUG
            print("⚠️ NetworkDiscovery: Saved IP no longer works, clearing")
            #endif
            clearSavedIP()
        }
        
        // 2. Simulator: try localhost
        #if targetEnvironment(simulator)
        let localhostURL = "http://127.0.0.1:3000/api"
        #if DEBUG
        print("📡 NetworkDiscovery: Trying simulator localhost")
        #endif
        if await testConnection(url: localhostURL) {
            #if DEBUG
            print("✅ NetworkDiscovery: Using localhost (simulator)")
            #endif
            saveIP("127.0.0.1", port: 3000)
            return localhostURL
        }
        #endif
        
        // 3. Bonjour/mDNS discovery (sub-second on local network)
        #if DEBUG
        print("📡 NetworkDiscovery: Step 3 - Bonjour discovery")
        #endif
        if let bonjourURL = await discoverViaBonjour() {
            #if DEBUG
            print("✅ NetworkDiscovery: Found server via Bonjour")
            #endif
            return bonjourURL
        }
        #if DEBUG
        print("📡 NetworkDiscovery: Bonjour discovery did not find server")
        #endif
        
        // 4. Parallel subnet scan (device's own subnet first)
        #if DEBUG
        print("📡 NetworkDiscovery: Step 4 - Parallel subnet scan")
        #endif
        if let scannedURL = await parallelSubnetScan() {
            #if DEBUG
            print("✅ NetworkDiscovery: Found server via subnet scan")
            #endif
            return scannedURL
        }
        #if DEBUG
        print("📡 NetworkDiscovery: Subnet scan found nothing")
        #endif
        
        // 5. On device: try common "Mac on iPhone hotspot" IPs before giving up
        #if !targetEnvironment(simulator)
        let hotspotCandidates = ["172.20.10.2", "172.20.10.3", "172.20.10.4"]
        for ip in hotspotCandidates {
            let url = "http://\(ip):3000/api"
            #if DEBUG
            print("📡 NetworkDiscovery: Trying common hotspot IP \(ip)")
            #endif
            if await testConnection(url: url) {
                #if DEBUG
                print("✅ NetworkDiscovery: Using \(ip) (Mac on iPhone hotspot)")
                #endif
                saveIP(ip, port: 3000)
                return url
            }
        }
        #if DEBUG
        print("⚠️ NetworkDiscovery: All discovery failed on device")
        print("   → Connect Mac to this iPhone's hotspot, start server on Mac, ensure Mac firewall allows port 3000")
        #endif
        #endif
        
        // Simulator or last resort: localhost
        return "http://127.0.0.1:3000/api"
    }
    
    // MARK: - Bonjour Discovery
    
    private func discoverViaBonjour() async -> String? {
        await withCheckedContinuation { continuation in
            let once = OnceFlag()
            let browser = NWBrowser(for: .bonjour(type: "_barrioapi._tcp", domain: nil), using: .tcp)
            
            let timeoutWork = DispatchWorkItem { [weak browser] in
                guard once.trySet() else { return }
                browser?.cancel()
                #if DEBUG
                print("   [Bonjour] Timeout after 3s")
                #endif
                continuation.resume(returning: nil)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: timeoutWork)
            
            browser.browseResultsChangedHandler = { [weak browser] results, _ in
                guard !once.isDone else { return }
                for result in results {
                    if case .service(let name, let type, let domain, _) = result.endpoint {
                        #if DEBUG
                        print("   [Bonjour] Found: \(name) (\(type) in \(domain))")
                        #endif
                    }
                    let connection = NWConnection(to: result.endpoint, using: .tcp)
                    connection.stateUpdateHandler = { state in
                        guard !once.isDone else { connection.cancel(); return }
                        switch state {
                        case .ready:
                            if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                               case .hostPort(let host, let port) = innerEndpoint {
                                let ip: String
                                switch host {
                                case .ipv4(let addr):
                                    ip = "\(addr)"
                                case .ipv6(let addr):
                                    let str = "\(addr)"
                                    if str.hasPrefix("::ffff:") {
                                        ip = String(str.dropFirst(7))
                                    } else {
                                        ip = str
                                    }
                                default:
                                    ip = "\(host)"
                                }
                                let portNum = Int(port.rawValue)
                                let cleanIP = hostForURL(ip)
                                #if DEBUG
                                print("   [Bonjour] Resolved: \(cleanIP):\(portNum)")
                                #endif
                                guard once.trySet() else { connection.cancel(); return }
                                timeoutWork.cancel()
                                browser?.cancel()
                                connection.cancel()
                                Task {
                                    await self.saveIP(cleanIP, port: portNum)
                                }
                                continuation.resume(returning: "http://\(cleanIP):\(portNum)/api")
                            }
                        case .failed, .cancelled:
                            connection.cancel()
                        default:
                            break
                        }
                    }
                    connection.start(queue: .global())
                    return
                }
            }
            
            browser.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    guard once.trySet() else { return }
                    #if DEBUG
                    print("   [Bonjour] Browser failed: \(error)")
                    #endif
                    timeoutWork.cancel()
                    continuation.resume(returning: nil)
                }
            }
            
            browser.start(queue: .global())
        }
    }
    
    // MARK: - Parallel Subnet Scan
    
    private func parallelSubnetScan() async -> String? {
        let port = 3000
        
        // Get the device's subnet first — most likely to contain the Mac
        var subnetsToScan: [String] = []
        if let deviceSubnet = getDeviceSubnet() {
            #if DEBUG
            print("   Device subnet: \(deviceSubnet)")
            #endif
            subnetsToScan.append(deviceSubnet)
        }
        // Add common subnets as fallback (skip duplicates)
        for s in ["192.168.1", "192.168.0", "172.20.10", "10.0.0"] {
            if !subnetsToScan.contains(s) { subnetsToScan.append(s) }
        }
        
        for subnet in subnetsToScan {
            #if DEBUG
            print("   Scanning \(subnet).x in parallel...")
            #endif
            // Generate all candidate IPs (1-254)
            let candidates = (1...254).map { "\(subnet).\($0)" }
            
            // Scan in parallel batches of 30 to avoid socket exhaustion
            let batchSize = 30
            for batchStart in stride(from: 0, to: candidates.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, candidates.count)
                let batch = Array(candidates[batchStart..<batchEnd])
                
                let found: String? = await withTaskGroup(of: String?.self, returning: String?.self) { group in
                    for ip in batch {
                        group.addTask {
                            let url = "http://\(ip):\(port)/api"
                            let ok = await self.testConnection(url: url, timeout: 1.5)
                            return ok ? url : nil
                        }
                    }
                    for await result in group {
                        if let url = result {
                            group.cancelAll()
                            return url
                        }
                    }
                    return nil
                }
                
                if let url = found {
                    if let parsed = URL(string: url), let host = parsed.host {
                        saveIP(hostForURL(host), port: port)
                    }
                    return url
                }
            }
        }
        return nil
    }
    
    // MARK: - Device Subnet Detection
    
    private func getDeviceSubnet() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var candidate: (subnet: String, priority: Int)?
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            guard let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            
            let name = String(cString: interface.ifa_name)
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: hostname)
            
            let parts = ip.split(separator: ".")
            guard parts.count == 4, !ip.hasPrefix("127."), !ip.hasPrefix("169.254.") else { continue }
            let subnet = parts[0...2].joined(separator: ".")
            
            // Prefer WiFi (en0) > hotspot bridge > cellular > other
            let priority: Int
            switch name {
            case "en0": priority = 10
            case _ where name.hasPrefix("bridge") || name.hasPrefix("ap"): priority = 8
            case _ where name.hasPrefix("pdp_ip"): priority = 5
            case _ where name.hasPrefix("utun"): priority = 2
            default: priority = 1
            }
            
            if candidate == nil || priority > candidate!.priority {
                candidate = (subnet, priority)
                #if DEBUG
                print("   [Subnet] \(name): \(ip) → subnet \(subnet) (priority \(priority))")
                #endif
            }
        }
        return candidate?.subnet
    }
    
    // MARK: - Connection Test
    
    private func testConnection(url: String, timeout: TimeInterval = 2.0) async -> Bool {
        guard let testURL = URL(string: "\(url)/health") else { return false }
        
        do {
            var request = URLRequest(url: testURL)
            request.timeoutInterval = timeout
            request.httpMethod = "GET"
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Persistence
    
    func saveIP(_ ip: String, port: Int) {
        let cleaned = hostForURL(ip)
        userDefaults.set(cleaned, forKey: savedIPKey)
        userDefaults.set(port, forKey: savedPortKey)
        #if DEBUG
        print("💾 NetworkDiscovery: Saved \(cleaned):\(port)")
        #endif
    }
    
    func getSavedIPForEdit() -> String? { userDefaults.string(forKey: savedIPKey) }
    func getSavedPortForEdit() -> Int? {
        let p = userDefaults.integer(forKey: savedPortKey)
        return p > 0 ? p : nil
    }
    
    private func getSavedIP() -> String? { userDefaults.string(forKey: savedIPKey) }
    private func getSavedPort() -> Int? {
        let p = userDefaults.integer(forKey: savedPortKey)
        return p > 0 ? p : nil
    }
    
    func getSavedServerAddress() -> String? {
        guard let ip = getSavedIP(), let port = getSavedPort() else { return nil }
        return "\(hostForURL(ip)):\(port)"
    }
    
    func clearSavedIP() {
        userDefaults.removeObject(forKey: savedIPKey)
        userDefaults.removeObject(forKey: savedPortKey)
    }
}

struct NetworkInfo: Codable {
    let serverIPs: [String]
    let localhostIPs: [String]
    let port: Int
    let baseURL: String
    let suggestedURLs: [String]
}
