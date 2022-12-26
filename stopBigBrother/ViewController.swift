//
//  ViewController.swift
//  stopBigBrother
//
//  Created by ip on 6/10/20.
//

import UIKit
import Photos
import BSImagePicker
import Vision

class ViewController: UIViewController{
    
    @IBOutlet weak var settingsBtn: UIButton!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var infoLbl: UILabel!
    
    @IBOutlet weak var processPhotosBtn: UIButton!
    
    @IBOutlet weak var selectImgBtn: UIButton!
    
    @IBOutlet weak var logoImgView: UIImageView!
    
    @IBOutlet weak var infoBtn: UIButton!
    
    // MARK - Global fields
    var aimMap = Dictionary<String, Aim>()
    var aimOrderedIDs = [String]()
    var currentAssetID = ""
    
    let thumbManager = PHCachingImageManager()
    let thumbOption = PHImageRequestOptions()
    var spinner = SpinnerViewController()
    
    var clearSelectionBtn = UIButton()
    var cvInstructionView = UITextView()
    var infoOverlay = UIView()
    
    // MARK - Segue fields
    var transferMD: Dictionary<String, Any> = Dictionary()
    
    // MARK - Settings
    var shouldBlurFaces = true
    var shouldDeleteLocation = true
    var saveAsCopy = true
    var sliderValue: Float = 0.65
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // MARK - Make UI look nice
        logoImgView.layer.cornerRadius = 2
        setInfoLabel()
        infoLbl.isHidden = true
        selectImgBtn.layer.cornerRadius = 15
        selectImgBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        processPhotosBtn.layer.cornerRadius = 15
        processPhotosBtn.isHidden = true
        infoBtn.layer.cornerRadius = 10
        settingsBtn.layer.cornerRadius = 10
        collectionView.layer.borderWidth = 2.0
        collectionView.layer.cornerRadius = 15
        collectionView.layer.borderColor = UIColor.black.cgColor.copy(alpha: 0.8)
        
        if !cvInstructionView.hasText {
            cvInstructionView = instructionViewSetup()
            collectionView.addSubview(cvInstructionView)
        }
        
        if #available(iOS 12, *) {
            if traitCollection.userInterfaceStyle == .dark {
                collectionView.layer.borderColor = UIColor.white.cgColor.copy(alpha: 0.8)
                cvInstructionView.textColor = UIColor.white
            }
        }
        
        thumbOption.isSynchronous = true
        thumbOption.isNetworkAccessAllowed = true
        thumbManager.allowsCachingHighQualityImages = false
        
        configureCV()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 12, *) {
            if traitCollection.userInterfaceStyle == .dark {
                collectionView.layer.borderColor = UIColor.white.cgColor.copy(alpha: 0.8)
                cvInstructionView.textColor = UIColor.white
                setClearBtnText(darkMode: true)
            } else {
                collectionView.layer.borderColor = UIColor.black.cgColor.copy(alpha: 0.8)
                cvInstructionView.textColor = UIColor.darkText
                setClearBtnText(darkMode: false)
            }
        } else {
            collectionView.layer.borderColor = UIColor.black.cgColor.copy(alpha: 0.8)
            cvInstructionView.textColor = UIColor.darkText
            setClearBtnText(darkMode: false)
        }
    }
    
    // Attempt to recover if encountered memory warning.
    override func didReceiveMemoryWarning() {
        print("[-] Received Memory Warning")
        cleanUp(showMessage: false)
        thumbManager.stopCachingImagesForAllAssets()
        showAlertWith(title: "Oops: Low on Memory", message: "Your phone is low on memory. Try closing other apps or please try again.", transfer: "")
    }
    
    // Select photos from library.
    @IBAction func selectPhotoAction(_ sender: Any) {
        if PHPhotoLibrary.authorizationStatus() == .denied {
            showAlertWith(title: "Access required...", message: "Please grant access to your photo library in settings app to continue.", transfer: "settings")
            return
        }
        let picker = ImagePickerController()
        picker.settings.selection.max = 10 - aimMap.count
        presentImagePicker(picker, select: { (asset: PHAsset) -> Void in
            // User selects an asset.
        }, deselect: { (asset: PHAsset) -> Void in
            // User deselects an asset.
        }, cancel: { (assets: [PHAsset]) -> Void in
            // User cancelled selection.
        }, finish: { (assets: [PHAsset]) -> Void in
            // User finishes selection.
            for asset in assets {
                let exists = self.aimMap[asset.localIdentifier] != nil
                if !exists {
                    self.aimMap[asset.localIdentifier] = Aim(asset: asset, metadata: self.getMetadata(asset: asset), position: self.aimMap.count)
                    self.aimOrderedIDs.append(asset.localIdentifier)
                }
            }
            self.thumbManager.startCachingImages(for: self.aimMap.values.map{value in value.asset}, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: self.thumbOption)
            self.collectionView.reloadData()
            let isPluralTxt = self.aimMap.count > 1 ? "Photos" : "Photo"
            self.processPhotosBtn.setTitle("Process \(self.aimMap.count) \(isPluralTxt)", for: .normal)
            
            self.cvInstructionView.removeFromSuperview()
            self.infoLbl.isHidden = false
            self.processPhotosBtn.isHidden = false
            self.selectImgBtn.setTitle("Add Images", for: .normal)
            if !self.clearSelectionBtn.isDescendant(of: self.view) {
                self.addClearSelectionBtn()
            }
        })
    }
    
    // Retrieve full size image with asset ID.
    private func fetchFullImage(asset: PHAsset) -> Bool {
        print("Fetching image: \(asset.localIdentifier)")
        var img = UIImage()
        var success = true
        let manager = PHImageManager()
        let option = PHImageRequestOptions()
        
        option.deliveryMode = .highQualityFormat
        option.isSynchronous = true
        option.isNetworkAccessAllowed = true
        option.progressHandler = { (progress, error, stop, info) in
            print("[-] progress: \(progress)")
        }
        let imgSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        let scaleFactor = UIScreen.main.scale
        let scale = CGAffineTransform(scaleX: 1/scaleFactor, y: 1/scaleFactor)
        let scaledSize = imgSize.applying(scale)
        manager.requestImage(for: asset, targetSize: scaledSize, contentMode: .aspectFit, options: option, resultHandler: { (result, info) in
            if result == nil {
                success = false
                return
            }
            img = result!
            let data = img.jpegData(compressionQuality: CGFloat(self.sliderValue))
            img = UIImage(data: data!)!
            self.aimMap[asset.localIdentifier]?.image = img
        })
        return success
    }
    
    // Retrieve thumbnail with asset ID.
    private func fetchThumbnail(asset: PHAsset) -> UIImage {
        var resultImg: UIImage = UIImage()
        thumbOption.progressHandler = { (progress, error, stop, info) in
            print("[-] Thumbnail progress: \(progress)")
        }
        thumbManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: thumbOption, resultHandler: { (result, info) in
            resultImg = result!
            let data = resultImg.jpegData(compressionQuality: 0.6)
            resultImg = UIImage(data: data!)!
        })
        return resultImg
    }
    
    // Download image from iCloud.
    private func downloadImages() -> Bool {
        var success = true
        self.aimMap.values.forEach { value in
            if !self.fetchFullImage(asset: value.asset) {
                let failedIndex = value.position
                cleanUp(showMessage: false)
                showAlertWith(title: "Unable to get image", message: "Could not retrieve image (#\(failedIndex)). Please check your network connection and/or iPhone storage capacity.", transfer: "")
                success = false
                return
            }
        }
        return success
    }
    
    // Queue selected photos to be processed.
    @IBAction func processPhotosAction(_ sender: Any) {
        clearSelectionBtn.removeFromSuperview()
        self.showSpinner()
        DispatchQueue.global(qos: .background).async {
            if !self.downloadImages() {
                return
            }
            DispatchQueue.main.async {
                self.aimOrderedIDs.forEach { assetID in
                    let value = self.aimMap[assetID]!
                    print("[-] Processing #\(value.position)")
                    self.currentAssetID = value.asset.localIdentifier
                    self.processImage(image: value.image)
                }
            }
        }
    }
    
    // Process photos through vision kit.
    private func processImage(image: UIImage) {
        let originalImg: UIImage = image
        let sequenceHandler = VNSequenceRequestHandler()
        let detectFaceRequest = VNDetectFaceRectanglesRequest(completionHandler: detectedFace)
        do {
            try sequenceHandler.perform([detectFaceRequest], on: originalImg.cgImage!, orientation: CGImagePropertyOrientation(originalImg.imageOrientation))
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // Retrieve detected face boxes.
    private func detectedFace(request: VNRequest, error: Error?) {
        guard var results = request.results as? [VNFaceObservation]
            else {
                print("Encountered error when retrieving results array")
                return
        }
        let asyncAssetID = self.currentAssetID
        DispatchQueue.main.async { [self] in
            if !shouldBlurFaces {
                results = []
                print("Will not blur faces (due to settings)")
            } else {
                print("Blurring \(results.count) faces")
            }
            let aimObj = aimMap[asyncAssetID]!
            let autoAnnotatedImage = draw(faces: results, image: aimObj.image)
            aimMap[asyncAssetID]?.image = autoAnnotatedImage
            if (aimObj.position == aimMap.count - 1) {
                self.performSegue(withIdentifier: "ReviewVC", sender: self)
            }
            print("[-] Done with asset # \(asyncAssetID)")
        }
    }
    
    // Draw face boxes on image.
    private func draw(faces: [VNFaceObservation], image: UIImage) -> UIImage{
        var faceBoxes: [CGRect] = []
        let renderedImage = UIGraphicsImageRenderer(size: image.size).image { (rendererContext) in
            image.draw(at: CGPoint.zero)
            faces.forEach{ face in
                faceBoxes.append(face.boundingBox.applying(CGAffineTransform(scaleX: CGFloat(image.size.width), y: -CGFloat(image.size.height))).applying(CGAffineTransform(translationX: 0, y: CGFloat(image.size.height))))
            }
            faceBoxes.forEach { box in
//                rendererContext.fill(box)
                UIColor.systemGreen.setStroke()
                rendererContext.cgContext.setLineWidth(10.0)
                rendererContext.stroke(box)
            }
            var left: [[CGPoint]?] = []
            var right: [[CGPoint]?] = []
            faces.forEach{ face in
                left.append(face.landmarks?.leftEye!.normalizedPoints)
                right.append(face.landmarks?.rightEye!.normalizedPoints)
            }
            
            let newLayer = CAShapeLayer()
            let path = UIBezierPath()
            left.forEach{ points in
                path.move(to: CGPoint(x: points![0].x, y: points![0].y))
                for i in 0..<points!.count-1 {
                    let point = CGPoint(x: points![i].x, y: points![i].y)
                    path.addLine(to: point)
                    path.move(to: point)
                }
                newLayer.path = path.cgPath
//                rendererContext.
            }
        }
        print("Done drawing, size: \(renderedImage.size)")
        return renderedImage
    }
    
    // Release memory and appropriate display "completion" message.
    private func cleanUp(showMessage: Bool) {
        removeSpinner()
        if showMessage {
            if(aimOrderedIDs.count == 0) {
                self.showAlertWith(title: "Cancelled", message: "No photos were saved.", transfer: "")
            } else {
                self.showAlertWith(title: "Done", message: "\(aimOrderedIDs.count) images processed and saved.", transfer: "photos")
            }
        }
        aimMap.removeAll()
        aimOrderedIDs.removeAll()
        currentAssetID = ""
        DispatchQueue.main.async {
            self.selectImgBtn.setTitle("Select Images", for: .normal)
            self.collectionView.reloadData()
            self.infoLbl.isHidden = true
            self.processPhotosBtn.isHidden = true
            self.clearSelectionBtn.removeFromSuperview()
        }
    }
    
    // Create and present an alert.
    func showAlertWith(title: String, message: String, transfer: String) {
        guard let photosUrl = URL(string: "photos-redirect://") else {
            return
        }
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        DispatchQueue.main.async {
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            if transfer != "" {
                let redirectAction = UIAlertAction(title: "Go to \(transfer)", style: .default, handler: { action in
                    if transfer=="photos" {
                        UIApplication.shared.open(photosUrl, completionHandler: { (success) in
                            print("Photos opened: \(success)")
                        })
                    } else if transfer=="settings" {
                        UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                            print("Settings opened: \(success)")
                        })
                    }
                })
                ac.addAction(redirectAction)
                ac.preferredAction = redirectAction
            }
            self.present(ac, animated: true)
        }
    }
    
    // Retrieve metadata with asset ID.
    private func getMetadata(asset: PHAsset) -> Dictionary<String, Any> {
        var dict: Dictionary<String, Any> = [:]
        dict["mediaType"] = asset.mediaType
        dict["creationDate"] = asset.creationDate
        dict["mediaSubtypes"] = asset.mediaSubtypes
        dict["sourceType"] = asset.sourceType
        dict["location"] = asset.location
        dict["pixelWidth"] = asset.pixelWidth
        dict["pixelHeight"] = asset.pixelHeight
        dict["modificationDate"] = asset.modificationDate
        return dict
    }
    
    // Receive data from sender VC to main.
    @IBAction func unwindToMain(_ unwindSegue: UIStoryboardSegue) {
        let sender = unwindSegue.source
        if sender is settingsVC {
            if let senderVC = sender as? settingsVC {
                shouldDeleteLocation = senderVC.deleteLocationSwitch.isOn
                shouldBlurFaces = senderVC.blurFacesSwitch.isOn
                saveAsCopy = senderVC.saveAsCopySwitch.isOn
                sliderValue = senderVC.compressionSlider.value
            }
        } else if sender is ReviewVC {
            if let senderVC = sender as? ReviewVC {
                print("[-] Review process complete")
                aimOrderedIDs = [String](repeating: "", count: senderVC.numberOfSavedImages)
                cleanUp(showMessage: true)
            }
        }
    }
    
    // Transfer data from current VC to destination.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("Segue from Home to: '\(segue.identifier!)'")
        if segue.identifier == "metadataVC" {
            let vc = segue.destination as! metadataVC
            vc.receiveMD = transferMD
        } else if segue.identifier == "settingsVC" {
            let vc = segue.destination as! settingsVC
            vc.segueSettings["delete"] = shouldDeleteLocation
            vc.segueSettings["blur"] =  shouldBlurFaces
            vc.segueSettings["save"] = saveAsCopy
            vc.segueSettings["slider"] = sliderValue
        }
        if segue.identifier == "ReviewVC" {
            let vc = segue.destination as! ReviewVC
            vc.receiveAimMap = aimMap
            vc.receiveAimOrderedIDs = aimOrderedIDs
            
            vc.segueSettings["delete"] = shouldDeleteLocation
            vc.segueSettings["blur"] =  shouldBlurFaces
            vc.segueSettings["save"] = saveAsCopy
            vc.segueSettings["slider"] = sliderValue
            
            aimMap.removeAll()
        }
    }
    
    // Setup collection view.
    fileprivate func configureCV() {
        let insetSize: CGFloat = 10
        let spacing: CGFloat = 10
        let cellWidth: CGFloat = min(collectionView.frame.width/2 - insetSize - spacing/2, 200)
        let cellHeight: CGFloat = min(collectionView.frame.height/2.5 - spacing/2, 250)
        let cellSize = CGSize(width: cellWidth, height: cellHeight)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = cellSize
        layout.sectionInset = UIEdgeInsets(top: insetSize, left: insetSize, bottom: insetSize, right: insetSize)
        layout.minimumLineSpacing = spacing
        layout.minimumInteritemSpacing = spacing*0.8
        collectionView.setCollectionViewLayout(layout, animated: true)
        
        collectionView.reloadData()
    }
    
    // Add clear button on top of CV.
    fileprivate func addClearSelectionBtn(){
        print("[-] Adding clear selection btn")
        clearSelectionBtn = UIButton(frame: CGRect(x: collectionView.frame.minX, y: collectionView.frame.maxY, width: 50, height: 40))
        clearSelectionBtn.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 12.0, *) {
            setClearBtnText(darkMode: traitCollection.userInterfaceStyle == .dark)
        } else {
            setClearBtnText(darkMode: false)
        }
        self.view.addSubview(clearSelectionBtn)
        clearSelectionBtn.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor).isActive = true
        clearSelectionBtn.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: -5).isActive = true
        clearSelectionBtn.layer.cornerRadius = 15
        clearSelectionBtn.addTarget(self, action: #selector(self.clearSelectionAction), for: .touchUpInside)
    }
    
    fileprivate func setClearBtnText(darkMode: Bool) {
        let btnFrame = CGRect(x: collectionView.frame.minX, y: collectionView.frame.maxY, width: 50, height: 40)
        let attachment = NSTextAttachment()
        attachment.image = darkMode ? UIImage(named: "clear-symbol-dark") : UIImage(named: "clear-symbol-light")
        let imageOffsetY: CGFloat = -btnFrame.height / 4
        attachment.bounds = CGRect(x: 0, y: imageOffsetY, width: btnFrame.height * (attachment.image!.size.width/attachment.image!.size.height), height: btnFrame.height)
        let attachmentString = NSAttributedString(attachment: attachment)
        clearSelectionBtn.setAttributedTitle(attachmentString, for: .normal)
    }
    
    @IBAction func clearSelectionAction() {
        DispatchQueue.main.async {
            let title = "Clear selection?"
            let message = "Would you like to clear your current selection of images?"
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "No", style: .cancel))
            ac.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { action in
                self.cleanUp(showMessage: false)
            }))
            self.present(ac, animated: true)
        }
    }
    
    // Set attributed text for info label.
    func setInfoLabel() {
        print("[-] Add info label")
        let attachment = NSTextAttachment()
        attachment.image = UIImage(named: "info-blue")
        let imageOffsetY: CGFloat = -infoLbl.frame.height/4
        attachment.bounds = CGRect(x: 0, y: imageOffsetY, width: infoLbl.frame.height * (attachment.image!.size.width/attachment.image!.size.height), height: infoLbl.frame.height)
        let attachmentString = NSAttributedString(attachment: attachment)
        let completeText = NSMutableAttributedString(string: "")
        completeText.append(attachmentString)
        let textAfterIcon = NSMutableAttributedString(string: " Tap on an image to see its metadata")
        completeText.append(textAfterIcon)
        infoLbl.attributedText = completeText
    }
    
    // Setup instruction view text.
    func instructionViewSetup() -> UITextView {
        var instructionView = UITextView()
        instructionView = UITextView(frame: CGRect(x: collectionView.frame.minX + 16, y: collectionView.frame.minY + 30, width: collectionView.frame.width - 32, height: 160))
        let sentence = NSAttributedString(string: "How to use:\n1. Select images\n2. Tap an image to view metadata\n3. Adjust settings\n4. Process photos\n5. Review and edit photos")
        instructionView.attributedText = sentence
        instructionView.font = UIFont(name: "Avenir-Medium", size: 17.0)
        instructionView.isEditable = false
        instructionView.isSelectable = false
        instructionView.backgroundColor = UIColor.clear
        if #available(iOS 13, *) {
            instructionView.textColor = UIColor.label
        }
        return instructionView
    }
    
    // Show information view overlay.
    @IBAction func infoBtnAction(_ sender: Any) {
        let overlayInstructionView = instructionViewSetup()
        overlayInstructionView.font = UIFont(name: "Avenir-Medium", size: 18.0)
        infoOverlay = UIView(frame: view.frame)
        infoOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        let mainOverlay = UIView(frame: CGRect(x: view.bounds.minX + 25, y: view.bounds.minY, width: view.bounds.width - 50, height: 50 + overlayInstructionView.frame.height + 55 + 50))
        mainOverlay.center = view.center.applying(CGAffineTransform.init(scaleX: 1, y: 0.9))
        let lbl = UILabel(frame: CGRect(x: mainOverlay.bounds.minX, y: mainOverlay.bounds.minY + 5, width: mainOverlay.bounds.width, height: 30))
        lbl.attributedText = NSAttributedString(string: "Instructions")
        lbl.font = UIFont.init(name: "Avenir-Heavy", size: 20.0)
        lbl.textAlignment = .center
        mainOverlay.addSubview(lbl)
        if #available(iOS 13.0, *) {
            mainOverlay.backgroundColor = UIColor.systemGray6
        } else {
            mainOverlay.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        }
        mainOverlay.layer.cornerRadius = 12
        let dismissBtn = UIButton(frame: CGRect(x: (mainOverlay.bounds.width - 120) / 2, y: mainOverlay.bounds.maxY - 55, width: 120, height: 45))
        dismissBtn.setTitle("Dismiss", for: .normal)
        dismissBtn.titleLabel?.font = UIFont.init(name: "Avenir-Heavy", size: 18.0)
        dismissBtn.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.75)
        dismissBtn.layer.cornerRadius = 15
        dismissBtn.addTarget(self, action: #selector(removeInfoOverlay), for: .touchUpInside)
        overlayInstructionView.frame = CGRect(x: mainOverlay.bounds.minX + 5, y: lbl.frame.maxY + 20, width: mainOverlay.bounds.width - 10, height: overlayInstructionView.frame.height)
        mainOverlay.addSubview(overlayInstructionView)
        mainOverlay.addSubview(dismissBtn)
        infoOverlay.addSubview(mainOverlay)
        self.view.addSubview(infoOverlay)
    }
    
    @IBAction func removeInfoOverlay() {
        infoOverlay.removeFromSuperview()
    }
    
    func showSpinner() {
        DispatchQueue.main.async {
            print("[-] Load spinner")
            self.addChild(self.spinner)
            self.spinner.view.frame = self.view.frame
            self.view.addSubview(self.spinner.view)
            self.spinner.didMove(toParent: self)
            self.view.setNeedsDisplay()
        }
    }
    
    func removeSpinner() {
        print("[-] Remove spinner")
        DispatchQueue.main.async {
            self.spinner.willMove(toParent: nil)
            self.spinner.view.removeFromSuperview()
            self.spinner.removeFromParent()
        }
    }
    
}

extension ViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return aimMap.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("load cell #\(indexPath.item)")
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! CollectionViewCell
        cell.layer.cornerRadius = 12
        
        let aimObj = self.aimMap[self.aimOrderedIDs[indexPath.item]]!
        let pic = fetchThumbnail(asset: aimObj.asset)
        cell.displayContent(image: pic, index: indexPath.item)
        
        cell.viewMetadataTapAction = {
            self.transferMD = aimObj.metadata
            self.performSegue(withIdentifier: "metadataVC", sender: self)
        }
        
        return cell
    }
}


extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        @unknown default:
            fatalError("[-] Encountered unknown orientation.")
        }
    }
}
