//
//  OddlineMapManager.swift
//  Disasterkit-Admin
//
//  Created by kiyolab01 on 2018/01/18.
//  Copyright © 2018年 kiyolab01. All rights reserved.
//

import Foundation

//他のクラスから参照されるが、このプロジェクトには不都合なので空クラスを作成
class OfflineMapManager: NSObject{
    static let shared = OfflineMapManager()
    
    override init(){
        super.init()
    }
    
    func addPointers(_ pointers:[Pointer]){
        
    }
}
