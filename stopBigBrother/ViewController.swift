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

    @IBOutlet weak var selectImgBtn: UIButton!
    
    @IBOutlet weak var processPhotosBtn: UIButton!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var settingsBtn: UIButton!
    
    //MARK - global fields
    var selectedAssets = [PHAsset]()
    var metadataArray = [Dictionary<String, Any>]()
    
    let thumbManager = PHCachingImageManager()
    let thumbOption = PHImageRequestOptions()
    
    // MARK - Segue fields
    var transferMD: Dictionary<String, Any> = Dictionary()
    
    // MARK - Settings
    var shouldBlurFaces = true
    var shouldDeleteLocation = true
    var saveAsCopy = true
    
    var latestDrawingIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // MARK - make UI nice
        selectImgBtn.layer.cornerRadius = 15
        selectImgBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        processPhotosBtn.layer.cornerRadius = 15
        processPhotosBtn.isHidden = true
        settingsBtn.layer.cornerRadius = 10
        collectionView.layer.cornerRadius = 15
        collectionView.layer.borderColor = UIColor.systemBlue.cgColor
        collectionView.layer.borderWidth = 2.0
        
        thumbOption.isSynchronous = true
        thumbOption.isNetworkAccessAllowed = true
        thumbManager.allowsCachingHighQualityImages = false
        
        configureCV()
    }
    
    override func didReceiveMemoryWarning() {
        // does not receive memory warning :(
        thumbManager.stopCachingImagesForAllAssets()
        showAlertWith(title: "Error", message: "Images are too large or numerous to be processed. Please try again in smaller batches.")
        fatalError("Exceeded memory usage")
    }
    
    @IBAction func selectPhotoAction(_ sender: Any) {
        let picker = ImagePickerController()
        var count = 0
        presentImagePicker(picker, select: { (asset: PHAsset) -> Void in
            count += 1
            if count == 15 {
                self.showAlertWith(title: "Limit Reached", message: "Maximum number of selections (15) has been reached")
            }
        }, deselect: { (asset: PHAsset) -> Void in
            // User deselects an asset.
            count -= 1
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
//            self.manager.startCachingImages(for: self.selectedAssets, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFill, options: self.option)
            
            self.collectionView.reloadData()
            self.processPhotosBtn.setTitle("process \(self.selectedAssets.count) photos", for: .normal)
            self.processPhotosBtn.isHidden = false
        })
    }
    
    private func fetchFullImage(asset: PHAsset) -> UIImage {
        var img = UIImage()
        // MARK - FIXME: Memory issues with this architecture. Will need to find workaround to avoid loading entire image into memory.
//        let timer: Timer = Timer()
//        timer.fire()
//        if(timer.timeInterval>6) {
//            self.showAlertWith(title: "Hmm", message: "This is taking longer than usual. This might be due to a slow network connection while downloading your selected photos from iCloud. You can continue to wait or manually quit the app to select a different photo.")
//        }
        let manager = PHImageManager()
        let option = PHImageRequestOptions()
        
        option.deliveryMode = .highQualityFormat
        option.isSynchronous = true
        option.isNetworkAccessAllowed = true
        option.progressHandler = { (progress, error, stop, info) in
            print("[-] progress: \(progress)")
        }

        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFill, options: option, resultHandler: { (result, info) in
            img = result!
            let data = img.jpegData(compressionQuality: 0.7)
            img = UIImage(data: data!)!
        })
        return img
    }
    
    private func fetchThumbnail(asset: PHAsset) -> UIImage {
        var resultImg: UIImage = UIImage()
        
        thumbOption.progressHandler = { (progress, error, stop, info) in
            print("[-] Thumbnail progress: \(progress)")
        }
        
        thumbManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: thumbOption, resultHandler: { (result, info) in
            resultImg = result!
            let data = resultImg.jpegData(compressionQuality: 0.7)
            resultImg = UIImage(data: data!)!
        })
        return resultImg
    }
    
    
    @IBAction func processPhotosAction(_ sender: Any) {
        for i in 0...selectedAssets.count-1 {
            print("[-] Processing #\(i)")
            processImage(index: i)
        }
    }
    
    private func processImage(index: Int) {
        let originalImg: UIImage = fetchFullImage(asset: selectedAssets[index])
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
        let image = fetchFullImage(asset: selectedAssets[captureCurrIndex])
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
                    self.finished()
                }
            })
        }
    }
    
    private func finished() {
        // Clean up + choose how to display finished process message
        self.showAlertWith(title: "\(selectedAssets.count) Saved", message: "\(selectedAssets.count) images processed and saved!")
        selectedAssets.removeAll()
        metadataArray.removeAll()
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.processPhotosBtn.isHidden = true
        }
    }
    
    func showAlertWith(title: String, message: String) {
        DispatchQueue.main.async {
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
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
        let insetSize: CGFloat = 7
        let spacing: CGFloat = 10
        let cellWidth: CGFloat = min(collectionView.frame.width/2 - insetSize - spacing/2, 200)
        let cellHeight: CGFloat = min(collectionView.frame.height/2.5 - spacing/2, 250)
        let cellSize = CGSize(width: cellWidth, height: cellHeight)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = cellSize
        layout.sectionInset = UIEdgeInsets(top: insetSize, left: insetSize, bottom: insetSize, right: insetSize)
        layout.minimumLineSpacing = spacing
        layout.minimumInteritemSpacing = spacing
        collectionView.setCollectionViewLayout(layout, animated: true)
        
        collectionView.reloadData()
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
