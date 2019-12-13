//
//  DBManager.swift
//  Disasterkit-Admin
//
//  Created by kiyolab01 on 2017/11/23.
//  Copyright © 2017年 kiyolab01. All rights reserved.
//

import Foundation
import FirebaseDatabase
import SwiftyJSON

class DBManager {
    
    static var ref: DatabaseReference!
    static let notification = NotificationCenter.default
    static var fetchedData: Dictionary<String, Any>? = nil
    
    static private func initialize() -> Bool{
        if !Provision.isNetworkConnecting(){
            print("ネットワークに繋がっていません")
            return false
        }
        else{
            self.ref = Database.database().reference()
            return true
        }
    }
    
    /**********送信系**********/
    static func pushUser(user: User, email: String = ""){
        if !initialize(){
            return
        }
        let ref = Database.database().reference()
        let folderRef = ref.child("users").child("\(user.id)")
        let newFolder: Dictionary<String, Any> = ["id": user.id, "name": user.name, "email": email]
        folderRef.updateChildValues(newFolder)
    }
    
    static func pushFriends(_ friends: [User]){
        if !initialize(){
            return
        }
        let myId = PreferenceManager.shared.read()!.id
        let folderRef = self.ref.child("friends").child("\(myId)")
        for friend in friends {
            let dic: Dictionary<String,Any> = [
                "id": friend.id,
                "name": friend.name
            ]
            let newFolder = ["\(friend.id)": dic]
            folderRef.updateChildValues(newFolder)
        }
    }
    
    static func pushMessage(que: Dictionary<String, String>){
        if !initialize(){
            return
        }
        for child in que{
                let swaped = Provision.swapServerId(child.key)
                let userId = Provision.fetchUUID(swaped, type: .userId)
                
                let folderRef = self.ref.child("messages").child("\(userId)")
                let dic: Dictionary<String,Any> = [
                    "uuid": swaped,
                    "message": child.value
            ]
            let newFolder = [swaped: dic]
            folderRef.updateChildValues(newFolder)
        }
    }
    
    static func pushLocation(_ pointer: Pointer){
        if !initialize(){
            return
        }
        let folderRef = self.ref.child("location").child("\(pointer.name)")
        let newFolder: Dictionary<String, Any> = ["name": pointer.name, "latitude": pointer.latitude, "longitude": pointer.longitude, "state": pointer.state, "date": Provision.getTimeStamp()]
        folderRef.updateChildValues(newFolder)
    }
    
    /**********End**********/
    
    /**********受信系**********/
    static func generateNonDuplicateId(){
        if !initialize(){
            return
        }
        self.ref.child("users").observeSingleEvent(of: .value, with: { snapshot in
            let json = JSON(snapshot.value!)
            
            var ids:[Int64] = []
            for child in json.dictionaryValue.values{
                ids.append(child["id"].rawValue as! Int64)
            }
            
            //重複しないIDが出るまで無限ループ
            while(true){
                let tmp = Int64(arc4random_uniform(65534))
                if !ids.contains(tmp){
                    fetchedData = ["id": tmp]
                    NotificationCenter.default.post(name: callbackDuplicateId, object: nil)
                    break
                }
            }
        }){ error  in
            print("\(error)")
        }
    }
    
    static func fetchUser(email: String){
        if !initialize(){
            return
        }
        self.ref.child("users").observeSingleEvent(of: .value, with: { snapshot in
            let json = JSON(snapshot.value!)
            for child in json.arrayValue{
                if child["email"].stringValue == email, let userId: Int64 = child["id"].rawValue as! Int64, let userName: String = child["name"].stringValue{
                    self.fetchedData = ["id": userId, "name": userName]
                    self.notification.post(name: callbackGetDatabase, object: nil)
                }
            }
        }){ error  in
            print("\(error)")
        }
    }
    
    static func fetchFriends(){
        if !initialize(){
            return
        }
        self.ref.child("friends").observeSingleEvent(of: .value, with: { snapshot in
            let json = JSON(snapshot.value!)
            for child in json.arrayValue{
                if let friendId: Int64 = child["id"].int64Value , let friendName: String = child["name"].stringValue{
                    self.notification.post(name: callbackGetDatabase, object: nil)
                    //json形式のDictionary
                    let dic: Dictionary<String,Any> = [
                        "id": friendId,
                        "name": friendName
                    ]
//                    Provision.friends[friendId] = dic
                }
            }
        }){ error  in
            print("\(error)")
        }
    }
    
    static func fetchMessages(){
        if !initialize(){
            return
        }
        self.ref.child("messages").observeSingleEvent(of: .value, with: { snapshot in
            let json = JSON(snapshot.value!)
            for users in json.dictionaryValue{
                for child in users.value.dictionaryValue{
                    if let uuid: String = child.value["uuid"].stringValue, let message: String = child.value["message"].stringValue, !Provision.isTimeOver(uuid: uuid){
                        Provision.queForAnother[uuid] = message
                        AdhocManager.shared.switchResult(from: uuid, message: message)
                    }
                }
            }
        }){ error  in
            print("\(error)")
        }
    }
    
    static func fetchLocation(){
        if !initialize(){
            return
        }
        self.ref.child("location").observeSingleEvent(of: .value, with: { snapshot in
            let json = JSON(snapshot.value!)
            for child in json.dictionaryValue.values{
                if let name: String = child["name"].stringValue, let latitude: Double = child["latitude"].doubleValue, let longitude: Double = child["longitude"].doubleValue,
                    let state: Int = child["state"].intValue, let timeStamp: String = child["date"].stringValue{
                    print("緯度: \(latitude), 経度: \(longitude), 混雑状態: \(state), 避難地名: \(name)")
                    //json形式のDictionary
                    let dic: Dictionary<String,Any> = [
                        "name": name,
                        "latitude": latitude,
                        "longitude": longitude,
                        "state": state,
                        "date": timeStamp
                    ]
//                    Provision.locations[HavingData.locations.count] = dic
                }
            }
        }){ error  in
            print("\(error)")
        }
    }
    /**********End**********/
}
