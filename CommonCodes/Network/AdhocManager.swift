//
//  AdhocManager.swift
//  Multihop
//
//  Created by kiyolab01 on 2017/11/21.
//  Copyright © 2017年 kiyolab01. All rights reserved.
//

import Foundation

//P2PとBLEからアクセスする共通コード
class AdhocManager {
    
    static let shared = AdhocManager()
    var showDelegate: ShowDelegate!
    var timerDelegate: TimerDelegate!
    
    init(){
        P2PManager.shared.start()
        BLEManager.shared.start()
    }
    
    func start(){
        timerDelegate.startAdhoc()
    }
    
    func stop(){
        timerDelegate.stopAdhoc()
    }
    
    func update(){
        BLEManager.shared.reloadConnection()
        P2PManager.shared.broadcastMessage()
    }
    
    func sendMessage(from: String, message: String){
        P2PManager.shared.sendMessage(from, message)
        BLEManager.shared.sendMessage(from, message)
    }
    
    func switchResult(from: String, message: String){
        let myId = PreferenceManager.shared.read()!.id
        let userId = Provision.convertHexStringToDecimal(Provision.fetchUUID(from, type: .userId))
        let targetId = Provision.convertHexStringToDecimal(Provision.fetchUUID(from, type: .targetId))
        print(message)
        //位置情報だったら
        if targetId == Provision.locationInfoToInt64 && Provision.queForSelf[from] == nil{
            let latitude = Provision.fetchLocation(message, type: .latitude) as! Double
            let longitude = Provision.fetchLocation(message, type: .longitude) as! Double
            let state = Provision.fetchLocation(message, type: .state) as! Int
            let name = Provision.fetchLocation(message, type: .name) as! String
            let pointer = Pointer.init(name, latitude, longitude, state)
            
            Provision.queForSelf[from] = message
            Provision.queForAnother[from] = message
            print("緯度: \(latitude), 経度: \(longitude), 混雑状態: \(state), 避難地名: \(name)")
            OfflineMapManager.shared.addPointers([pointer])
        }
            //自分が送ったメッセージなら
        else if myId == userId{
            //何もしない
        }
//            //サーバを経由していないなら
//        else if !Provision.checkArchivedServer(from){
//            Provision.queForAnother[from] = message
//        }
            //targetIDが自分なら
        else if myId == targetId && Provision.queForSelf[from] == nil{
            let friendName = Provision.matchingFriend(from) ?? "ID: \(userId.description)"
            
            // MARK: -
            let user = User(friendName, userId)
            try? MessageLogManager.receive(
                message: Message(user, message)
            )
            
            // FIXME: TEST
            NotificationCenter.default.post(
                name: callbackMessageUpdate , object: nil
            )
            
            Provision.queForSelf[from] = message
            showDelegate.pushNotification(from: friendName, message: message)
        }
            //自分宛のメッセージでないなら
        else{
            print("送信先では有りません")
            //キューにメッセージを入れる
            Provision.queForAnother[from] = message
        }
    }
}
