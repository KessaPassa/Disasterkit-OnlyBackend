//
//  Protcol.swift
//  BLE-Multihop
//
//  Created by kiyolab01 on 2017/10/27.
//  Copyright © 2017年 kiyolab01. All rights reserved.
//

import Foundation
import CoreBluetooth
import Reachability

//128bitUUIDを分割する指標
enum MessageType: Int{
    case talkId = 0
    case server = 1
    case userId = 2
    case targetId = 3
    case timeStamp = 4
}

//位置情報を受け取った時に分割する指標
enum LocationType: Int{
    case latitude = 0
    case longitude = 1
    case state = 2
    case name = 3
}

//規定を定める構造体
public struct Provision{
    
    //オリジナルメッセージを送信してから受信できるまでの時間(s)
    static let PERMMITION_TIME = 300
    
    //サーバには保存せず、端末に保存しておくデータ
    static var targetId: Int64!
    static var queForSelf: Dictionary<String, String> = [:]
    static var queForAnother: Dictionary<String, String> = [:]
    
    //サーバに到達しているかの合図用32bit ID
    static let notArchivedServer: String = "EFC3"
    static let archivedServer: String = "AD1F"
    
    //targetIdの代わりに使う。位置情報を流す時に無限ループ用 && 位置情報ってことがわかるように
    static let locationInfo: String = "FFFF"
    static var locationInfoToInt64: Int64 = convertHexStringToDecimal(locationInfo)
    
    //128bitのUUIDを作る
    static func connection() -> String{
        let talkId = fetchUUID(UUID().uuidString, type: .talkId)
        let myId = convertDecimalToHexString(PreferenceManager.shared.read()!.id)
        let targetId = convertDecimalToHexString(self.targetId)
        
        let uuid = talkId + "-" + notArchivedServer + "-" + myId + "-" + targetId + "-" + getTimeStamp()
        return uuid
    }
    
    //位置情報を送る専用
    static func connectionForLocation() -> String{
        let talkId = fetchUUID(UUID().uuidString, type: .talkId)
        let myId = self.locationInfo
        let targetId = self.locationInfo
        
        let uuid = talkId + "-" + notArchivedServer + "-" + myId + "-" + targetId + "-" + getTimeStamp()
        return uuid
    }
    
    //サーバに保存されたか調べる
    static func checkArchivedServer(_ uuid: String) -> Bool{
        let serverId = fetchUUID(uuid, type: .server)
        
        switch serverId {
        case notArchivedServer:
            return false
        
        case archivedServer:
            return true
            
        default:
            return false
        }
    }
    
    //サーバに到達済みにuuidを書き換えて上書き
    static func swapServerId(_ uuid: String) -> String{
        let talkId = fetchUUID(uuid, type: .talkId)
        let userId = fetchUUID(uuid, type: .userId)
        let targetId = fetchUUID(uuid, type: .targetId)
        let timeStamp = fetchUUID(uuid, type: .timeStamp)
        
        let newUuid = talkId + "-" + archivedServer + "-" + userId + "-" + targetId + "-" + timeStamp
        return newUuid
    }
    
    //128bitUUIDは 8桁-4桁-4桁-4桁-12桁 になっているのため「-」で分割する
    private static func uuidSplit( _ uuid: String) -> [String]{
        let split: [String] = uuid.components(separatedBy: "-")
        return split
    }
    
    //4桁のStringになるように変換する. 16進数なので"%04X"になる
    private static func convertDecimalToHexString(_ id: Int64) -> String{
        let id = String.init(format: "%04X", id)
        return id
    }
    
    //16進数Stringから10進数Int64に変換
    static func convertHexStringToDecimal(_ str: String) -> Int64{
        return Int64(str, radix: 16)!
    }
    
    //Typeで欲しいUUIDを取得
    static func fetchUUID(_ uuid: String, type: MessageType) -> String{
        let split: [String] = uuidSplit(uuid)

        return split[type.rawValue]
    }
    
    //自分の知っている人が居れば、Nameを返す
    static func matchingFriend(_ uuid: String) -> String?{
        let targetId = convertHexStringToDecimal(fetchUUID(uuid, type: .userId))
        
        let friends = try! UserManager.shared.read()
        for friend in friends{
            if  friend.id == targetId{
                return (friend.name)
            }
        }
        
        return nil
    }
    
    //現在の時間を取得
    static func getTimeStamp(interval: Int = 0) -> String {
        let formatter = DateFormatter()
        //formatter.locale = NSLocale.init(localeIdentifier: "ja_JP")
        
        formatter.dateFormat = "yyyyMMddHHmm"
        let now = Date.init(timeIntervalSinceNow: TimeInterval(interval))
        return formatter.string(from: now)
    }
    
    //キューに保持しておく制限時間を決め、それを過ぎたらtrueを返す
    static func isTimeOver(uuid: String) -> Bool{
        let timeStamp = fetchUUID(uuid, type: .timeStamp)
        if timeStamp <= getTimeStamp(interval: -PERMMITION_TIME){
            return true
        }
        else{
            return false
        }
    }
    
    private static func locationSplit( _ uuid: String) -> [String]{
        let split: [String] = uuid.components(separatedBy: "§")
        return split
    }
    
    static func fetchLocation(_ uuid: String, type: LocationType) -> Any{
        let split: [String] = locationSplit(uuid)
        
        if type == .latitude || type == .longitude{
            return Double(split[type.rawValue])!
        }
        else if type == .state{
            return Int(split[type.rawValue])!
        }
        else{
            return split[type.rawValue]
        }
    }
    
    //ネットワークに繋がって居るかどうか
    static func isNetworkConnecting() -> Bool{
        let reachability = Reachability()!
        if reachability.connection != .none {
            return true
        }
        else{
            return false
        }
    }
}
