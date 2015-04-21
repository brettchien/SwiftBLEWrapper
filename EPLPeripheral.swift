//
//  EPLPeripheral.swift
//  SSBLE
//
//  Created by Ting-Chou Chien on 1/15/15.
//  Copyright (c) 2015 Ting-Chou Chien. All rights reserved.
//

import Foundation
import CoreBluetooth

public struct EPLECGNotifyStruct {
    typealias inputType = Array<UInt8>
    var readings: [Int] = Array(count: 6, repeatedValue: 0)

    init(bytearray: inputType) {
        autoreleasepool {
            for i in 0..<6 {
                var index = i * 3
                var reading: UInt32 = UInt32(bytearray[index]) << 24
                reading += UInt32(bytearray[index + 1]) << 16
                reading += UInt32(bytearray[index + 2]) << 8
                self.readings[i] = Int(Int32( bitPattern: reading) >> 8)
            }
        }
    }
}

public protocol EPLECGNotifyDelegate {
    func didUpdateECGReadings(newReadings: EPLECGNotifyStruct)
}

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
public class EPLPeripheral: NSObject, CBPeripheralDelegate{
    // MARK: -
    // MARK: Subscript
    // MARK: -
    // MARK: Subscript
    subscript(key: String) -> EPLService? {
        get {
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

    // MARK: -
    // MARK: Private variables
    private var advertisementData: [NSObject : AnyObject]!
    private var provideServices: [String : EPLService] = [:]
    private var _rssi: NSNumber = 0
    private var _monitorRSSI: Bool = false
    private var rssiTimer: NSTimer?


    // MARK: -
    // MARK: Internal variables
    internal var cbPeripheral: CBPeripheral!

    // MARK: -
    // MARK: Public variables
    public var delegate: EPLPeripheralDelegate?
    public var ecgDelegate: EPLECGNotifyDelegate?
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
    public init(cbPeripheral: CBPeripheral!, advData: [NSObject : AnyObject]! = nil){
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

    // MARK: -
    // MARK: Delegate Methods
    public func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        if let s = service {
            println("didDiscover Characteristic for service: " + s.UUID.UUIDString)
            let epls = self.provideServices[s.UUID.UUIDString]
            if s.UUID.UUIDString == "57BD6EB5-4543-4732-8628-2788A7BF400F" {
                epls?.dataSource = ECGIIProfile()
            }
            if let chars = epls?.cbService.characteristics {
                for char in chars {
                    let c = EPLCharacteristic(cbCharacteristic: char as! CBCharacteristic)
                    epls?[c.UUID] = c
                    if let ds = epls?.dataSource?.dataSources[c.UUID] {
                        c.dataSource = ds
                    }
                    if let delegate = epls?.dataSource?.delegates[c.UUID] {
                        c.delegate = delegate
                    }

                    if epls?.name == "ECGII" {
                        if c.readable {
                            println(c.name + " readable")
                            self.cbPeripheral.readValueForCharacteristic(c.cbCharacteristic)
                        }
                        if c.notify {
                            self.cbPeripheral.setNotifyValue(true, forCharacteristic: c.cbCharacteristic)
                        }
                    }
                }
            }
        }
    }

    public func peripheral(peripheral: CBPeripheral!, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        if let c = characteristic {
            println("didDiscoverDescriptor for ", c.UUID)
        }

    }

    public func peripheral(peripheral: CBPeripheral!, didDiscoverIncludedServicesForService service: CBService!, error: NSError!) {
        if let s = service {
            println("didDiscoverIncludeServicesFor Service", s.UUID)
        }

    }

    public func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        if let p = peripheral {
            println("didDiscoverServices for " + p.name)
            if let services = p.services {
                for service in services {
                    let cbs = service as! CBService
                    self.provideServices[cbs.UUID.UUIDString] = EPLService(cbService: cbs)
                }
                for (uuid, service) in self.provideServices {
                    self.cbPeripheral.discoverCharacteristics(nil, forService: service.cbService)
                }
                self.cbPeripheral.readRSSI()
            }
        }
    }

    public func peripheral(peripheral: CBPeripheral!, didModifyServices invalidatedServices: [AnyObject]!) {
        if let services = invalidatedServices {
            println("didModifyServices")
        }
    }

    public func peripheral(peripheral: CBPeripheral!, didReadRSSI RSSI: NSNumber!, error: NSError!) {
        if let rssi = RSSI {
            println(String(format: "didReadRSSI: %4.1f", rssi.doubleValue))
            self.RSSI = rssi
        }
    }

    public func peripheral(peripheral: CBPeripheral!, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        if let char = characteristic {
            println("didUpdateNotificationStateForCharacteristic: " + char.UUID.UUIDString)
        }
    }

    public func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        let p = peripheral
        let char = characteristic
        let ep = EPLCentralManager.sharedInstance.connectedPeripherals[p]
        if p != nil && char != nil && ep != nil{
            let char_uuidString = char.UUID.UUIDString
            let serv_uuidString = char.service.UUID.UUIDString
            println("didUpdateValueCharacteristic: " + char_uuidString)
            if let service = self.provideServices[serv_uuidString], let epc = service[char_uuidString] {
                epc.cbCharacteristic = char
                if let delegate = epc.delegate {
                    if epc.isNotifying {
                        epc.delegate?.characteristic(epc, notifyData: char.value)
                    } else {
                        epc.delegate?.characteristic(epc, updateData: char.value)
                    }
                }
            }

        }
    }

    public func peripheral(peripheral: CBPeripheral!, didUpdateValueForDescriptor descriptor: CBDescriptor!, error: NSError!) {
        if let des = descriptor {
            println("didUpdateValueForDescriptor: " + des.UUID.UUIDString)
        }
    }

    public func peripheral(peripheral: CBPeripheral!, didWriteValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        if let char = characteristic {
            println("didWriteValueForCharacteristic: " + char.UUID.UUIDString)
        }
    }

    public func peripheral(peripheral: CBPeripheral!, didWriteValueForDescriptor descriptor: CBDescriptor!, error: NSError!) {
        if let des = descriptor {
            println("didWriteValueForDescriptor: " + des.UUID.UUIDString)
        }
    }

    public func peripheralDidInvalidateServices(peripheral: CBPeripheral!) {
        if let p = peripheral {
            println("didInvalidateServices")
        }
    }

    public func peripheralDidUpdateName(peripheral: CBPeripheral!) {
        if let p = peripheral {
            println("didUpdateName")
        }
    }
}
