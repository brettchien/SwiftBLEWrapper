//
//  EPLPeripheral.swift
//  SSBLE
//
//  Created by Ting-Chou Chien on 1/15/15.
//  Copyright (c) 2015 Ting-Chou Chien. All rights reserved.
//

import Foundation
import CoreBluetooth
import XCGLogger
import BrightFutures

// MARK: -
// MARK: EPLPeripheralDelegate Protocol
@objc public protocol EPLPeripheralDelegate {
    
    optional func didUpdateName()
    optional func didUpdateRSSI(newRSSI: NSNumber)
}

// MARK: -
// MARK: override operators
func == (left: EPLPeripheral , right: EPLPeripheral) -> Bool{
    return left.identifier == right.identifier
}

func != (left: EPLPeripheral , right: EPLPeripheral) -> Bool{
    return left.identifier != right.identifier
}

// MARK: -
// MARK: EPLPeripheralDelegate Classs
public class EPLPeripheral: NSObject, SequenceType, CBPeripheralDelegate{
    // MARK: -
    // MARK: Subscript
    subscript(key: String) -> EPLService? {
        get {
            // lazy discovery
            if self.provideServices.count == 0 {
                self.discoverServices()
            }
            
            if let service = self.provideServices[key] {
                return service
            } else {
                for (UUID, service) in self.provideServices {
                    if let dataSource = service.dataSource {
                        if key == dataSource.name {
                            return service
                        }
                    }
                }
            }
            return nil
        }
        
        set(newService){
            if let char = self.provideServices[key] {
                return
            } else {
                self.provideServices[key] = newService
            }
        }
    }
    
    // Generator function, used for 'for-in' statement
    public func generate() -> AnyGenerator<EPLService> {
        let values = Array(self.provideServices.values)
        var idx = 0
        return anyGenerator {
            if idx < values.count {
                return values[idx++]
            }
            return nil
        }
    }
    
    // MARK: -
    // MARK: Private variables
    private var log = XCGLogger.defaultInstance()
    private var advertisementData: [NSObject : AnyObject]!
    private var provideServices: [String : EPLService] = [:]
    private var _rssi: NSNumber = 0
    private var _monitorRSSI: Bool = false
    private var rssiTimer: NSTimer?
    
    // Promises
    private var serviceDiscoveredPromise = Promise<String, NSError>()
    private var rssiUpdatedPromise = Promise<NSNumber, NSError>()
    
    // MARK: -
    // MARK: Internal variables
    internal var cbPeripheral: CBPeripheral!
    
    // MARK: -
    // MARK: Public variables
    public var delegate: EPLPeripheralDelegate?
    public var identifier: NSUUID! {
        get {
            if let p = self.cbPeripheral {
                return p.identifier
            }
            return nil
        }
    }
    
    public var RSSI: NSNumber {
        get {
            return self._rssi
        }
        set {
            self._rssi = newValue
            self.delegate?.didUpdateRSSI!(self._rssi)
        }
    }
    
    public var monitorRSSI: Bool {
        get {
            return self._monitorRSSI
        }
        set {
            if self._monitorRSSI == false {
                if newValue != self._monitorRSSI {
                    self.rssiTimer = NSTimer(timeInterval: 1.0, target: self, selector: Selector("rssiTimerFunc"), userInfo: nil, repeats: true)
                }
            } else {
                // monitor RSSI ongoing
                if newValue != self.monitorRSSI {
                    if let timer = self.rssiTimer {
                        timer.invalidate()
                    }
                }
            }
            self._monitorRSSI = newValue
        }
    }
    
    public var name: String! {
        get {
            if let p = self.cbPeripheral {
                return p.name
            }
            return nil
        }
    }
    
    public var services: [EPLService]! {
        get {
            if self.provideServices.count > 0 {
                return Array(self.provideServices.values)
            }
            return nil
        }
    }
    
    // MARK: -
    // MARK: Private interfaces
    private func rssiTimerFunc() {
        if let p = self.cbPeripheral {
            p.readRSSI()
        }
    }
    
    // MARK: -
    // MARK: Internal interfaces
    
    // MARK: -
    // MARK: Public interfaces
    public init(cbPeripheral: CBPeripheral, advData: [NSObject : AnyObject]! = nil){
        super.init()
        self.cbPeripheral = cbPeripheral
        self.cbPeripheral.delegate = self
        if let adv = advData {
            self.advertisementData = advData
        }
    }
    
    public func findServiceByCharacteristicUUID(uuid: String) -> EPLService! {
        for (key, service) in self.provideServices {
            if let char = service[uuid] {
                return service
            }
        }
        return nil
    }
    
    public func discoverServices() -> Future<String, NSError> {
        self.log.debug("Discover services")
        print(self.cbPeripheral)
        self.cbPeripheral.discoverServices(nil)
        
        return self.serviceDiscoveredPromise.future
    }
    
    public func readRSSI() -> Future<NSNumber, NSError> {
        self.log.debug("Read RSSI")
        self.cbPeripheral.readRSSI()
        
        return self.rssiUpdatedPromise.future
    }
}

extension EPLPeripheral {
    
    // MARK: -
    // MARK: CBPeripheral Delegates
    
    // MARK: -
    // MARK: Discovering Services
    public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        let p = peripheral
        self.log.debug("didDiscoverServfices for \(p.name)")
        let services = p.services
        for service in (services)! {
            let cbs = service
            let epls = EPLService(cbService: cbs)
            self.provideServices[cbs.UUID.UUIDString] = epls
            self.log.debug(epls.UUID)
        }
        do {
            try self.serviceDiscoveredPromise.success("discoverServicesSuccess")
        } catch {
            
        }
    }
    
    public func peripheral(peripheral: CBPeripheral, didDiscoverIncludedServicesForService service: CBService, error: NSError?) {
        let s = service
        self.log.info("didDiscoverIncludeServicesFor Service \(s.UUID.UUIDString)")
    }
    
    // MARK: -
    // MARK: Discovering Characteristics and Characteristic Descriptors
    public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        let s = service
        self.log.debug("didDiscover Characteristics for service: \(s.UUID.UUIDString)")
        let epls = self.provideServices[s.UUID.UUIDString]
        if let chars = epls?.cbService.characteristics {
            for char in chars {
                let c = EPLCharacteristic(cbCharacteristic: char)
                epls?[c.UUID] = c
            }
            do {
                try epls?.characteristicDiscoveredPromise.success("didDiscoverCharacteristics")
            } catch {
                
            }
        }
    }
    
    public func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        let c = characteristic
        self.log.info("didDiscoverDescriptor for \(c.UUID.UUIDString)")
    }
    
    // MARK: -
    // MARK: Retrieving Characteristic and Characteristic Descriptor Values
    public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        let p = peripheral
        let char = characteristic
        let ep = EPLCentralManager.sharedInstance.connectedPeripherals[p]
        let char_uuidString = char.UUID.UUIDString
        let serv_uuidString = char.service.UUID.UUIDString
        if let service = self.provideServices[serv_uuidString], let epc = service[char_uuidString] {
            epc.cbCharacteristic = char
            if let datasource = epc.dataSource {
                self.log.debug("didUpdateValueCharacteristic: \(epc.name)")
            } else {
                self.log.debug("didUpdateValueCharacteristic: \(char_uuidString)")
            }
            if let delegate = epc.delegate {
                epc.data = delegate.characteristic!(epc, parseData: char.value!)
                if epc.isNotifying {
                    delegate.characteristic(epc, notifyData: char.value!)
                } else {
                    delegate.characteristic(epc, updateData: char.value!)
                    do {
                        try epc.characteristicReadPromise.success(epc)
                    } catch {
                        
                    }
                }
            }
        }
    }
    
    public func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        let des = descriptor
        self.log.info("didUpdateValueForDescriptor: \(des.UUID.UUIDString)")
    }
    
    // MARK: -
    // MARK: Writing Characteristic and Characteristic Descriptor Values
    public func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        let char = characteristic
        self.log.info("didWriteValueForCharacteristic: \(char.UUID.UUIDString)")
    }
    
    public func peripheral(peripheral: CBPeripheral, didWriteValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        let des = descriptor
        self.log.info("didWriteValueForDescriptor: \(des.UUID.UUIDString)")
    }
    
    // MARK: -
    // MARK: Managing Notifications for a Characteristic's Value
    public func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        let p = peripheral
        let char = characteristic
        let ep = EPLCentralManager.sharedInstance.connectedPeripherals[p]
        let char_uuidString = char.UUID.UUIDString
        let serv_uuidString = char.service.UUID.UUIDString
        if let service = self.provideServices[serv_uuidString], let epc = service[char_uuidString] {
            epc.cbCharacteristic = char
            var msg = "didUpdateNotificationStateForCharacteristic: "
            if let datasource = epc.dataSource {
                msg += epc.name
            } else {
                msg += char_uuidString
            }
            self.log.debug(msg)
        }
    }
    
    // MARK: -
    // MARK: (Depercated) Retrieving a Peripheral's Received Signal Strength Indicator (RSSI) Data
    //    public func peripheral(peripheral: CBPeripheral!, didReadRSSI RSSI: NSNumber!, error: NSError!) {
    //        if let rssi = RSSI {
    //            println(String(format: "didReadRSSI: %4.1f", rssi.doubleValue))
    //            self.RSSI = rssi
    //
    //            self.rssiUpdatedPromise.success(self.RSSI)
    //        }
    //    }
    
    // Mark: -
    // Mark: Monitoring Changes to a Peripheral's Name or Services
    public func peripheralDidUpdateName(peripheral: CBPeripheral) {
        self.log.info("didUpdateName \(peripheral.name)")
    }
    
    public func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        self.log.info("didModifyServices")
    }
}
