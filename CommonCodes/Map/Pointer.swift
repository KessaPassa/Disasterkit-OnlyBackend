//
//  Location.swift
//  Disasterkit-Admin
//
//  Created by kiyolab01 on 2017/12/05.
//  Copyright © 2017年 kiyolab01. All rights reserved.
//

import Foundation

struct Pointer: Codable{
    
    var name: String
    var latitude: Double
    var longitude: Double
    var state: Int
    
    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case state = "State"
    }
    
    init(_ name: String, _ latitude: Double, _ longitude: Double, _ state: Int) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.state = state
    }
}
