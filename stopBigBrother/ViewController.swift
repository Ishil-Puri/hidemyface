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

class ViewController: UIViewController {

    @IBOutlet weak var selectImgBtn: UIButton!
    
    @IBOutlet weak var viewMetadataBtn: UIButton!
    
    @IBOutlet weak var imgView: UIImageView!
    
    @IBOutlet weak var settingsBtn: UIButton!
    
    var selectedAssets = [PHAsset]()
    var photoArray = [UIImage]()
    var metadataTemp: String = ""
    var mdDict: Dictionary<String, Any> = Dictionary()
    
    // MARK - Settings
    var shouldBlurFaces = true
    var shouldDeleteLocation = true
    var saveAsCopy = true
   
    // Image parameters for reuse throughout app
//    var imageWidth: CGFloat = 0
//    var imageHeight: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        selectImgBtn.layer.cornerRadius = 15
        selectImgBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        viewMetadataBtn.layer.cornerRadius = 15
        viewMetadataBtn.isHidden = true
        settingsBtn.layer.cornerRadius = 10
    }
    
    @IBAction func selectPhotoAction(_ sender: Any) {
        selectedAssets.removeAll()
        photoArray.removeAll()
        let picker = ImagePickerController()
        presentImagePicker(picker, select: { (asset: PHAsset) -> Void in
        }, deselect: { (asset: PHAsset) -> Void in
            // User deselects an asset.
        }, cancel: { (assets: [PHAsset]) -> Void in
            // User cancelled selection.
        }, finish: { (assets: [PHAsset]) -> Void in
            // User finishes selection.
            let prevSize = self.selectedAssets.count
            for asset in assets {
                self.selectedAssets.append(asset)
            }
            self.convertAssetToImages(prevSize:prevSize)
            self.displayMetaData()
            self.viewMetadataBtn.isHidden = false
        })
    }
    
    private func convertAssetToImages(prevSize: Int) -> Void {
        if (self.selectedAssets.count != 0) {
            let manager = PHImageManager.default()
            let option = PHImageRequestOptions()
            var img = UIImage()
            
            let timer: Timer = Timer()
            timer.fire()
            
            option.isSynchronous = true
            option.isNetworkAccessAllowed = true
            
            option.progressHandler = { (progress, error, stop, info) in
                print("progress: \(progress)")
            }
            
            for i in prevSize..<selectedAssets.count {
                timer.fire()
                manager.requestImage(for: selectedAssets[i], targetSize: PHImageManagerMaximumSize, contentMode: .aspectFill, options: option, resultHandler: { (result, info) in
                    img = result!
                    if(timer.timeInterval>10) {
                        self.showAlertWith(title: "Hmm", message: "This is taking longer than usual. This might be due to a slow network connection while downloading your selected photos from iCloud. You can continue to wait or manually quit the app to select a different photo.")
                    }
                    print("image #: \(String(describing: i))")
                    print("dict: \(String(describing: info))")
                })
                let data = img.jpegData(compressionQuality: 0.7)
                let compressedImg = UIImage(data: data!)
                self.photoArray.append(compressedImg! as UIImage)
                
//                processImage(originalImg: photoArray[i])
            }
            timer.invalidate()
        }
    }
    
    private func processImage(i: Int) {
        let originalImg: UIImage = photoArray[i]
        let originalAsset: PHAsset = selectedAssets[i]
        
        // Check settings
        
        if (shouldBlurFaces) {
            // process occurs per image
            let sequenceHandler = VNSequenceRequestHandler()
            let detectFaceRequest = VNDetectFaceRectanglesRequest(completionHandler: detectedFace)
            do {
                try sequenceHandler.perform([detectFaceRequest], on: originalImg.cgImage!, orientation: CGImagePropertyOrientation(originalImg.imageOrientation))
            } catch {
                print(error.localizedDescription)
            }
        }
        
        if (!shouldDeleteLocation) {
            // Get last image saved and add location from original data to new image
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
            fetchOptions.fetchLimit = 1
            let fetchResult: PHFetchResult = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: fetchOptions)
            
            if fetchResult.count > 0 {
                setLocationMetadata(asset: fetchResult[0], location: originalAsset.location)
            } else {
                print("Couldn't find latest photo asset")
            }
        }
        
        // MARK - Adjust metadata as necessary
        
    }
    
    private func detectedFace(request: VNRequest, error: Error?) {
        print("Woot, we've arrived at the completion handler")
        guard let results = request.results as? [VNFaceObservation]
            else {
                // TODO: Create advanced error handling, show a report of images unable to be processed
                print("Encountered error when retrieving results array")
                return
        }
        DispatchQueue.main.async {
            print("Woot, we are now drawing bounding boxes around \(results.count) faces")
            self.draw(faces: results)
            self.imgView.setNeedsDisplay()
        }
    }
    
    private func draw(faces: [VNFaceObservation]) {
        let latestIndex: Int = self.photoArray.count - 1
        var faceBoxes: [CGRect] = [CGRect.zero]
        
        UIGraphicsBeginImageContext(self.photoArray[latestIndex].size)
        self.photoArray[latestIndex].draw(at: CGPoint.zero)
        let context = UIGraphicsGetCurrentContext()!
        context.setLineWidth(4.0)
        context.setStrokeColor(UIColor.red.cgColor)
        
        faces.forEach{ face in
            faceBoxes.append(face.boundingBox.applying(CGAffineTransform(scaleX: CGFloat(context.width), y: CGFloat(context.height))))
        }
        
        context.addRects(faceBoxes)
        
        context.strokePath()
        guard let annotatedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("Unable to grab annotated image.")
            return
        }
        
        UIGraphicsEndImageContext()
        
        self.imgView.image = annotatedImage
        
        self.saveImage(image: annotatedImage)
    }
    
    
    private func saveImage(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // Error when saving
            showAlertWith(title: "Save error", message: error.localizedDescription)
            
        } else {
            showAlertWith(title: "Saved!", message: "Your image has been secured and saved as a copy to your photos.")
        }
    }
    
    func showAlertWith(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
    
    private func displayMetaData() {
        // FIXME - only uses last asset
        metadataTemp = getMetadata(asset: selectedAssets[selectedAssets.count - 1])
//        for i in 0..<selectedAssets.count {
//            imgView.image = photoArray[i]
//        }
    }
    
    private func setLocationMetadata(asset: PHAsset, location: CLLocation?) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest(for: asset).setValue(location, forKey: "location")
//                PHAssetChangeRequest(for: self.selectedAssets[i]).setValue(Date.init(timeIntervalSinceNow: 0), forKey: "creationDate") # adjusts creation date
        }, completionHandler: { (success, error) in
            if success {
            } else {
                print("Error Saving Edits:", error?.localizedDescription ?? "Unknown Error")
            }
        })
    }
    
    
    private func getMetadata(asset: PHAsset) -> String{
        let mediaType = "\(asset.mediaType)"
        let date = asset.creationDate
            != nil ? " \(asset.creationDate!)" : "No date info found :("
        let mediaSubtypes = "\(asset.mediaSubtypes)"
        let sourceType = asset.sourceType
        let location = asset.location != nil ? " \(asset.location!)" : "No Location info found :("
//        let isFavorite = asset.isFavorite
//        let isHidden = asset.isHidden
        let dimensions = "\(asset.pixelWidth)x\(asset.pixelHeight)"
        let modificationDate = asset.modificationDate
        != nil ? " \(asset.modificationDate!)" : "No modification date info found :("
        
        mdDict["location"] = asset.location
        mdDict["creation date"] = asset.creationDate
        
        return "Media Type: \(mediaType)\nMedia Subtype: \(mediaSubtypes)\nCreation Date: \(date)\nSource Type: \(sourceType)\nLocation: \(location)\nDimensions: \(dimensions)\nLast Modified: \(modificationDate)"
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
            vc.receiveMD = metadataTemp
            vc.location = mdDict["location"] as? CLLocation
        } else if segue.identifier == "settingsVC" {
            let vc = segue.destination as! settingsVC
            vc.segueSettings["delete"] = shouldDeleteLocation
            vc.segueSettings["blur"] =  shouldBlurFaces
            vc.segueSettings["save"] = saveAsCopy
        }
    }
    
    
//    private func setupScrollView(prevSize: Int) -> Void {
//        for i in prevSize..<photoArray.count {
//            let imgView = UIImageView()
//            imgView.image = photoArray[i]
//            let xpos = scrollView.frame.width * CGFloat(i)
//            imgView.frame = CGRect(x: xpos, y:0, width: scrollView.frame.width, height: scrollView.frame.height)
//            imgView.contentMode = .scaleAspectFit
//
//            scrollView.contentSize.width = scrollView.frame.width * CGFloat(i + 1)
//            scrollView.addSubview(imgView)
//            scrollView.delegate = self
//        }
//        displayMetaData()
//    }
    
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
