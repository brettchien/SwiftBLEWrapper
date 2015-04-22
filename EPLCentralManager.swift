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
import Async

// MARK: -
// MARK: EPLCentralManagerDelegate Protocol
@objc public protocol EPLCentralManagerDelegate {
    // required functions
    func afterBLEIsReady(central: EPLCentralManager!)
    func didDiscoverPeripherals(central: EPLCentralManager!)
    func didConnectedPeripheral(peripheral: EPLPeripheral!)
    
    // optional functions
    optional func afterScanTimeout(central: EPLCentralManager!)
}

// MARK: -
// MARK: EPLCentralManager Class
public class EPLCentralManager: NSObject, CBCentralManagerDelegate {
    // MARK: -
    // MARK: Private variables
    private let log = XCGLogger.defaultInstance()
    private var cbCentralManager: CBCentralManager?
    private let centralQueue = dispatch_queue_create("epl.ble.central.main", DISPATCH_QUEUE_SERIAL)
    private var _ble_ready: Bool = false
    private var scanOption:Dictionary<String, AnyObject> = [:]

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
    
    
    public func scan(timeout: Double = 10.0, allowDuplicated: Bool = false) {
        self.log.debug("Start Scanning for peripherals")
        self.scanOption[CBCentralManagerScanOptionAllowDuplicatesKey] = allowDuplicated
        self.scanOption[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] = []
        self.cbCentralManager!.scanForPeripheralsWithServices(nil, options: self.scanOption)

        // insert a background delay then rise a timeout event
        Async.main(after: timeout) {
            self.log.debug("Scan Timeout")
            self.stopScan()
            self.delegate?.afterScanTimeout!(self)
        }
    }
    
    public func stopScan() {
        log.debug("Stop scanning")
        self.cbCentralManager!.stopScan()
    }

    public func connect(peripheral: EPLPeripheral, options: [NSObject: AnyObject]! = nil) {
        var msg = "Connect to " + peripheral.name
        log.debug(msg)
        self.cbCentralManager?.connectPeripheral(peripheral.cbPeripheral, options: options)
    }
    
    // MARK: -
    // MARK: CBCentralManagerDelegate Methods
    public func centralManagerDidUpdateState(central: CBCentralManager!) {
        self.ble_ready = false
        switch self.cbCentralManager!.state {
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
        default:
            break
        }
    }
    
    public func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        log.debug("didConnect")
        if let p = peripheral {
            var ep = EPLPeripheral(cbPeripheral: p)
            self.discoveredPeripherals.removeValueForKey(p)
            self.connectedPeripherals[p] = ep
            ep.cbPeripheral.discoverServices(nil)
            self.delegate?.didConnectedPeripheral(ep)
        }
    }
    
    public func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        log.debug("disconnect")
        if let p = peripheral {
            var ep = EPLPeripheral(cbPeripheral: p)
            self.connectedPeripherals.removeValueForKey(p)
        }
    }
    
    public func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        if let p = peripheral {
            var ep = EPLPeripheral(cbPeripheral: p, advData: advertisementData)
            self.discoveredPeripherals[p] = ep
            log.debug(String(format: "didDiscover %@ (RSSI: %4.1f)", p.name, RSSI))
            self.delegate?.didDiscoverPeripherals(self)
        }
    }
    
    public func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        log.debug("didFailToConnectPeripheral")
        if let p = peripheral {
            var ep = EPLPeripheral(cbPeripheral: p)
            self.discoveredPeripherals.removeValueForKey(p)
            self.connectedPeripherals.removeValueForKey(p)
        }
    }
    
    public func centralManager(central: CBCentralManager!, didRetrieveConnectedPeripherals peripherals: [AnyObject]!) {
        log.debug("didRetrieveConnected")
        if let ps = peripherals {
            for p in ps {
                let p = p as! CBPeripheral
                var ep = EPLPeripheral(cbPeripheral: p)
                self.connectedPeripherals[p] = ep
            }
        }
    }
    
    public func centralManager(central: CBCentralManager!, didRetrievePeripherals peripherals: [AnyObject]!) {
        println("didRetrieve")
        if let ps = peripherals {
            for p in ps {
                let p = p as! CBPeripheral
                var ep = EPLPeripheral(cbPeripheral: p)
                self.discoveredPeripherals[p] = ep
            }
        }
    }
    
    public func centralManager(central: CBCentralManager!, willRestoreState dict: [NSObject : AnyObject]!) {
        println("wilRestore")
    }
}