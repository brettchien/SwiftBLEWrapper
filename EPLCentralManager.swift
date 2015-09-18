//
//  EPLCentralManager.swift
//  SSBLE
//
//  Created by Ting-Chou Chien on 1/15/15.
//  Copyright (c) 2015 Ting-Chou Chien. All rights reserved.
//

import Foundation
import CoreBluetooth
import XCGLogger
//import Async

// MARK: -
// MARK: EPLCentralManagerDelegate Protocol
@objc public protocol EPLCentralManagerDelegate {
    // required functions
    func afterBLEIsReady(central: EPLCentralManager!)
    func didDiscoverPeripherals(central: EPLCentralManager!)
    func didConnectedPeripheral(peripheral: EPLPeripheral!)
    func didDisconnectedPeripheral(peripheral: EPLPeripheral!)
    
    // optional functions
    optional func afterScanTimeout(central: EPLCentralManager!)
}

// MARK: -
// MARK: EPLCentralManager Class
public class EPLCentralManager: NSObject, CBCentralManagerDelegate {
    // MARK: -
    // MARK: Private variables
    private let log = XCGLogger.defaultInstance()
    private var cbCentralManager: CBCentralManager
    private let centralQueue = dispatch_queue_create("epl.ble.central.main", DISPATCH_QUEUE_SERIAL)
    private var _ble_ready: Bool = false
    private var scanOption:Dictionary<String, AnyObject> = [:]
    private var block = Async.background {}
    
    // MARK: -
    // MARK: Internal variables
    
    // MARK: -
    // MARK: Public variables
    // singleton, there's only one EPLCentralManager for the whole system
    public class var sharedInstance: EPLCentralManager {
        struct Static {
            static let instance = EPLCentralManager()
        }
        return Static.instance
    }
    
    public var ble_ready: Bool {
        get {
            return self._ble_ready
        }
        set {
            self._ble_ready = newValue
            if self._ble_ready == true {
                delegate?.afterBLEIsReady(self)
            }
        }
    }
    
    public var delegate: EPLCentralManagerDelegate?
    public var connectedPeripherals: [CBPeripheral :EPLPeripheral] = [:]
    public var discoveredPeripherals: [CBPeripheral : EPLPeripheral] = [:]
    
    // MARK: -
    // MARK: Private Interface
    
    // MARK: -
    // MARK: Internal Interface
    
    // MARK: -
    // MARK: Public Interface
    public override init() {
        cbCentralManager = CBCentralManager()
        super.init()
        self.cbCentralManager =  CBCentralManager(delegate: self, queue: self.centralQueue)
    }
    
    public func reset() {
        self.cbCentralManager = CBCentralManager(delegate: self, queue: self.centralQueue)
    }
    
    
    public func scan(timeout: Double = 10.0, allowDuplicated: Bool = false) {
        self.log.debug("Start Scanning for peripherals")
        // insert a background delay then rise a timeout event
        self.block = Async.background(after: timeout) {
            self.log.debug("Scan Timeout")
            self.stopScan()
            self.delegate?.afterScanTimeout!(self)
        }
        
        self.scanOption[CBCentralManagerScanOptionAllowDuplicatesKey] = allowDuplicated
        self.scanOption[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] = []
        self.cbCentralManager.scanForPeripheralsWithServices(nil, options: self.scanOption)
    }
    
    public func stopScan() {
        self.log.debug("Stop scanning")
        self.cbCentralManager.stopScan()
    }
    
    public func connect(peripheral: EPLPeripheral, options: [String: AnyObject]! = nil) {
        self.log.debug("Connect to \(peripheral.name)")
        self.cbCentralManager.connectPeripheral(peripheral.cbPeripheral, options: options)
    }
    
    public func disconnect(peripheral: EPLPeripheral) {
        self.log.debug("Disconnect with \(peripheral.name)")
        self.cbCentralManager.cancelPeripheralConnection(peripheral.cbPeripheral)
    }
}

extension EPLCentralManager {
    // MARK: -
    // MARK: Monitoring Connections with Peripherals
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        self.log.debug("didConnect")
        Async.main {
            print(peripheral)
            let ep = EPLPeripheral(cbPeripheral: peripheral)
            self.discoveredPeripherals.removeValueForKey(peripheral)
            self.connectedPeripherals[peripheral] = ep
            if let d = self.delegate {
                d.didConnectedPeripheral(ep)
            }
        }
    }
    
    public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        if let err = error {
            self.log.error("Disconnect with Error: \(err)")
        }
        let p = peripheral
        let ep = EPLPeripheral(cbPeripheral: p)
        self.connectedPeripherals.removeValueForKey(p)
        self.delegate?.didDisconnectedPeripheral(ep)
    }
    
    public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.log.error("didFailToConnectPeripheral")
        let p = peripheral
            var ep = EPLPeripheral(cbPeripheral: p)
            self.discoveredPeripherals.removeValueForKey(p)
            self.connectedPeripherals.removeValueForKey(p)
    }
    
    // MARK: -
    // MARK: Discovering and Retrieving Peripherals
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        let rssi = RSSI
        var ep = EPLPeripheral(cbPeripheral: peripheral, advData: advertisementData)
        self.discoveredPeripherals[peripheral] = ep
        self.log.debug("didDiscover \(peripheral)")
        self.delegate?.didDiscoverPeripherals(self)
    }
    
    
    // MARK: -
    // MARK: Monitoring Changes to the Central Manager's State
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        self.ble_ready = false
        self.cbCentralManager = central
        switch self.cbCentralManager.state {
        case .Unauthorized:
            break
        case .Unknown:
            break
        case .Unsupported:
            break
        case .PoweredOff:
            break
        case .PoweredOn:
            self.ble_ready = true
        case .Resetting:
            break
        }
    }
    
    public func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
    }
    
    
    
// deprecated
//    public func centralManager(central: CBCentralManager!, didRetrieveConnectedPeripherals peripherals: [AnyObject]!) {
//        self.log.debug("didRetrieveConnected")
//        if let ps = peripherals {
//            for p in ps {
//                let p = p as! CBPeripheral
//                var ep = EPLPeripheral(cbPeripheral: p)
//                self.connectedPeripherals[p] = ep
//            }
//        }
//    }
//    
//    public func centralManager(central: CBCentralManager!, didRetrievePeripherals peripherals: [AnyObject]!) {
//        print("didRetrieve")
//        if let ps = peripherals {
//            for p in ps {
//                let p = p as! CBPeripheral
//                var ep = EPLPeripheral(cbPeripheral: p)
//                self.discoveredPeripherals[p] = ep
//            }
//        }
//    }
}
