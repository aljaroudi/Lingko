//
//  ConnectivityService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import Network
import os.log

@MainActor
@Observable
final class ConnectivityService {
    private let logger = Logger(subsystem: "com.lingko.app", category: "Connectivity")
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.lingko.connectivity")

    var isConnected: Bool = true
    var connectionType: ConnectionType = .wifi

    init() {
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                self.isConnected = path.status == .satisfied

                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else {
                    self.connectionType = .unknown
                }

                self.logger.info("📡 Network status changed - Connected: \(self.isConnected), Type: \(self.connectionType.rawValue)")
            }
        }

        monitor.start(queue: queue)
        logger.info("📡 Network monitoring started")
    }


    var statusDescription: String {
        guard isConnected else {
            return "No connection"
        }

        switch connectionType {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "Connected"
        }
    }
}

enum ConnectionType: String {
    case wifi = "Wi-Fi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case unknown = "Unknown"
}
