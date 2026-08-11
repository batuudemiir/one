//
//  NetworkMonitor.swift
//  one
//
//  Basit ağ durum takipçisi — offline banner için sinyal.
//  NWPathMonitor tabanlı, singleton @Published `isOnline`.
//
//  Not: @MainActor DEĞİL — NWPathMonitor kendi queue'sunda çağırıyor, handler
//  içinde main'e sıçrıyoruz. @MainActor + arka plan queue + singleton üçlüsü
//  bazen "invalid reuse after initialization failure" veriyor.
//

import Foundation
import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOnline: Bool = true

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "one.network", qos: .utility)

    private init() {
        self.monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self else { return }
                if self.isOnline != online {
                    self.isOnline = online
                }
            }
        }
        monitor.start(queue: queue)
    }

    // Singleton — deinit çağrılmaz normalde. Yine de güvenli tarafta kalalım.
    deinit { monitor.cancel() }
}
