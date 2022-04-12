//
//  ExportProfileVC.swift
//  DemoWallet
//
//  Created by admin on 11/04/22.
//

import Foundation
import WalletCore
import UIKit
import MBProgressHUD

final class ExportPrivateKeyViewConroller: UIViewController {

    private struct Layout {
        static var widthAndHeight: CGFloat = 260
    }
    
    var delegate : ScannerProtocol!
    

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontSizeToFitWidth = true
        label.text = viewModel.headlineText
        label.textColor = .red
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    lazy var warningKeyLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = viewModel.warningText
        label.textColor = .red
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    lazy var copyButton: UIButton = {
        let button = Button(size: .extraLarge, style: .clear)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(copyAction(_:)), for: .touchUpInside)
        button.setTitle(NSLocalizedString("Copy", value: "Copy", comment: ""), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let viewModel: ExportPrivateKeyViewModel

    init(
        viewModel: ExportPrivateKeyViewModel
    ) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = viewModel.backgroundColor

        let stackView = UIStackView(
            arrangedSubviews: [
            hintLabel,
            imageView,
            warningKeyLabel,
            copyButton,
        ])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.backgroundColor = viewModel.backgroundColor
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: StyleLayout.sideMargin),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: StyleLayout.sideMargin),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -StyleLayout.sideMargin),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -StyleLayout.sideMargin),

            imageView.heightAnchor.constraint(equalToConstant: Layout.widthAndHeight),
            imageView.widthAnchor.constraint(equalToConstant: Layout.widthAndHeight),
        ])

        createQRCode()
    }

    func createQRCode() {
        displayLoading()
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let `self` = self else { return }
            let image = QRGenerator.generate(from: self.viewModel.privateKeyString)
            DispatchQueue.main.async {
                self.imageView.image = image
                self.hideLoading()
            }
        }
    }
    func displayLoading(
        text: String = String(format: NSLocalizedString("loading.dots", value: "Loading %@", comment: ""), "..."),
        animated: Bool = true
    ) {
        let hud = MBProgressHUD.showAdded(to: self.view, animated: animated)
        hud.label.text = text
    }
    
    @objc private func copyAction(_ sender: UIButton) {
        showShareActivity(from: sender, with: [viewModel.privateKeyString])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showShareActivity(from sender: UIView, with items: [Any], completion: (() -> Swift.Void)? = nil) {
        
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: [])
        activityViewController.popoverPresentationController?.sourceView = sender
        activityViewController.popoverPresentationController?.sourceRect = sender.frame
        present(activityViewController, animated: true, completion: completion)
    }
    func hideLoading(animated: Bool = true) {
        MBProgressHUD.hide(for: view, animated: animated)
    }
}

struct StyleLayout {
    static let sideMargin: CGFloat = 15
    static let sideCellMargin: CGFloat = 10

    struct TableView {
        static let heightForHeaderInSection: CGFloat = 30
        static let separatorColor = UIColor(named: "d7d7d7")
    }

    struct CollectibleView {
        static let heightForHeaderInSection: CGFloat = 40
    }
}

class Button: UIButton {

    init(size: ButtonSize, style: ButtonStyle) {
        super.init(frame: .zero)
        apply(size: size, style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(size: ButtonSize, style: ButtonStyle) {
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: size.height),
        ])

        backgroundColor = style.backgroundColor
        layer.cornerRadius = style.cornerRadius
        layer.borderColor = style.borderColor.cgColor
        layer.borderWidth = style.borderWidth
        layer.masksToBounds = true
        titleLabel?.textColor = style.textColor
        titleLabel?.font = style.font
        setTitleColor(style.textColor, for: .normal)
        setTitleColor(style.textColorHighlighted, for: .highlighted)
        setBackgroundColor(style.backgroundColorHighlighted, forState: .highlighted)
        setBackgroundColor(style.backgroundColorHighlighted, forState: .selected)
        setBackgroundColor(style.backgroundColorDisabled, forState: .disabled)

        contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
    }

}

final class QRGenerator {
    static func generate(from string: String) -> UIImage? {
        let context = CIContext()
        let data = string.data(using: String.Encoding.ascii)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 7, y: 7)
            if let output = filter.outputImage?.transformed(by: transform), let cgImage = context.createCGImage(output, from: output.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
}
enum ButtonSize: Int {
    case small
    case normal
    case large
    case extraLarge

    var height: CGFloat {
        switch self {
        case .small: return 32
        case .normal: return 44
        case .large: return  50
        case .extraLarge: return 64
        }
    }
}

enum ButtonStyle: Int {
    case solid
    case squared
    case border
    case borderless
    case clear

    var backgroundColor: UIColor {
        switch self {
        case .solid, .squared: return .blue
        case .border, .borderless: return .white
        case .clear : return .clear
        }
    }

    var backgroundColorHighlighted: UIColor {
        switch self {
        case .solid, .squared: return .blue
        case .border: return .blue
        case .borderless: return .white
        case .clear: return .clear
        }
    }

    var backgroundColorDisabled: UIColor {
        return .darkGray
    }

    var cornerRadius: CGFloat {
        switch self {
        case .solid, .border: return 5
        case .squared, .borderless, .clear: return 0
        }
    }

    var font: UIFont {
        switch self {
        case .solid,
             .squared,
             .border,
             .borderless,
             .clear:
            return UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.medium)
        }
    }

    var textColor: UIColor {
        switch self {
        case .solid, .squared: return .white
        case .border, .borderless, .clear: return .blue
        }
    }

    var textColorHighlighted: UIColor {
        switch self {
        case .solid, .squared: return UIColor(white: 1, alpha: 0.8)
        case .border: return .white
        case .borderless, .clear: return .blue
        }
    }

    var borderColor: UIColor {
        switch self {
        case .solid, .squared, .border: return .blue
        case .borderless, .clear: return .clear
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .solid, .squared, .borderless, .clear: return 0
        case .border: return 1
        }
    }
}
extension UIButton {
    func setBackgroundColor(_ color: UIColor, forState: UIControl.State) {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        UIGraphicsGetCurrentContext()!.setFillColor(color.cgColor)
        UIGraphicsGetCurrentContext()!.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let colorImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        self.setBackgroundImage(colorImage, for: forState)
    }
}
struct ExportPrivateKeyViewModel {

    let privateKey: Data
    let privateKeyString : String

    init(
        privateKey: Data
    ) {
        self.privateKey = privateKey
        self.privateKeyString = privateKey.hexString
    }
    
    init(key : String) {
        self.privateKeyString = key
        self.privateKey = Data(hexString: key) ?? Data()
    }

    var headlineText: String {
        return NSLocalizedString("export.warning.private.key", value: "Export at your own risk!", comment: "")
    }

//    var privateKeyString: String {
//        return privateKey.hexString
//    }

    var warningText: String {
        return NSLocalizedString("export.warningTwo.private.key", value: "Anyone with your Private Key will have FULL access to your wallet!", comment: "")
    }

    var backgroundColor: UIColor {
        return .white
    }
}
