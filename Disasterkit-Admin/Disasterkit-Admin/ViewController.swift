//
//  ViewController.swift
//  Disasterkit-Admin
//
//  Created by kiyolab01 on 2017/11/18.
//  Copyright © 2017年 kiyolab01. All rights reserved.
//

import UIKit
import FirebaseDatabase
import UserNotifications
import Reachability

private let sectionHead1 = """
避難場所の名前を入力します.
全ユーザに公開される名前です.
"""

private let sectionHead2 = """
避難所の混雑状況を選択してください.
"""

private let sectionHead3 = """
上記項目に間違いがないか確認してください.
"""

protocol ShowDelegate {
    func pushNotification(from: String, message: String)
    func showAlert()
}

protocol TimerDelegate{
    func startAdhoc()
    func stopAdhoc()
}

class ViewController: UIViewController {
    
    //メッセージのパース用に使うため、使わせない文字
    let NO_USED = "§"
    
    let tableView = UITableView(frame: .zero, style: .grouped)
    var cell = [UITableViewCell]()
    var sectionHead = [String]()
    var timer: Timer!
    
    /// 避難所の名前を入力するテキストフィールド.
    weak var inputField: UITextField!
//    @IBOutlet var congestionStateSlider: UISlider!
    
    /// 混み具合を表すセグメント.
    /// "少ない", "余裕あり", "多い", "満員" --> 0, 1, 2, 3 で対応付けられている.
    /// segmentedControl.selectedSegmentIndex で取得可能.
    weak var segmentedControl: UISegmentedControl!
    
    //何秒ごとにメッセージ受け取り更新をするか
    let RELOAD_INTERVAL: TimeInterval = 5
    
    override func loadView() {
        super.loadView()
        
        cell = [
            TextFieldCell(), CongestionCell(), UITableViewCell()
        ]
        
        inputField = (cell[0] as! TextFieldCell).textField
        segmentedControl = (cell[1] as! CongestionCell).segmentedControl
        
        sectionHead = [
            sectionHead1, sectionHead2, sectionHead3
        ]
        cell.last?.textLabel?.text = "情報を送信"
        cell.last?.textLabel?.textColor =
            UIColor(displayP3Red: 0, green: 122 / 255, blue: 1, alpha: 1)
        
        tableView.separatorColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        
        //自治体にユーザ情報はいらないので
        PreferenceManager.shared.write(person: User("自治体", Provision.locationInfoToInt64))
        BLEManager.shared.showDelegate = self
//        AdhocManager.shared.timerDelegate = self
        LocationManager.shared.start()
        pushConfigAlert()
        monitorInputField()
        
        //タイマーをセット
        timer = Timer.scheduledTimer(timeInterval: RELOAD_INTERVAL, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = CGRect(
            x: 0,
            y: navigationController?.navigationBar.frame.height ?? 0,
            width: view.frame.width,
            height: view.frame.height - (navigationController?.navigationBar.frame.height ?? 0)
        )
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //Timer.scheduledTimerで指定秒数ごとに発火する
    @objc func update(){
        DBManager.pushMessage(que: Provision.queForAnother)
        DBManager.fetchMessages()
        AdhocManager.shared.update()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    //位置情報を取得してデータベースに送信
    func prepareLocation() {
        if let name = self.inputField.text, !name.isEmpty {
            let message = "避難所名「\(name)」で位置情報を送信してよろしいですか？"
            confirmAlert(message)
        }
        else{
            warningAlert(title: "避難所の名前が記入されていません")
        }
    }
    
    func confirmAlert(_ message: String){
        let alert: UIAlertController = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        let actionLeft = UIAlertAction.init(title: "キャンセル", style: .default)
        let actionRight = UIAlertAction.init(title: "OK", style: .default){ _ in
            self.sendLocation()
        }
        alert.addAction(actionLeft)
        alert.addAction(actionRight)
        present(alert, animated: true, completion: nil)
    }
    
    //位置情報と同期して動作したいのでdidUpdateLocationsで発火させる
    func sendLocation(){
        guard let name = inputField.text, name != "", let latitude = LocationData.latitude, let longitude = LocationData.longitude else{
            warningAlert(title: "現在地を取得できませんでした")
            return
        }
        
        //混雑度は1~4なので+1する
        let state = segmentedControl.selectedSegmentIndex + 1
        
        //ターゲットを自分にすることで無限ループにする
        let uuid = Provision.connectionForLocation()
        let data = "\(latitude)" + NO_USED + "\(longitude)" + NO_USED + "\(state)" + NO_USED + name
        AdhocManager.shared.sendMessage(from: uuid, message: data)
        
        let pointer = Pointer(name, latitude, longitude, state)
        DBManager.pushLocation(pointer)
        
        LocationData.latitude = nil
        LocationData.longitude = nil
        self.inputField.text = ""
        
        warningAlert(title: "アドホックネットワークに避難所データを送信しました")
    }
    
    func warningAlert(title: String){
        let alert: UIAlertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        let action = UIAlertAction.init(title: "OK", style: .default)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
}


extension ViewController: UNUserNotificationCenterDelegate{
    private func pushConfigAlert(){
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        //通知設定のアラートを出す
        center.requestAuthorization(options: [.badge, .sound, .alert], completionHandler: { _, _ in
            //何もしない
        })
    }
    
    //直接遷移できないので、設定に飛ばす
    private func segueConfig(){
        let url = URL(string:"App-Prefs:root")!
        if UIApplication.shared.canOpenURL(url){
            UIApplication.shared.open(url)
        }
    }
    
    //InputFieldを監視する
    private func monitorInputField(){
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(inputFieldDidChange),
            name: NSNotification.Name.UITextFieldTextDidChange,
            object: self.inputField
        )
    }
    
    //61文字までしか送信できないので制限する
    @objc func inputFieldDidChange(notification: NSNotification){
        let MAX_COUNT = 20
        let textFieldString = notification.object as! UITextField
        if let text = textFieldString.text {
            if text.characters.last == NO_USED.characters.first{
                self.inputField.text = String(text.prefix(text.characters.count-1))
                warningAlert(title: "「\(NO_USED)」この文字は使えません")
            }
            else if text.characters.count > MAX_COUNT {
                self.inputField.text = text.substring(to: text.index(text.startIndex, offsetBy: MAX_COUNT))
                warningAlert(title: "\(MAX_COUNT)文字までしか入力できません")
            }
        }
    }
}

extension ViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cell[indexPath.section]
    }
}

extension ViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.section < 2 {
            return nil
        }
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 11.5)
        label.textColor = UIColor.lightGray
        label.text = sectionHead[section]
        return label
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // MARK: - 送信ボタンを押したときの処理.
        prepareLocation()
    }
}


class TextFieldCell: UITableViewCell {
    
    let textField = UITextField()
    private let label = UILabel()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .none
        
        textField.layer.borderColor = UIColor.black.cgColor
        textField.layer.borderWidth = 0.5
        
        label.textAlignment = .center
        label.text = "表示名"
        
        addSubview(label)
        addSubview(textField)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        label.frame = CGRect(
            x: 0,
            y: frame.height * 0.5 - 15,
            width: 80,
            height: 30
        )
        
        textField.frame = CGRect(
            x: 90,
            y: frame.height * 0.5 - 30 * 0.5,
            width: frame.width - 100,
            height: 30
        )
        
        textField.layer.cornerRadius = frame.height * 0.25
    }
}

class CongestionCell: UITableViewCell {
    let segmentedControl = UISegmentedControl(items: [
        "少ない", "余裕あり", "多い", "満員"
        ])
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        segmentedControl.selectedSegmentIndex = 0
        addSubview(segmentedControl)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        segmentedControl.frame = CGRect(
            x: 10, y: 10,
            width: frame.width - 20,
            height: frame.height - 20
        )
    }
}

//ShowDelegateまとめ
extension ViewController: ShowDelegate{
    
    //通知を送る
    func pushNotification(from: String, message: String){
        let content = UNMutableNotificationContent()
        content.title = from
        content.body = message
        content.sound = UNNotificationSound.default()
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest.init(identifier: "Disaster kit", content: content, trigger: trigger)
        
        // ローカル通知予約
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    //アラートを出す
    func showAlert(){
        let alert: UIAlertController = UIAlertController(title: "設定を押してWi-FiとBluetoothをオンにして下さい", message: nil, preferredStyle: .alert)
        let actionLeft = UIAlertAction.init(title: "設定", style: .default){ _ in
            self.segueConfig()
        }
        let actionRight = UIAlertAction.init(title: "OK", style: .default)
        alert.addAction(actionLeft)
        alert.addAction(actionRight)
        present(alert, animated: true, completion: nil)
    }
}

//何故かうまく動作しないので廃止
extension ViewController: TimerDelegate{
    
    //アドホック開始
    func startAdhoc() {
        timer.fire()
    }
    
    //アドホック停止
    func stopAdhoc(){
        timer.invalidate()
    }
}

