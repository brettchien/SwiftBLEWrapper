//
//  EPLCharacteristic.swift
//  
//
//  Created by Ting-Chou Chien on 1/18/15.
//
//

import Foundation
import CoreBluetooth

// MARK: -
// MARK: EPLCharacteristicDelegate Protocol
@objc public protocol EPLCharacteristicDelegate {
    optional func characteristic(characteristic: EPLCharacteristic!, parseData rawData: NSData) -> String

    func characteristic(characteristic: EPLCharacteristic!, notifyData rawData: NSData)

    func characteristic(characteristic: EPLCharacteristic!, updateData rawData: NSData)
}

// MARK: -
// MARK: EPLCharacteristicDataSource Protocol
@objc public protocol EPLCharacteristicDataSource {
    var name: String {get}
}

// MARK: -
// MARK: EPLCharacteristic Class
public class EPLCharacteristic: NSObject {
    // MARK: -
    // MARK: Private variables
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
            if let delegate = self.delegate {
                self.data = self.delegate?.characteristic!(self, parseData: self._cbCharacteristic.value)
            }
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
    
    public var notify: Bool {
        return self._notify
    }
    
    public var indicate: Bool {
        return self._indicate
    }

    public var isNotifying: Bool {
        return self.cbCharacteristic.isNotifying
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
}