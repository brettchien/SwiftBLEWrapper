//
//  EPLPeripheralManager.swift
//  BabyECG
//
//  Created by Ting-Chou Chien on 5/5/15.
//  Copyright (c) 2015 Ting-Chou Chien. All rights reserved.
//

import Foundation
import CoreBluetooth
import XCGLogger

// MARK: -
// MARK: EPLPeripheralManager Class
public class EPLPeripheralManager: NSObject, CBPeripheralManagerDelegate {
    // MARK: -
    // MARK: Private variables
    private let log = XCGLogger.defaultInstance()
    private var cbPeripheralManager: CBPeripheralManager? = nil
    private let peripheralQueue = dispatch_queue_create("epl.ble.peripheral.main", DISPATCH_QUEUE_SERIAL)
    private var _ANCSEnabled: Bool = false

    // MARK: -
    // MARK: Internal variables

    // MARK: -
    // MARK: Public variables
    public class var sharedInstance: EPLPeripheralManager {
        struct Static {
            static let instance = EPLPeripheralManager()
        }
        return Static.instance
    }

    // MARK: -
    // MARK: Private Interface

    // MARK: -
    // MARK: Internal Interface

    // MARK: -
    // MARK: Public Interface
    public override init() {
        super.init()
        self.cbPeripheralManager = CBPeripheralManager(delegate: self, queue: self.peripheralQueue)
    }

    public convenience init(ANCSEnabled: Bool) {
        self.init()
        self._ANCSEnabled = ANCSEnabled
    }

}

extension EPLPeripheralManager {
    // MARK: -
    // MARK: Monitoring Changes to the Peripheral Manager's State
    public func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager!) {
        if let cbPeripheralManager = self.cbPeripheralManager {
            switch cbPeripheralManager.state {
            case .Unknown:
                break
            case .Resetting:
                break
            case .Unsupported:
                break
            case .Unauthorized:
                break
            case .PoweredOff:
                break
            case .PoweredOn:
                if self._ANCSEnabled {
                    var advertisement = [
                        CBAdvertisementDataLocalNameKey: UIDevice.currentDevice().name
                    ]
                    self.cbPeripheralManager?.startAdvertising(advertisement)
                }
                break
            }
        }
    }

    public func peripheralManager(peripheral: CBPeripheralManager!, willRestoreState dict: [NSObject : AnyObject]!) {

    }

    // MARK: -
    // MARK: Adding Services
    public func peripheralManager(peripheral: CBPeripheralManager!, didAddService service: CBService!, error: NSError!) {

    }

    // MARK: -
    // MARK: Advertising Peripheral Data
    public func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager!, error: NSError!) {

    }

    // MARK: -
    // MARK: Monitoring Subscriptions to Characteristic Values
    public func peripheralManager(peripheral: CBPeripheralManager!, central: CBCentral!, didSubscribeToCharacteristic characteristic: CBCharacteristic!) {

    }

    public func peripheralManager(peripheral: CBPeripheralManager!, central: CBCentral!, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic!) {

    }

    public func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager!) {

    }

    // MARK: -
    // MARK: Receving Read and Write Requests
    public func peripheralManager(peripheral: CBPeripheralManager!, didReceiveReadRequest request: CBATTRequest!) {

    }

    public func peripheralManager(peripheral: CBPeripheralManager!, didReceiveWriteRequests requests: [AnyObject]!) {

    }
}
