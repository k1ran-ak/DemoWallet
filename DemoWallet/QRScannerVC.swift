//
//  QRScannerVC.swift
//  DemoWallet
//
//  Created by admin on 11/04/22.
//

import Foundation
import UIKit
import WalletConnect
import WalletCore
protocol ScannerProtocol {
    func url(code : String)
}

class QRScannerVC : UIViewController, ScannerProtocol {
   //MARK: - Outlets
    
    @IBOutlet weak var addressTF: UITextField!
    @IBOutlet weak var scanBtn: UIButton!
    @IBOutlet weak var approveBtn: UIButton!
    @IBOutlet weak var killBtn: UIButton!
    
   
    //MARK: - Local Variables
    private var qrcode = String()
    var interactor: WCInteractor?
    let clientMeta = WCPeerMeta(name: "WalletConnect SDK", url: "https://github.com/TrustWallet/wallet-connect-swift")

    let privateKey = PrivateKey(data: Data(hexString: "31f31a1674e45b7c5df4f1adfc7261c8a09ad3bc3e6dec6a23ac2a916e20e4e6")!)!

    var defaultAddress: String = ""
    var defaultChainId: Int = 1
    var recoverSession: Bool = false
    var notificationGranted: Bool = false
    
    private var backgroundTaskId: UIBackgroundTaskIdentifier?
    private weak var backgroundTimer: Timer?
    private lazy var viewModel: ExportPrivateKeyViewModel = {
        return .init(key: "31f31a1674e45b7c5df4f1adfc7261c8a09ad3bc3e6dec6a23ac2a916e20e4e6")
    }()
    
    var isConnected : Bool = false
    override func viewDidLoad() {
        super.viewDidLoad()
       
        defaultAddress = CoinType.ethereum.deriveAddress(privateKey: privateKey)
        addressTF.text = qrcode
        self.killBtn.setTitle("Connect", for: .normal)
//        approveButton.isEnabled = false

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            print("<== notification permission: \(granted)")
            if let error = error {
                print(error)
            }
            self.notificationGranted = granted
        }
    }
    
    func url(code: String) {
        self.qrcode = code
        addressTF.text = code
    }
  
    func ScanQRCode() {
        let vc = ScannerViewController(nibName: nil, bundle: nil)
        vc.delegate = self
        self.present(vc, animated: true)
    }
    
    func connectWallet() {
        let string = self.qrcode
        if string.isEmpty {
            return
        }
//        DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
//            let alert = UIAlertController(title: "Wallet App", message: "\(string)", preferredStyle: .alert)
//            let action = UIAlertAction(title: "Dismiss", style: .cancel)
//            alert.addAction(action)
//            self.present(alert, animated: true)
//        })
       
        guard let session = WCSession.from(string: string) else {
            // invalid session
            return
        }
        let clientMeta = WCPeerMeta(name: "DemoWallet", url: "https://example.walletconnect.org")
        let interactor = WCInteractor(session: session, meta: clientMeta, uuid: UUID())
        
        interactor.onSessionRequest = { (id, peer) in
            // ask for user consent
            print(id,peer)
        }

        interactor.onDisconnect = {(error) in
            // handle disconnect
            print(error)
        }

        interactor.eth.onSign = {(id, payload) in
            // handle eth_sign, personal_sign, eth_signTypedData
            print(id,payload)
        }

        interactor.eth.onTransaction = { (id, event, transaction) in
            // handle eth_signTransaction / eth_sendTransaction
            print(id,event,transaction)
        }

        interactor.bnb.onSign = {(id, order) in
            // handle bnb_sign
            print(id,order)
        }

    }
    
    func connect(session: WCSession) {
        print("==> session", session)
        let interactor = WCInteractor(session: session, meta: clientMeta, uuid: UIDevice.current.identifierForVendor ?? UUID())

        configure(interactor: interactor)

        interactor.connect().done { [weak self] connected in
            self?.connectionStatusUpdated(connected)
        }.catch { [weak self] error in
            self?.present(error: error)
        }

        self.interactor = interactor
    }
    
    func configure(interactor: WCInteractor) {
        let accounts = [defaultAddress]
        let chainId = defaultChainId

        interactor.onError = { [weak self] error in
            self?.present(error: error)
        }

        interactor.onSessionRequest = { [weak self] (id, peerParam) in
            let peer = peerParam.peerMeta
            let message = [peer.description, peer.url].joined(separator: "\n")
            let alert = UIAlertController(title: peer.name, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Reject", style: .destructive, handler: { _ in
                self?.interactor?.rejectSession().cauterize()
            }))
            alert.addAction(UIAlertAction(title: "Approve", style: .default, handler: { _ in
                self?.interactor?.approveSession(accounts: accounts, chainId: chainId).cauterize()
            }))
            self?.show(alert, sender: nil)
        }

        interactor.onDisconnect = { [weak self] (error) in
            if let error = error {
                print(error)
            }
            self?.connectionStatusUpdated(false)
        }

        interactor.eth.onSign = { [weak self] (id, payload) in
            let alert = UIAlertController(title: payload.method, message: payload.message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in
                self?.interactor?.rejectRequest(id: id, message: "User canceled").cauterize()
            }))
            alert.addAction(UIAlertAction(title: "Sign", style: .default, handler: { _ in
                self?.signEth(id: id, payload: payload)
            }))
            self?.show(alert, sender: nil)
        }

        interactor.eth.onTransaction = { [weak self] (id, event, transaction) in
            let data = try! JSONEncoder().encode(transaction)
            let message = String(data: data, encoding: .utf8)
            let alert = UIAlertController(title: event.rawValue, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Reject", style: .destructive, handler: { _ in
                self?.interactor?.rejectRequest(id: id, message: "I don't have ethers").cauterize()
            }))
            self?.show(alert, sender: nil)
        }
        
        

        interactor.bnb.onSign = { [weak self] (id, order) in
            let message = order.encodedString
            let alert = UIAlertController(title: "bnb_sign", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak self] _ in
                self?.interactor?.rejectRequest(id: id, message: "User canceled").cauterize()
            }))
            alert.addAction(UIAlertAction(title: "Sign", style: .default, handler: { [weak self] _ in
                self?.signBnbOrder(id: id, order: order)
            }))
            self?.show(alert, sender: nil)
        }

        interactor.trust.onTransactionSign = { [weak self] (id , transaction) in
            let data = try! JSONEncoder().encode(transaction)
            let message = String(data: data, encoding: .utf8)
            let alert = UIAlertController(title: "Trust Wallet", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Reject", style: .destructive, handler: { _ in
                self?.interactor?.rejectRequest(id: id, message: "I don't have okt").cauterize()
            }))
            alert.addAction(UIAlertAction(title: "Approve", style: .default, handler: { (_) in
                self?.interactor?.approveRequest(id: id, result: "This is the signed data").cauterize()
            }))
            self?.show(alert, sender: nil)
        }
    }

    func approve(accounts: [String], chainId: Int) {
        interactor?.approveSession(accounts: accounts, chainId: chainId).done {
            print("<== approveSession done")
        }.catch { [weak self] error in
            self?.present(error: error)
        }
    }

    func signEth(id: Int64, payload: WCEthereumSignPayload) {
        let data: Data = {
            switch payload {
            case .sign(let data, _):
                return data
            case .personalSign(let data, _):
                let prefix = "\u{19}Ethereum Signed Message:\n\(data)".data(using: .utf8)!
                return prefix + data
            case .signTypeData(_, let data, _):
                // FIXME
                return data
            }
        }()

        var result = privateKey.sign(digest: Hash.keccak256(data: data), curve: .secp256k1)!
        result[64] += 27
        self.interactor?.approveRequest(id: id, result: "0x" + result.hexString).cauterize()
    }

    func signBnbOrder(id: Int64, order: WCBinanceOrder) {
        let data = order.encoded
        print("==> signbnbOrder", String(data: data, encoding: .utf8)!)
        let signature = privateKey.sign(digest: Hash.sha256(data: data), curve: .secp256k1)!
        let signed = WCBinanceOrderSignature(
            signature: signature.dropLast().hexString,
            publicKey: privateKey.getPublicKeySecp256k1(compressed: false).data.hexString
        )
        interactor?.approveBnbOrder(id: id, signed: signed).done({ confirm in
            print("<== approveBnbOrder", confirm)
        }).catch { [weak self] error in
            self?.present(error: error)
        }
    }

    func connectionStatusUpdated(_ connected: Bool) {
//        self.approveButton.isEnabled = connected
//        self.connectButton.setTitle(!connected ? "Connect" : "Kill Session", for: .normal)
    }

    func present(error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.show(alert, sender: nil)
    }

    
    
    //MARK: - Button Actions
    @IBAction func scanBtnAction(_ sender: Any) {
        self.ScanQRCode()
        
        let vc = ExportPrivateKeyViewConroller(viewModel: viewModel)
        self.present(vc, animated: true)
    }
    
    @IBAction func approveBtnAtn(_ sender: Any) {
        let chainId = self.defaultChainId
        guard let address = addressTF.text else {
            print("empty address or chainId")
            return
        }
//        guard EthereumAbi.isValidString(string: address) || Cosmos.isValidString(string: address) else {
//            print("invalid eth or bnb address")
//            return
//        }
        approve(accounts: [address], chainId: chainId)
    }
    
    
    @IBAction func killBtnAtn(_ sender: Any) {
        if isConnected {
            self.killBtn.setTitle("Kill Session", for: .normal)
        } else {
            self.killBtn.setTitle("Connect", for: .normal)
        }
        
        guard let string = self.addressTF.text, let session = WCSession.from(string: string) else {
            print("invalid uri: \(String(describing: self.addressTF.text))")
            return
        }
        
        
        
        if let i = interactor, i.state == .connected {
            i.killSession().done {  [weak self] in
//                self?.approveButton.isEnabled = false
//                self?.connectButton.setTitle("Connect", for: .normal)
            }.cauterize()
        } else {
            connect(session: session)
        }

    }
    @IBAction func generateBtnAtn(_ sender: Any) {
        let vc = ExportPrivateKeyViewConroller(viewModel: viewModel)
        vc.delegate = self
        self.present(vc, animated: true)
    }
    
    
}
extension QRScannerVC {
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("<== applicationDidEnterBackground")

        if interactor?.state != .connected {
            return
        }

        if notificationGranted {
            pauseInteractor()
        } else {
            startBackgroundTask(application)
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("==> applicationWillEnterForeground")
        if let id = backgroundTaskId {
            application.endBackgroundTask(id)
        }
        backgroundTimer?.invalidate()

        if recoverSession {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                self.interactor?.resume()
            }
        }
    }

    func startBackgroundTask(_ application: UIApplication) {
        backgroundTaskId = application.beginBackgroundTask(withName: "WalletConnect", expirationHandler: {
            self.backgroundTimer?.invalidate()
            print("<== background task expired")
        })

        var alerted = false
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            print("<== background time remainning: ", application.backgroundTimeRemaining)
            if application.backgroundTimeRemaining < 15 {
                self.pauseInteractor()
            } else if application.backgroundTimeRemaining < 120 && !alerted {
                let notification = self.createWarningNotification()
                UNUserNotificationCenter.current().add(notification, withCompletionHandler: { error in
                    alerted = true
                    if let error = error {
                        print("post error \(error.localizedDescription)")
                    }
                })
            }
        }
    }

    func pauseInteractor() {
        recoverSession = true
        interactor?.pause()
    }

    func createWarningNotification() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "WC session will be interrupted"
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        return UNNotificationRequest(identifier: "session.warning", content: content, trigger: trigger)
    }
}

