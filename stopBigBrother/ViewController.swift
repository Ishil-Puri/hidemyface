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
    
    @IBOutlet weak var stackView: UIStackView!
    
    var selectedAssets = [PHAsset]()
    var photoArray = [UIImage]()
    var mdDict: Dictionary<String, Any> = [:]
    var metadataTemp: String = ""
    
    // Layer into which to draw bounding box paths.
    var pathLayer: CALayer?
   
    // Image parameters for reuse throughout app
    var imageWidth: CGFloat = 0
    var imageHeight: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        selectImgBtn.layer.cornerRadius = 15
        selectImgBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        viewMetadataBtn.layer.cornerRadius = 15
        viewMetadataBtn.isHidden = true
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
        })
        viewMetadataBtn.isHidden = false
    }
    
    private func convertAssetToImages(prevSize: Int) -> Void {
        if (self.selectedAssets.count != 0) {
            let manager = PHImageManager.default()
            let option = PHImageRequestOptions()
            var thumbnail = UIImage()
            option.isSynchronous = true
            for i in prevSize..<selectedAssets.count {
                manager.requestImage(for: selectedAssets[i], targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: option, resultHandler: { (result, info) -> Void in thumbnail = result!
                })
                let data = thumbnail.jpegData(compressionQuality: 0.7)
                let img = UIImage(data: data!)
                self.photoArray.append(img! as UIImage)
            }
            displayMetaData()
//            setupScrollView(prevSize:prevSize)
        }
    }
    

    
    private func displayMetaData() {
        for i in 0..<selectedAssets.count {
            faceDetection(image: photoArray[i])
            imgView.image = photoArray[i]
            metadataTemp = getMetadata(asset: selectedAssets[i])
//            deleteMetadata()
        }
    }
    
    private func deleteMetadata() {
        PHPhotoLibrary.shared().performChanges({
            for i in 0..<self.selectedAssets.count {
                PHAssetChangeRequest(for: self.selectedAssets[i]).setValue(nil, forKey: "location")
//                PHAssetChangeRequest(for: self.selectedAssets[i]).setValue(Date.init(timeIntervalSinceNow: 0), forKey: "creationDate")
            }
        }, completionHandler: { (success, error) in
            if success {
            } else {
                print("Error Saving Edits:", error?.localizedDescription ?? "Unknown Error")
            }
        })
    }
    func show(_ image: UIImage) {
        
        // Remove previous paths & image
        pathLayer?.removeFromSuperlayer()
        pathLayer = nil
        imgView.image = nil
        
        // Account for image orientation by transforming view.
        let correctedImage = scaleAndOrient(image: image)
        
        // Place photo inside imgView.
        imgView.image = correctedImage
        
        // Transform image to fit screen.
        guard let cgImage = correctedImage.cgImage else {
            print("Trying to show an image not backed by CGImage!")
            return
        }
        
        let fullImageWidth = CGFloat(cgImage.width)
        let fullImageHeight = CGFloat(cgImage.height)
        
        let imageFrame = imgView.frame
        let widthRatio = fullImageWidth / imageFrame.width
        let heightRatio = fullImageHeight / imageFrame.height
        
        // ScaleAspectFit: The image will be scaled down according to the stricter dimension.
        let scaleDownRatio = max(widthRatio, heightRatio)
        
        // Cache image dimensions to reference when drawing CALayer paths.
        imageWidth = fullImageWidth / scaleDownRatio
        imageHeight = fullImageHeight / scaleDownRatio
        
        // Prepare pathLayer to hold Vision results.
        let xLayer = (imageFrame.width - imageWidth)
        let yLayer = (imageFrame.height - imageHeight + 90)
        let drawingLayer = CALayer()
        drawingLayer.bounds = CGRect(x: xLayer, y: yLayer, width: imageWidth, height: imageHeight)
        drawingLayer.anchorPoint = CGPoint.zero
        drawingLayer.position = CGPoint(x: xLayer, y: yLayer)
        drawingLayer.opacity = 0.5
        pathLayer = drawingLayer
        self.view.layer.addSublayer(pathLayer!)
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
        
        return "Media Type: \(mediaType)\nMedia Subtype: \(mediaSubtypes)\nCreation Date: \(date)\nSource Type: \(sourceType)\nLocation: \(location)\nDimensions: \(dimensions)\nLast Modified: \(modificationDate)"
    }
    
    
    private func faceDetection(image: UIImage) {
        // Send vision request with chosen photo.
        guard let cgImage = image.cgImage else {
            print("UIImage has no CGImage backing it!")
            return
        }
        show(image)
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        performVisionRequest(image: cgImage, orientation: orientation)
    }
    
    fileprivate func handleDetectedFaces(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            self.presentAlert("Face Detection Error", error: nsError)
            return
        }
        // Perform frawing on main thread.
        DispatchQueue.main.async {
            guard let drawLayer = self.pathLayer, let results = request?.results as? [VNFaceObservation] else {
                return
            }
            self.draw(faces: results, onImageWithBounds: drawLayer.bounds)
            drawLayer.setNeedsDisplay()
        }
    }
    
    fileprivate func performVisionRequest(image: CGImage, orientation: CGImagePropertyOrientation) {
        
        let requests = createVisionRequests()
        
        let imageRequestHandler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        // Send the requests to request handler
        DispatchQueue.global(qos: .userInitiated).async {
            do{
                try imageRequestHandler.perform(requests)
            } catch let error as NSError {
                print("Failed to perform image request: \(error)")
                self.presentAlert("Image Request Failed", error: error)
                return
            }
        }
    }
    
    /// - Tag: CreateRequests
    fileprivate func createVisionRequests() -> [VNRequest] {
        
        // Create an array to collect all desired requests.
        var requests: [VNRequest] = []
        // Break rectangle & face landmark detection into 2 stages to have more fluid feedback in UI.
        requests.append(self.faceDetectionRequest)
//        requests.append(self.faceLandmarkRequest)
        
        // Return grouped requests as a single array.
        return requests
    }
    
    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleDetectedFaces)
    
    // Mark - Helper Functions
    
    fileprivate func draw(faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        for observation in faces {
            let faceBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
            let faceLayer = shapeLayer(color: .yellow, frame: faceBox)
            
            // Add to pathLayer on top of image.
            pathLayer?.addSublayer(faceLayer)
        }
        CATransaction.commit()
    }
    
    fileprivate func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer{
        // Create new layer.
        let layer = CAShapeLayer()
        
        // Config. layer appearance.
        layer.fillColor = nil // No fill
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.borderWidth = 2
        
        // Set line color based on parameter.
        layer.borderColor = color.cgColor
        
        // Locate layer.
        layer.anchorPoint = .zero
        layer.frame = frame
        layer.masksToBounds = true
        
        // Transform layer to same coordinate system as imgView underneath it
        layer.transform = CATransform3DMakeScale(-1, -1, 1)
        
        return layer
    }
    
    fileprivate func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
        
        let imageWidth = bounds.width
        let imageHeight = bounds.height
        
        // Begin with input rect.
        var rect = forRegionOfInterest
        
        // Repositioning origin.
        rect.origin.x *= imageWidth
        rect.origin.x += bounds.origin.x
        rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
        
        // Rescale rect with new basis
        rect.size.width *= imageWidth
        rect.size.height *= imageHeight
        
        return rect
    }

    func presentAlert(_ title: String, error: NSError) {
        // Always present alert on main thread.
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title,
                                                    message: error.localizedDescription,
                                                    preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK",
                                         style: .default) { _ in
                                            // Do nothing -- simply dismiss alert.
            }
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    
    func scaleAndOrient(image: UIImage) -> UIImage {
        
        // Set a default value for limiting image size.
        let maxResolution: CGFloat = 640
        
        guard let cgImage = image.cgImage else {
            print("UIImage has no CGImage backing it!")
            return image
        }
        
        // Compute parameters for transform.
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
//        var transform = CGAffineTransform.identity
        
        var bounds = CGRect(x: 0, y: 0, width: width, height: height)
        
        if width > maxResolution ||
            height > maxResolution {
            let ratio = width / height
            if width > height {
                bounds.size.width = maxResolution
                bounds.size.height = round(maxResolution / ratio)
            } else {
                bounds.size.width = round(maxResolution * ratio)
                bounds.size.height = maxResolution
            }
        }
        
        let scaleRatio = bounds.size.width / width
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        
        return UIGraphicsImageRenderer(size: bounds.size).image { rendererContext in
            let context = rendererContext.cgContext
            
            if orientation == .right || orientation == .left {
                context.scaleBy(x: -scaleRatio, y: scaleRatio)
                context.translateBy(x: -height, y: 0)
            } else {
                context.scaleBy(x: scaleRatio, y: -scaleRatio)
                context.translateBy(x: 0, y: -height)
            }
//            context.concatenate(transform)
            context.draw(cgImage, in: CGRect(x: imgView.frame.minX, y: imgView.frame.minY, width: width, height: height))
        }
    }
    
    @IBAction func unwindToMain(_ unwindSegue: UIStoryboardSegue) {
        let sourceViewController = unwindSegue.source
        // Use data from the view controller which initiated the unwind segue
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print(segue.identifier!)
        if segue.identifier == "metadataVC" {
            print("Visited")
            let vc = segue.destination as! metadataVC
            vc.receiveMD = metadataTemp
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
        }
    }
}
