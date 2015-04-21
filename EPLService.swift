//
//  EPLService.swift
//
//
//  Created by Ting-Chou Chien on 1/18/15.
//
//

import Foundation
import CoreBluetooth

// MARK: -
// MARK: EPLServiceDelegate Protocol
//@objc public protocol EPLServiceDelegate {
//
//}

// MARK: -
// MARK: EPLServiceDataSource Protocol
@objc public protocol EPLServiceDataSource {
    var UUID: String {get}
    var name: String {get}
    var dataSources: [String: EPLCharacteristicDataSource] {get}
    var delegates: [String: EPLCharacteristicDelegate] {get set}
}

// MARK: -
// MARK: EPLService Class
public class EPLService: Printable {
    // MARK: -
    // MARK: Subscript
    subscript(key: String) -> EPLCharacteristic? {
        get {
            if let char = self.characteristics[key] {
                return char
            } else {
                for (UUID, service) in self.characteristics {
                    if let dataSource = service.dataSource {
                        if key == dataSource.name {
                            return service
                        }
                    }
                }
            }
            return nil
        }

        set(newCharacteristic){
            if let char = self.characteristics[key] {
                return
            } else {
                self.characteristics[key] = newCharacteristic
            }
        }
    }

    // MARK: -
    // MARK: Private variables



    // MARK: -
    // MARK: Internal variables
    internal var cbService: CBService!
    internal var cbPeripheral: CBPeripheral! {
        return self.cbService!.peripheral
    }

    // MARK: -
    // MARK: Public variables
    public var dataSource: EPLServiceDataSource?

    public var name: String {
        get {
            if let dataSource = self.dataSource {
                return dataSource.name
            }
            return ""
        }
    }
    public var keys: [String] {
        get {
            var result = ["1", "2"]
            if let ds = self.dataSource {
            }
            return result
        }
    }
    public var characteristics: [String : EPLCharacteristic] = [:]
    public var UUID: CBUUID! {
        return self.cbService.UUID
    }
    public var isPrimary: Bool! {
        return self.cbService.isPrimary
    }
    public var description: String {
        if let s = self.cbService {
            var ret = "<EPLService: 0x" + String(format: "%X", self.cbService.hashValue)
            ret += ", isPrinmary = "
            ret = self.isPrimary! ? ret + "YES": ret + "NO"
            ret += ", UUID ="
            if let uuid = self.UUID {
                ret += self.UUID.UUIDString
            } else {
                ret += "(null)"
            }
            ret += ">"
            return ret
        }
        return ""
    }

    // MARK: -
    // MARK: Private Interface

    // MARK: -
    // MARK: Internal Interface

    // MARK: -
    // MARK: Public Interface
    public init(cbService: CBService) {
        self.cbService = cbService
    }
}