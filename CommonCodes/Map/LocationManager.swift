//
//  LocationManager.swift
//  Disasterkit-Admin
//
//  Created by kiyolab01 on 2017/11/19.
//  Copyright © 2017年 kiyolab01. All rights reserved.
//

import Foundation
import CoreLocation

struct LocationData{
    
    static var latitude: Double? = nil
    static var longitude: Double? = nil
}

//位置情報を扱う
class LocationManager: NSObject, CLLocationManagerDelegate {
    
    static let shared = LocationManager()
    var locationManager: CLLocationManager!
    
    //初期化
    override init() {
        super.init()
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        guard self.locationManager != nil else {
            print("失敗")
            return
        }
        
        self.locationManager.requestWhenInUseAuthorization()
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedWhenInUse {
            self.locationManager.distanceFilter = 5
            self.locationManager.startUpdatingLocation()
        }
    }
    
    public func start(){
//            self.locationManager.requestLocation()
    }
    
    // requestLocation()を使用する場合、失敗した際のDelegateメソッドの実装が必須
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置情報の取得に失敗しました")
    }
    
    
    //ステートが変化したら
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            print("ユーザーはこのアプリケーションに関してまだ選択を行っていません")
            // 許可を求めるコードを記述する（後述）
            break
        case .denied:
            print("ローケーションサービスの設定が「無効」になっています (ユーザーによって、明示的に拒否されています）")
            // 「設定 > プライバシー > 位置情報サービス で、位置情報サービスの利用を許可して下さい」を表示する
            break
        case .restricted:
            print("このアプリケーションは位置情報サービスを使用できません(ユーザによって拒否されたわけではありません)")
            // 「このアプリは、位置情報を取得できないために、正常に動作できません」を表示する
            break
        case .authorizedAlways:
            print("常時、位置情報の取得が許可されています。")
            // 位置情報取得の開始処理
            break
        case .authorizedWhenInUse:
            print("起動時のみ、位置情報の取得が許可されています。")
            // 位置情報取得の開始処理
            break
        }
    }
    
    //位置情報が更新するたびに
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let location = locations.first
        LocationData.latitude = Double(String.init(format: "%.15f", (location!.coordinate.latitude)))
        LocationData.longitude = Double(String.init(format: "%.15f", (location!.coordinate.longitude)))
        
        print("latitude: \(LocationData.latitude!) : longitude: \(LocationData.longitude!)")
    }
    
    //DateをStringに変換
    func convertDateToString(timeStamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter.string(from: timeStamp)
    }
}
