//
//  BLEManager.swift
//  Multihop
//
//  Created by kiyolab01 on 2017/10/19.
//  Copyright © 2017年 kiyolab01. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

class BLEManager: NSObject{
    
    static let shared = BLEManager()
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    var peripheralManager: CBPeripheralManager!
    var showDelegate: ShowDelegate!
    var isConnecting = false
    
    //Disaster kitを使っているという合図用128bit UUID
    let DISASTER_KIT = CBUUID.init(string: "0C3E79DC-0F7E-4101-AB7F-9662CC5236FF")
    
    /**********ここに外部からアクセスされる**********/
    override init(){
        super.init()
        
        let centralOptions = [
            CBCentralManagerOptionShowPowerAlertKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ]
        let peripheralOptions = [CBPeripheralManagerOptionShowPowerAlertKey: true]
        self.centralManager = CBCentralManager.init(delegate: self, queue: nil, options: centralOptions)
        self.peripheralManager = CBPeripheralManager.init(delegate: self, queue: nil, options: peripheralOptions)
    }
    
    //ここにアクセスすると開始
    public func start(){
        startAdvertise()
        startScan()
    }
    
    //ここにアクセスすると終了
    public func stop(){
        stopAdvertise()
        stopScan()
        cancelConnection()
    }
    
    //メッセージ送信
    public func sendMessage(_ from: String, _ message: String) {
        if self.peripheral == nil {
            print("BLE接続できていません")
            return
        }
        
        Provision.queForAnother[from] = message
        broadcastMessage()
    }
    
    public func reloadConnection(){
        stop()
        start()
    }
    /**********End**********/
    
    
    //所持して居る、自分以外のメッセージも送信する
    func broadcastMessage(){
        if Provision.queForAnother.isEmpty == false{
            //ここで削除しないと重複してメモリが溢れる
            self.peripheralManager.removeAllServices()
            
            for que in Provision.queForAnother{
                //保持時間を過ぎていたら削除する
                if Provision.isTimeOver(uuid: que.key){
                    print("BLEで時間が過ぎたので削除しました: \(que)")
                    Provision.queForAnother[que.key] = nil
                    Provision.queForAnother.removeValue(forKey: que.key)
                }
                else{
                    let characteristic = mutableCharacteristic(uuid: CBUUID.init(string: que.key))
                    let service = CBMutableService.init(type: DISASTER_KIT, primary: true)
                    service.characteristics = [characteristic]
                    self.peripheralManager.add(service)
                    characteristic.value = convertStringToData(word: que.value)
                    self.peripheral.readValue(for: characteristic)
                }
            }
        }
    }
    
    //以下便利関数
    /**********キャラクタリスティックのvalueコンバーター**********/
    private func convertUInt8ToData(value: UInt8) -> Data{
        var value = value
        let data: Data = NSData(bytes: &value, length: 1) as Data!
        
        return data
    }
    
    private func convertDataToUInt8(data: Data?) -> UInt8{
        guard var data: Data = data else{
            print(#function)
            return 0
        }
        
        var bytes = [UInt8].init(repeating: 0, count: data.count)
        data.copyBytes(to: &bytes, count: data.count)
        
        if bytes.count != 0 {
            return bytes[0]
        }
        else{
            print(#function)
            return 0
        }
    }
    
    private func convertStringToData(word: String?)-> Data{
        guard let word = word else{
            print(#function)
            return Data.init(count: 0)
        }
        
        let data: Data = word.data(using: String.Encoding.utf8)!
        return data
    }
    
    private func convertDataToString(data: Data?) -> String{
        guard let data: Data = data, let word = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String! else{
            print(#function)
            return ""
        }
        
        return word
    }
    /**********END**********/
    
    
    /**********キャラクタリスティック初期作成**********/
    private func properties() -> CBCharacteristicProperties {
        return [.write, .read]
    }
    
    private func permissions() -> CBAttributePermissions {
        return [.writeable, .readable]
    }
    
    private func mutableCharacteristic(uuid: CBUUID) -> CBMutableCharacteristic {
        return CBMutableCharacteristic(
            type: uuid,
            properties: properties(),
            value: nil,
            permissions: permissions()
        )
    }
    /**********END**********/
}

//Bluetooth関係
extension BLEManager: CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate{
    
    //  接続状況が変わるたびに呼ばれる
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var message = "centralState: "
        
        switch central.state {
        case .poweredOff:
            message += "電源OFF"
            showDelegate.showAlert()
        case .poweredOn:
            message += "電源ON"
        case .resetting:
            message += "レスティング状態"
        case .unauthorized:
            message += "非認証状態"
        case .unknown:
            message += "不明"
        case .unsupported:
            message += "非対応"
        }
        
        print(message)
    }
    
    //  ペリフェラルのStatusが変化した時に呼ばれる
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        var message = "peripheralState: "
        
        switch peripheral.state {
        case .poweredOff:
            message += "電源OFF"
        case .poweredOn:
            message += "電源ON"
        case .resetting:
            message += "レスティング状態"
        case .unsupported:
            message += "非認証状態"
        case .unknown:
            message += "不明"
        case .unauthorized:
            message += "非対応"
        }
        
        print(message)
    }
    
    /************アドバタイズ関連************/
    func startAdvertise() {
        let advertisementData: Dictionary<String, Any> = [CBAdvertisementDataServiceUUIDsKey: [DISASTER_KIT]]
        self.peripheralManager.startAdvertising(advertisementData)
    }
    
    func stopAdvertise(){
        self.peripheralManager.stopAdvertising()
    }
    
    //  アドバタイズ開始処理の結果を取得
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if error != nil {
            print("***Advertising ERROR")
            return
        }
        print("Advertising success")
    }
    
    /************スキャン関連************/
    
    //  スキャン開始
    func startScan() {
        self.centralManager.scanForPeripherals(withServices: [DISASTER_KIT], options: nil)
    }
    
    //スキャン停止
    func stopScan(){
        self.centralManager.stopScan()
    }
    
    //スキャンキャンセル
    func cancelConnection(){
        if self.peripheral != nil{
            self.centralManager.cancelPeripheralConnection(self.peripheral)
        }
    }
    
    //  接続成功時に呼ばれる
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connect success!")
        
        broadcastMessage()
        //サービス探索開始
        self.peripheral.discoverServices(nil)
    }
    
    //  接続失敗時に呼ばれる
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Connect failed...")
    }
    
    //  スキャン結果を取得
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Peripheral: \(peripheral)")
        self.peripheral = peripheral
        self.peripheral.delegate = self
        self.centralManager.connect(self.peripheral, options: nil)
        isConnecting = false
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService], function: String = #function) {
        print("didModigfyServices: \(function)")
        //        broadcastMessage()
        peripheral.discoverServices(nil)
    }
    
    //  サービス追加結果の取得
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if error != nil {
            print("Service Add Failed...")
            return
        }
        print("Service Add Sucsess!")
    }
    
    //アドバタイズを行い、セントラルから接続されるとReadリクエストがここに来る
    //良く分からないけど、このメソッドがないと送ったメッセージがnilになる
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        //CBMutableCharacteristicのvalueをCBATTRequestのvaueにセット
        request.value = request.characteristic.value
        
        //リクエストに応答
        self.peripheralManager.respond(
            to: request,
            withResult: CBATTError.success
        )
    }
    
    //  service検索結果取得
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else{
            print("error: service取得失敗")
            return
        }
        print("\(services.count)個のサービスを発見。")
        
        //  サービスを見つけたらすぐにキャラクタリスティックを取得
        for obj: CBService in services {
            //Disaster kitを使っているならば
            if DISASTER_KIT == obj.uuid{
                isConnecting = true
                
                //キャラクタリスティック探索開始
                //talk_idがランダム生成なのでnilにしないと通らない
                peripheral.discoverCharacteristics(nil, for: obj)
            }
        }
        
        if !isConnecting{
            print("メッセージを持っていません")
        }
    }
    
    //  キャラクタリスティック発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics: [CBCharacteristic] = service.characteristics {
            print("\(characteristics.count)個のキャラクタリスティック")
            
            for obj in characteristics{
                if let characteristic = obj as CBCharacteristic!{
                    //Rread専用のキャラクタリスティックに限定して読み出す
                    if characteristic.properties.rawValue & CBCharacteristicProperties.read.rawValue != 0{
                        print("read")
                        peripheral.readValue(for: characteristic)
                    }
                }
            }
        }
    }
    
    //データ読み出し結果を取得する
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let word = convertDataToString(data: characteristic.value)
        let from = characteristic.uuid.uuidString
        AdhocManager.shared.switchResult(from: from, message: word)
    }
}


