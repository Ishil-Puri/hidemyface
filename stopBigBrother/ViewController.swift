//
//  ViewController.swift
//  stopBigBrother
//
//  Created by ip on 6/10/20.
//  Copyright © 2020 The Brotherhood Inc. All rights reserved.
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
    
    // MARK - Global fields
    var selectedAssets = [PHAsset]()
    var metadataArray = [Dictionary<String, Any>]()
    var imageArray = [UIImage]()
    var latestDrawingIndex = 0
    
    let thumbManager = PHCachingImageManager()
    let thumbOption = PHImageRequestOptions()
    var spinner = SpinnerViewController()
    
    var clearSelectionBtn = UIButton()
    var instructionView = UIImageView()
    
    // MARK - Segue fields
    var transferMD: Dictionary<String, Any> = Dictionary()
    
    // MARK - Settings
    var shouldBlurFaces = true
    var shouldDeleteLocation = true
    var saveAsCopy = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // MARK - Make UI nice
        logoImgView.layer.cornerRadius = 2
        setInfoLabel()
        infoLbl.isHidden = true
        selectImgBtn.layer.cornerRadius = 15
        selectImgBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        processPhotosBtn.layer.cornerRadius = 15
        processPhotosBtn.isHidden = true
        settingsBtn.layer.cornerRadius = 10
        collectionView.layer.cornerRadius = 15
        
        let hasDisplayedInstructions = instructionView.image != nil
        instructionView = UIImageView(frame: CGRect(x: collectionView.frame.minX + 16, y: collectionView.frame.minY + 30, width: collectionView.frame.width - 32, height: 100))
        instructionView.image = UIImage(named: "app-instructions-light")
        instructionView.contentMode = .scaleAspectFit

        collectionView.layer.borderColor = UIColor.black.cgColor.copy(alpha: 0.8)
        if #available(iOS 12, *) {
            if traitCollection.userInterfaceStyle == .dark {
                collectionView.layer.borderColor = UIColor.white.cgColor.copy(alpha: 0.8)
                instructionView.image = UIImage(named: "app-instructions-dark")
            }
        }
        if !hasDisplayedInstructions {
            collectionView.addSubview(instructionView)
        }
        
        collectionView.layer.borderWidth = 2.0
        
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
                instructionView.image = UIImage(named: "app-instructions-dark")
                setClearBtnText(darkMode: true)
            } else {
                collectionView.layer.borderColor = UIColor.black.cgColor.copy(alpha: 0.8)
                instructionView.image = UIImage(named: "app-instructions-light")
                setClearBtnText(darkMode: false)
            }
        } else {
            collectionView.layer.borderColor = UIColor.black.cgColor.copy(alpha: 0.8)
            instructionView.image = UIImage(named: "app-instructions-light")
            setClearBtnText(darkMode: false)
        }
    }
    
    override func didReceiveMemoryWarning() {
        // Attempt to recover if encountered memory issue.
        print("[-] Received Memory Warning")
        cleanUp(showMessage: false)
        thumbManager.stopCachingImagesForAllAssets()
        showAlertWith(title: "Error: Out of Memory", message: "Images are too large or numerous to be processed. Please try again later.", transfer: false)
//        fatalError("Exceeded memory usage")
    }
    
    @IBAction func selectPhotoAction(_ sender: Any) {
        if PHPhotoLibrary.authorizationStatus() == .denied {
            showAlertWith(title: "Access required...", message: "Please grant access to your photo library in Settings app to continue.", transfer: false)
            return
        }
        let picker = ImagePickerController()
        picker.settings.selection.max = 10 - selectedAssets.count
        presentImagePicker(picker, select: { (asset: PHAsset) -> Void in
            // User selects an asset.
        }, deselect: { (asset: PHAsset) -> Void in
            // User deselects an asset.
        }, cancel: { (assets: [PHAsset]) -> Void in
            // User cancelled selection.
        }, finish: { (assets: [PHAsset]) -> Void in
            // User finishes selection.
            for asset in assets {
                let exists = self.selectedAssets.contains { element in element.localIdentifier==asset.localIdentifier }
                if !exists {
                    self.selectedAssets.append(asset)
                    self.metadataArray.append(self.getMetadata(asset: asset))
                }
            }
            self.thumbManager.startCachingImages(for: self.selectedAssets, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: self.thumbOption)
            self.collectionView.reloadData()
            self.processPhotosBtn.setTitle("process \(self.selectedAssets.count) photos", for: .normal)
            
            self.instructionView.removeFromSuperview()
            self.infoLbl.isHidden = false
            self.processPhotosBtn.isHidden = false
            self.selectImgBtn.setTitle("add images", for: .normal)
            if !self.clearSelectionBtn.isDescendant(of: self.view) {
                self.addClearSelectionBtn()
            }
        })
    }
    
    private func fetchFullImage(asset: PHAsset) -> Bool {
        print("Fetching image: \(asset.localIdentifier)")
        var img = UIImage()
        var success = true
        // MARK - FIXME: Memory issues reduced but present with current architecture (meanwhile, image selection limit is capped).
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
            let data = img.jpegData(compressionQuality: 0.65)
            img = UIImage(data: data!)!
            self.imageArray.append(img)
        })
        return success
    }
    
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
    
    private func downloadImages() -> Bool {
        var success = true
        self.selectedAssets.forEach { asset in
            if !self.fetchFullImage(asset: asset) {
                let failedIndex = selectedAssets.firstIndex(of: asset)
                cleanUp(showMessage: false)
                showAlertWith(title: "Unable to get image", message: "Could not retrieve image (#\(failedIndex ?? -1)). Please check your network connection and/or iPhone storage capacity.", transfer: false)
                success = false
                return
            }
        }
        // return download successful boolean?
        return success
    }
    
    @IBAction func processPhotosAction(_ sender: Any) {
        clearSelectionBtn.removeFromSuperview()
        self.showSpinner()
        DispatchQueue.global(qos: .background).async {
            if !self.downloadImages() {
                return
            }
            DispatchQueue.main.async {
                for i in 0...self.selectedAssets.count-1 {
                    print("[-] Processing #\(i)")
                    self.processImage(index: i)
                }
            }
        }
    }
    
    private func processImage(index: Int) {
        let originalImg: UIImage = imageArray[index]
        self.latestDrawingIndex = index
        let sequenceHandler = VNSequenceRequestHandler()
        let detectFaceRequest = VNDetectFaceRectanglesRequest(completionHandler: detectedFace)
        do {
            try sequenceHandler.perform([detectFaceRequest], on: originalImg.cgImage!, orientation: CGImagePropertyOrientation(originalImg.imageOrientation))
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func detectedFace(request: VNRequest, error: Error?) {
        print("Woot, we've arrived at the completion handler")
        guard var results = request.results as? [VNFaceObservation]
            else {
                // TODO: Create advanced error handling, show a report of images unable to be processed
                print("Encountered error when retrieving results array")
                return
        }
        let capIndex = self.latestDrawingIndex
        DispatchQueue.main.async {
            if !self.shouldBlurFaces {
                results = []
                print("Will not blur faces due to settings.")
            } else {
                print("Woot, we are now drawing bounding boxes around \(results.count) faces")
            }
            let annotatedImage = self.draw(faces: results, captureCurrIndex: capIndex)
            self.saveImage(image: annotatedImage, index: capIndex)
            print("[-] Saving photo # \(capIndex)")
        }
    }

    private func draw(faces: [VNFaceObservation], captureCurrIndex: Int) -> UIImage{
        var faceBoxes: [CGRect] = []
        let image = imageArray[captureCurrIndex]
        imageArray[captureCurrIndex] = UIImage()
        print("[-] index: \(captureCurrIndex)")
        
        let renderedImage = UIGraphicsImageRenderer(size: image.size).image { (rendererContext) in
            image.draw(at: CGPoint.zero)
            faces.forEach{ face in
                faceBoxes.append(face.boundingBox.applying(CGAffineTransform(scaleX: CGFloat(image.size.width), y: -CGFloat(image.size.height))).applying(CGAffineTransform(translationX: 0, y: CGFloat(image.size.height))))
            }
            faceBoxes.forEach { box in
                rendererContext.fill(box)
            }
        }
        print("Done drawing, size: \(renderedImage.size)")
        return renderedImage
    }
    
    private func saveImage(image: UIImage, index: Int) {
        if saveAsCopy {
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if !self.shouldDeleteLocation {
                    creationRequest.location = self.metadataArray[index]["location"] as? CLLocation
                }
            }, completionHandler: { success, error in
                if !success {
                    print("Error creating asset: \(String(describing: error))")
                }
                if index == self.selectedAssets.count - 1 {
                    self.cleanUp(showMessage: true)
                }
            })
        } else {
            // MARK – implement later: save as changes to original image
        }
    }
    
    private func cleanUp(showMessage: Bool) {
        // Clean up + choose how to display finished process message
        removeSpinner()
        if showMessage {
            self.showAlertWith(title: "\(selectedAssets.count) Saved", message: "\(selectedAssets.count) images processed and saved!", transfer: true)
        }
        selectedAssets.removeAll()
        metadataArray.removeAll()
        imageArray.removeAll()
        DispatchQueue.main.async {
            self.selectImgBtn.setTitle("select images", for: .normal)
            self.collectionView.reloadData()
            self.infoLbl.isHidden = true
            self.processPhotosBtn.isHidden = true
            self.clearSelectionBtn.removeFromSuperview()
        }
    }
    
    func showAlertWith(title: String, message: String, transfer: Bool) {
        DispatchQueue.main.async {
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                if transfer {
                    UIApplication.shared.open(URL(string: "photos-redirect://")!)
                }
            }))
            self.present(ac, animated: true)
        }
    }
    
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
    
    @IBAction func unwindToMain(_ unwindSegue: UIStoryboardSegue) {
        let sender = unwindSegue.source
        if sender is settingsVC {
            if let senderVC = sender as? settingsVC {
                shouldDeleteLocation = senderVC.deleteLocationSwitch.isOn
                shouldBlurFaces = senderVC.blurFacesSwitch.isOn
                saveAsCopy = senderVC.saveAsCopySwitch.isOn
            }
        }
        // Use data from the view controller which initiated the unwind segue
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("Time to segue with: '\(segue.identifier!)'")
        if segue.identifier == "metadataVC" {
            let vc = segue.destination as! metadataVC
            vc.receiveMD = transferMD
        } else if segue.identifier == "settingsVC" {
            let vc = segue.destination as! settingsVC
            vc.segueSettings["delete"] = shouldDeleteLocation
            vc.segueSettings["blur"] =  shouldBlurFaces
            vc.segueSettings["save"] = saveAsCopy
        }
    }
    
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
    
    fileprivate func addClearSelectionBtn(){
        print("[–] Adding clear selection btn")
        clearSelectionBtn = UIButton(frame: CGRect(x: collectionView.frame.minX, y: collectionView.frame.maxY, width: 50, height: 40)) // utilized in setClearBtnText()
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
    
    // Sets attributed text for info label
    func setInfoLabel() {
        print("[–] Add info label")
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
        return selectedAssets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("load cell #\(indexPath.item)")
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! CollectionViewCell
        cell.layer.cornerRadius = 12
        
        let pic = fetchThumbnail(asset: selectedAssets[indexPath.item])
        cell.displayContent(image: pic, index: indexPath.item)
        
        cell.viewMetadataTapAction = {
            self.transferMD = self.metadataArray[cell.index]
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
