//
//  NetworkMonitor.swift
//  winston
//
//  Created by Zander Bobronnikov on 5/30/25.
//

import Foundation
import Network

@Observable
final class NetworkMonitor {
    private let networkMonitor = NWPathMonitor()
    private let workerQueue = DispatchQueue(label: "Monitor")
    var connectedToWifi = false

  init(start: Bool = true) {
      networkMonitor.pathUpdateHandler = { path in
        self.connectedToWifi = path.usesInterfaceType(.wifi)
      }
      
      if start {
        networkMonitor.start(queue: workerQueue)
      }
    }
}
