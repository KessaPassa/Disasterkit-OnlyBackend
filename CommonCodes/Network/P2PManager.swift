//
//  ConnectionManager.swift
//  PeerKitTest
//
//  Created by kiyolab01 on 2017/09/29.
//  Copyright © 2017年 kiyolab01. All rights reserved.
//

import Foundation
import PeerKit
import MultipeerConnectivity

enum Event: String{
    case Message = "Message"
}

class P2PManager{
    
    static let shared = P2PManager()
    
    var peers: [MCPeerID]{
        return PeerKit.session?.connectedPeers as [MCPeerID]? ?? []
    }
    
    private init(){
        
    }
    
    public func onEvent(event: Event, run: ObjectBlock?) {
        if let run = run {
            PeerKit.eventBlocks[event.rawValue] = run
        } else {
            PeerKit.eventBlocks.removeValue(forKey: event.rawValue)
        }
    }
    
    public func connection(){
        onConnect { user, target in
            print("P2P接続\n \(target)")
        }
        
        onDisconnect { user, target in
            print("P2P切断\n \(target)")
        }
        
        onEvent(event: .Message) { [unowned self] _, obj in
            self.receiveMassage(object: obj)
        }
    }
    
    public func disConnection(){
        onConnect(run: nil)
        onDisconnect(run: nil)
    }
    
    public func receiveMassage(object: AnyObject?) {
        guard let data = object else {
            return
        }
        if let message = data["message"] as? String, let from = data["from"] as? String{
            AdhocManager.shared.switchResult(from: from, message: message)
        }
    }
    
    public func sendMessage(_ from: String, _ message: String){
        Provision.queForAnother[from] = message
        broadcastMessage()
    }
    
    //所持して居る、自分以外のメッセージも送信する
    public func broadcastMessage() {
        if Provision.queForAnother.isEmpty == false{
            for que in Provision.queForAnother{
                //保持時間を過ぎていたら削除する
                if Provision.isTimeOver(uuid: que.key){
                    print("P2Pで時間が過ぎたので削除しました: \(que)")
                    Provision.queForAnother[que.key] = nil
                    Provision.queForAnother.removeValue(forKey: que.key)
                }
                else{
                    sendMessageEvent(message: que.value, from: que.key)
                }
            }
        }
    }
    
    private func sendMessageEvent(message: String, from: String = PeerKit.myName, toPeera peers: [MCPeerID]? = PeerKit.session?.connectedPeers as [MCPeerID]?){
        let anyObject = ["message": message, "from": from]
        PeerKit.sendEvent(Event.Message.rawValue, object: anyObject as AnyObject, toPeers: peers)
    }
    
    public func start(){
        //serviceTypeは1~15文字以内 && 頭文字は小文字アルファベットでなければならない
        //serviceTypeは接続元と接続先が同じでなけれ通信できない
        PeerKit.transceive(serviceType: "disaster-kit")
    }
    
    public func stop(){
        PeerKit.stopTransceiving()
    }
    
    public func onConnect(run: PeerBlock?){
        PeerKit.onConnect = run
    }
    
    public func onDisconnect(run: PeerBlock?){
        PeerKit.onDisconnect = run
    }
}

