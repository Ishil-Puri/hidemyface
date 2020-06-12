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

class ViewController: UIViewController, UIScrollViewDelegate {

    
    @IBOutlet weak var selectImgBtn: UIButton!
    
    @IBOutlet weak var metadataTxtView: UITextView!
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    var selectedAssets = [PHAsset]()
    var photoArray = [UIImage]()
    var mdDict: Dictionary<String, Any> = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        selectImgBtn.layer.cornerRadius = 4
    }
    
    @IBAction func selectPhotoAction(_ sender: Any) {
        let picker = ImagePickerController()
        presentImagePicker(picker, select: { (asset: PHAsset) -> Void in
        }, deselect: { (asset: PHAsset) -> Void in
            // User deselects an asset.
        }, cancel: { (assets: [PHAsset]) -> Void in
            // User cancelled selection.
        }, finish: { (assets: [PHAsset]) -> Void in
            // User finishes selection.
            for asset in assets {
                self.selectedAssets.append(asset)
            }
            self.convertAssetToImages()
        })
        
        viewMetaData()
        
    }
    
    private func convertAssetToImages() -> Void {
        if (self.selectedAssets.count != 0) {
            let manager = PHImageManager.default()
            let option = PHImageRequestOptions()
            var thumbnail = UIImage()
            option.isSynchronous = true
            
            for i in 0..<selectedAssets.count {
                manager.requestImage(for: selectedAssets[i], targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: option, resultHandler: { (result, info) -> Void in thumbnail = result!
                })
                let data = thumbnail.jpegData(compressionQuality: 0.7)
                let img = UIImage(data: data!)
                self.photoArray.append(img! as UIImage)
            }
            setupScrollView()
        }
    }
    
    private func setupScrollView() -> Void {
        for i in 0..<photoArray.count {
            let imgView = UIImageView()
            imgView.image = photoArray[i]
            let xpos = scrollView.frame.width * CGFloat(i)
            imgView.frame = CGRect(x: xpos, y:0, width: scrollView.frame.width, height: scrollView.frame.height)
            imgView.contentMode = .scaleAspectFit
            
            scrollView.contentSize.width = scrollView.frame.width * CGFloat(i + 1)
            scrollView.addSubview(imgView)
            scrollView.delegate = self
        }
    }
    
    private func viewMetaData() {
        metadataTxtView.text = mdDict.description
        for i in 0..<selectedAssets.count {
            scrollView.scrollRectToVisible(scrollView.subviews[i].frame, animated: true)
            metadataTxtView.text = "\(String(describing: selectedAssets[i].creationDate))"
            metadataTxtView.text += "DONE"
            sleep(2)
        }
    }
    
}
