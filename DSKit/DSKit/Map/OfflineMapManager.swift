//
//  OfflineMapManager.swift
//  Disasterkit-Admin
//
//  Created by kiyolab01 on 2018/01/12.
//  Copyright © 2018年 kiyolab01. All rights reserved.
//

import Foundation
import ArcGIS
import SVProgressHUD

class OfflineMapManager: NSObject{
    
    public var mapView: AGSMapView!
    private var graphicsOverlay = AGSGraphicsOverlay()
    static let shared = OfflineMapManager()
    var onlineLabel: UILabel!
    
    let ERROR_RANGE = 5.0
    let ICON_SIZE: CGFloat = 50
    
    override init(){
        super.init()
    }
    
    func initView(frame: CGRect){
        mapView = AGSMapView.init(frame: frame)
        mapView.isAttributionTextVisible = false
        mapView.touchDelegate = self
        setNowLocation()
        
        let downloadButton = UIButton.init(frame: CGRect.init(
            x: mapView.frame.width - (ICON_SIZE + 10), y: mapView.frame.height - 180, width: ICON_SIZE, height: ICON_SIZE))
        downloadButton.setImage(#imageLiteral(resourceName: "Download.png"), for: .normal)
        downloadButton.addTarget(EvacuationMapViewController(), action: #selector(EvacuationMapViewController.addDownloadButton), for: .touchUpInside)
        mapView.addSubview(downloadButton)
        
        let nowLocationButton = UIButton.init(frame: CGRect.init(
            x: mapView.frame.width - (ICON_SIZE + 10), y: mapView.frame.height - 120, width: ICON_SIZE, height: ICON_SIZE))
        nowLocationButton.setImage(#imageLiteral(resourceName: "NowLocation.png"), for: .normal)
        nowLocationButton.addTarget(self, action: #selector(setNowLocation), for: .touchUpInside)
        mapView.addSubview(nowLocationButton)
        
        onlineLabel = UILabel.init(frame: CGRect.init(x: 0, y: 60, width: mapView.frame.width, height: 60))
        onlineLabel.textAlignment = .center
        onlineLabel.numberOfLines = 0
        onlineLabel.backgroundColor = UIColor.init(white:0.7, alpha:0.6)
        onlineLabel.text  = "この地図はオフラインマップではありません\nボタンを押してダウンロードしてください"
        mapView.addSubview(onlineLabel)
    }
    
    //オフラインマップを表示する
    func addMap(url: String?){
        //ファイルが存在するなら
        if let path = url, FileManager.default.fileExists(atPath: path) {
            let localTiledLayer = AGSArcGISTiledLayer(tileCache: AGSTileCache(fileURL: URL.init(fileURLWithPath: path)))
            let map = AGSMap(basemap: AGSBasemap(baseLayer: localTiledLayer))
            mapView.map = map
            onlineLabel.isHidden = true
        }
        //オフラインマップが見つからない場合はオンラインマップを表示
        else {
            if url != nil{
                SVProgressHUD.showError(withStatus: "その地図は持っていません")
            }
            let map = AGSMap(basemap: AGSBasemap.streets())
            mapView.map = map
            onlineLabel.isHidden = false
        }
    }
    
    //ポインターを表示する
    func addPointers(_ pointers:[Pointer]){
        guard mapView != nil else{
            return
        }
        for pointer in pointers {
            if isApplyingRange(pointer){
                let point = AGSPoint.init(clLocationCoordinate2D:
                    CLLocationCoordinate2D.init(latitude: pointer.latitude, longitude: pointer.longitude))
                let color = convertIntToColor(pointer.state)
                let symbol = AGSPictureMarkerSymbol.init(image: color)
                let graphic = AGSGraphic(geometry: point, symbol: symbol, attributes: nil)
                self.graphicsOverlay.graphics.add(graphic)
            }
        }
        mapView.graphicsOverlays.add(graphicsOverlay)
    }
    
    //IntをColorに変換
    func convertIntToColor(_ state: Int) -> UIImage{
        var color: UIImage!
        
        switch state {
        case 1:
            color = #imageLiteral(resourceName: "Pointer_green")
        case 2:
            color = #imageLiteral(resourceName: "Pointer_yellow")
        case 3:
            color = #imageLiteral(resourceName: "Pointer_orange")
        case 4:
            color = #imageLiteral(resourceName: "Pointer_red")
        default:
            color = UIImage.init()
        }
        
        return color.resize(size: CGSize.init(width: 30, height: 30))!
    }
    
    //±誤差の範囲内に居るかどうか
    func isApplyingRange(_ pointer: Pointer) -> Bool{
        guard let latitude = LocationData.latitude, let longitude = LocationData.longitude else {
            return false
        }
        
        if latitude < (pointer.latitude+ERROR_RANGE) &&
            (pointer.latitude-ERROR_RANGE) < latitude &&
            (pointer.longitude-ERROR_RANGE) < longitude &&
            longitude < (pointer.longitude+ERROR_RANGE) {
            
            return true
        }
        else{
            return false
        }
    }
    
    @objc func setNowLocation(){
        // 回転を北に合わせる
        self.mapView.setViewpointRotation(0, completion: { _ in})
        // 位置情報の表示モードを設定（現在位置を中心にマップをズームして表示する）
        self.mapView.locationDisplay.autoPanMode = .recenter
        // 現在位置の表示を開始
        mapView.locationDisplay.start(completion: { (error) -> Void in
            if let error = error {
                print("位置情報の取得のエラー:\(error.localizedDescription)")
            } else {
                print("位置情報の取得に成功")
                guard let latitude = LocationData.longitude, let longitude = LocationData.longitude else{
                    return
                }
                // 現在位置に合わせる
                self.mapView.location(toScreen: AGSPoint.init(
                    clLocationCoordinate2D: CLLocationCoordinate2D.init(latitude: latitude, longitude: longitude)))
                // マップが現在位置にズームされる際の表示縮尺の設定
                self.mapView.locationDisplay.initialZoomScale = 100000
            }
        })
    }
}

extension OfflineMapManager: AGSGeoViewTouchDelegate{
    
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        print("タッチアット")
//        self.mapView.callout.title = "Location"
//        self.mapView.callout.isAccessoryButtonHidden = true
    }
}

extension UIImage {
    func resize(size _size: CGSize) -> UIImage? {
        let widthRatio = _size.width / size.width
        let heightRatio = _size.height / size.height
        let ratio = widthRatio < heightRatio ? widthRatio : heightRatio
        
        let resizedSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(resizedSize, false, 0.0)
        draw(in: CGRect(origin: .zero, size: resizedSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
}
