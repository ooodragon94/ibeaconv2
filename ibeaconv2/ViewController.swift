//
//  ViewController.swift
//  ibeaconv2
//
//  Created by TaeIl on 25/12/2018.
//  Copyright © 2018 TaeIl. All rights reserved.
//

import UIKit
import CoreLocation
import CoreBluetooth
import CoreMotion

class ViewController: UIViewController, CLLocationManagerDelegate {

    let serviceUUID = CBUUID(string: "FFE0")
    let characteristicUUID = CBUUID(string: "FFE1")
    var centralManager: CBCentralManager!
    var iBeaconPeripheral: CBPeripheral!
    var iBeaconCharacteristic: CBCharacteristic!
    var CBmanager:CBCentralManager!
    var motion = CMMotionManager()
    
    var distanceData:String = ""
    var beaconSorted:[CLBeacon] = []
    var gyroData:[Double] = [0.0,0.0,0.0]
    var uuid = UUID(uuidString: "")
    var locationManager:CLLocationManager = CLLocationManager()
    var sections = ["gyro",""]
    
    @IBOutlet weak var tableView: UITableView!
    @IBAction func pairAction(_ sender: Any) {
        print("pair button pressed")
        self.centralManager.scanForPeripherals(withServices: [serviceUUID])
        func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
            print(peripheral)
            iBeaconPeripheral = peripheral
            self.centralManager.stopScan()
            self.centralManager.connect(iBeaconPeripheral)
            iBeaconPeripheral.delegate = self
        }
        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            print("connected to device")
            let alert = UIAlertController(title: "iBeacon paired!", message: nil, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Confirm", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            iBeaconPeripheral.discoverServices(nil)
        }
    }
    
    @IBAction func start(_ sender: Any) {
        if uuid == nil {
            self.alertUUID()
        } else {
            rangeBeacons()
        }
        myGyro()
        self.tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        myGyro()
        self.tableView.reloadData()
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        myGyro()
        tableView.dataSource = self
        centralManager = CBCentralManager(delegate: self, queue: nil)
        locationManager.delegate = self
    
        locationManager.requestAlwaysAuthorization()
        
    }
    
    func alertUUID () {
        let alert = UIAlertController(title: "Enter UUID", message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "UUID"
            textField.keyboardType = .default
            self.uuid = UUID(uuidString: textField.text!)
        }
        let action = UIAlertAction(title: "Add", style: .default) { (_) in
            //first textfield input
            let uuid = alert.textFields!.first!.text!
            self.uuid = UUID(uuidString: uuid)
        }
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    func rangeBeacons() {
        if let uuid = self.uuid {
            let region = CLBeaconRegion(proximityUUID: uuid, identifier: "Xcorps")
            locationManager.startRangingBeacons(in: region)
        } else {
            print("beacon not found to the corresponding UUID")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            rangeBeacons()
        }
    }
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
//        guard let discoveredBeaconProximity = beacons.first?.proximity else {print("nothing"); return}
        
        print("beacons : \(beacons)")
        beaconSorted = beacons
        
        //sorting
        for i in 0...beaconSorted.count-1 {
            for j in 0...beaconSorted.count-1 {
                if (Int(truncating: beaconSorted[i].minor) < Int(truncating: beaconSorted[j].minor)) {
                    let temp:CLBeacon = beaconSorted[i]
                    beaconSorted[i] = beaconSorted[j]
                    beaconSorted[j] = temp
                }
            }
        }
        var tempData:String = ""
        for i in 0...gyroData.count-1 {
            tempData.append("\(gyroData[i])#")
        }
        
        for beacon in beaconSorted {
            let formatted = String(format: "%d", beacon.rssi)
            
            //don't send zero
            if formatted != "0" {
                tempData.append("\(formatted)@")
            } else {
                print("zero value detected")
            }
        }
        distanceData = tempData
        
        print("data : \(distanceData)")
        let data = distanceData.data(using: String.Encoding.utf8)!
        if let iBeaconPeripheral = self.iBeaconPeripheral {
            iBeaconPeripheral.writeValue(data, for: iBeaconCharacteristic , type: CBCharacteristicWriteType.withoutResponse)
        } else {
            print("data send failed")
        }
        myGyro()
        self.tableView.reloadData() 
    }
    func myGyro() {
        motion.gyroUpdateInterval = 1
        motion.startGyroUpdates(to: OperationQueue.current!) {
            (gryodata, error) in self.tableView.reloadData() //calls this every gyroupdate
            if let trueData = gryodata {
                self.view.reloadInputViews()
                var x = trueData.rotationRate.x
                x = Double(round(1000*x)/1000)
                var y = trueData.rotationRate.y
                y = Double(round(1000*y)/1000)
                var z = trueData.rotationRate.z
                z = Double(round(1000*z)/1000)
                self.gyroData[0]=x
                self.gyroData[1]=y
                self.gyroData[2]=z
            }
        }
    }
}







//extension for tableview
extension ViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return sections[0]
        }
        if section == 1 {
            if let sectionName = uuid?.uuidString { return sectionName }
        } else {return nil}
        return nil
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return 1 }
        else if section == 1 { return beaconSorted.count }
        else { return 0 }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        
        if indexPath.section == 0 {
            cell.textLabel?.text = "X: \(gyroData[0]), Y: \(gyroData[1]), Z: \(gyroData[2])"
        }
        else if indexPath.section == 1 {
            cell.textLabel?.text = "Major: \(beaconSorted[indexPath.row].major) Minor: \(beaconSorted[indexPath.row].minor)"
            cell.detailTextLabel?.text = "Rssi: \(beaconSorted[indexPath.row].rssi) distance: \(beaconSorted[indexPath.row].accuracy)"
        }
        else {
            return UITableViewCell()
        }
        return cell
    }
}





//extension for bluetooth connection
extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
            let alert = UIAlertController(title: "Bluetooth unsupported", message: "Contact the developer for help", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Confirm", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        case .unauthorized:
            print("central.state is .unauthorized")
            let alert = UIAlertController(title: "Bluetooth unauthorized", message: "Contact the developer for help", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Confirm", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        case .poweredOff:
            print("central.state is .poweredOff")
            //alert "turn bluetooth"
            let alert = UIAlertController(title: "Bluetooth turned off", message: "Turn on device's Bluetooth on system preference", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Confirm", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        case .poweredOn:
            print("central.state is .poweredOn")
            //scan for devices
            centralManager.scanForPeripherals(withServices: [serviceUUID])
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("peripheral: \(peripheral)")
        
        iBeaconPeripheral = peripheral
        iBeaconPeripheral.delegate = self
        centralManager.stopScan()
        centralManager.connect(iBeaconPeripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected to device")
        let alert = UIAlertController(title: "iBeacon paired", message: nil, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Confirm", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
        iBeaconPeripheral.discoverServices(nil)
    }
}
    
extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        for service in services {
            print("services: \(service)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print("characteristic: \(characteristic)")
            iBeaconCharacteristic = characteristic
                        if characteristic.properties.contains(.read) {
                            print("\(characteristic.uuid): properties contains .read")
                        }
            if characteristic.properties.contains(.notify) {
                print("\(characteristic.uuid): properties contains .notify")
                //notified values by ibeacons
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
            
        case characteristicUUID:  //need to know our bluetooth characteristic uuid
            print(characteristic.value ?? "no value")
            iBeaconCharacteristic = characteristic
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
}


