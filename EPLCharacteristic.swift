//
//  EPLCharacteristic.swift
//  
//
//  Created by Ting-Chou Chien on 1/18/15.
//
//

import Foundation
import CoreBluetooth
import XCGLogger
import BrightFutures

// MARK: -
// MARK: EPLCharacteristicDelegate Protocol
@objc public protocol EPLCharacteristicDelegate {
    optional func characteristic(characteristic: EPLCharacteristic!, parseData rawData: NSData) -> String

    func characteristic(characteristic: EPLCharacteristic!, notifyData rawData: NSData)

    func characteristic(characteristic: EPLCharacteristic!, updateData rawData: NSData)
}

// MARK: -
// MARK: EPLCharacteristicValueUpdate protocol
@objc public protocol EPLCharacteristicValueUpdate {
    func valueUpdate(newValue: AnyObject)
}

// MARK: -
// MARK: EPLCharacteristicDataSource Protocol
@objc public protocol EPLCharacteristicDataSource {
    var name: String {get}
    optional var bytecount: Int {get}
    optional var valueUpdateReceivers: [EPLCharacteristicValueUpdate] {get set}

    optional func serialize(data: [String : AnyObject]) -> NSData?
    optional func addValueUpdateReceiver(receiver: EPLCharacteristicValueUpdate)
}

// MARK: -
// MARK: EPLCharacteristic Class
public class EPLCharacteristic: NSObject {
    // MARK: -
    // MARK: Private variables
    private var log = XCGLogger.defaultInstance()
    private var _readable:Bool = false
    private var _writable:Bool = false
    private var _notify:Bool = false
    private var _indicate: Bool = false
    private var _cbCharacteristic: CBCharacteristic!

    // MARK: -
    // MARK: Internal variables
    internal var cbCharacteristic: CBCharacteristic! {
        get {
            return self._cbCharacteristic
        }
        set(newValue) {
            self._cbCharacteristic = newValue
        }
    }
    internal var property: CBCharacteristicProperties
    internal var cbService: CBService! {
        if let char = self.cbCharacteristic {
            return char.service
        } else {
            return nil
        }
    }
    internal var cbPeripheral: CBPeripheral! {
        if let char = self.cbCharacteristic {
            return char.service.peripheral
        } else {
            return nil
        }
    }

    internal var characteristicReadPromise = Promise<EPLCharacteristic>()
    internal var characteristicWritePromise = Promise<EPLCharacteristic>()
    
    // MARK: -
    // MARK: Public variables
    public var delegate: EPLCharacteristicDelegate?
    public var dataSource: EPLCharacteristicDataSource?

    public var name: String {
        if let dataSource = self.dataSource {
            return dataSource.name
        }
        return ""
    }

    public var data: String?

    public var rawData: NSData? {
        return self.cbCharacteristic.value
    }
    
    public var readable: Bool {
        return self._readable
    }
    
    public var writable: Bool {
        return self._writable
    }
    
    public var notifiable: Bool {
        return self._notify
    }
    
    public var indicatable: Bool {
        return self._indicate
    }

    public var isNotifying: Bool {
        get {
            return self.cbCharacteristic.isNotifying
        }
        set(enabled) {
            if enabled && !self.cbCharacteristic.isNotifying {
                self.cbPeripheral.setNotifyValue(enabled , forCharacteristic: self.cbCharacteristic)
            }
        }
    }

    public var UUID: String {
        return self.cbCharacteristic.UUID.UUIDString
    }

    public var value: String {
        if let delegate = self.delegate {
            return delegate.characteristic!(self, parseData: self.rawData!)
        }
        return ""
    }
    
    
    // MARK: -
    // MARK: Private Interface
    private func processProperties() {
        if let c = self.cbCharacteristic {
            if (self.property.rawValue & CBCharacteristicProperties.Read.rawValue) > 0 {
                self._readable = true
            }
            if (self.property.rawValue & CBCharacteristicProperties.Write.rawValue) > 0 {
                self._writable = true
            }
            if (self.property.rawValue & CBCharacteristicProperties.Notify.rawValue) > 0 {
                self._notify = true
            }
            if (self.property.rawValue & CBCharacteristicProperties.Indicate.rawValue) > 0 {
                self._indicate = true
            }
        }
    }
    
    // MARK: -
    // MARK: Internal Interface
    
    // MARK: -
    // MARK: Public Interface
    public init(cbCharacteristic: CBCharacteristic) {
        property = cbCharacteristic.properties
        super.init()
        self.cbCharacteristic = cbCharacteristic
        self.property = self.cbCharacteristic.properties
        self.processProperties()
    }

    public func read() -> Future<EPLCharacteristic> {
        self.log.debug(String(format: "Read Characteristic(%@) content", self.name))
        self.cbService.peripheral.readValueForCharacteristic(self.cbCharacteristic)
        return self.characteristicReadPromise.future
    }

    public func write(data: NSData) -> Future<EPLCharacteristic> {
        // length check
        if let length = self.dataSource?.bytecount {
            if data.length > length {
                self.log.error(String(format: "Require length %d but get %d", length, data.length))
            }
        }
        var count = data.length / sizeof(UInt8)
        self.log.debug {
            var content = ""
            if let delegate = self.delegate {
                content = delegate.characteristic!(self, parseData: data)
            } else {
                content = "0x"
                var count = data.length / sizeof(UInt8)
                var array = [UInt8](count: count, repeatedValue: 0)
                data.getBytes(&array, length: count)
                for datum in array {
                    content += String(format: "%02X", datum)
                }
            }
            return String(format: "Write Characteristic(%@) content with %@", self.name, content)
        }
        self.cbService.peripheral.writeValue(data, forCharacteristic: self.cbCharacteristic, type: CBCharacteristicWriteType.WithResponse)

        return self.characteristicWritePromise.future
    }

    public func write(data: [String : AnyObject]) -> Future<EPLCharacteristic> {
        if let dataSource = self.dataSource {
            if let sentData = dataSource.serialize!(data) {
                return self.write(sentData)
            }
            self.characteristicWritePromise.failure(NSError(domain: "Data is not converted", code: 1, userInfo: nil))
        }
        self.characteristicWritePromise.failure(NSError(domain: "DataSource does not exist", code: 2, userInfo: nil))
        return self.characteristicReadPromise.future
    }
}