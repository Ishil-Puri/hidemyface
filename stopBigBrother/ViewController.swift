//
//  ViewController.swift
//  stopBigBrother
//
//  Created by ip on 6/10/20.
//  Copyright © 2020 The Brotherhood Inc. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {

    private let cellID = "CellID"
    
    public var imagePickerController: UIImagePickerController?
    
    public var refUrl: Any?
    
    var fetchResult: PHFetchResult<PHAsset>!
    
    @IBOutlet weak var selectImgBtn: UIButton!
    
    @IBOutlet weak var metadataTxtView: UITextView!
    
    @IBOutlet weak var selectedImageView: UIImageView!
    
    @IBOutlet weak var galleryCollectionView: UICollectionViewCell!
    
    internal var selectedImage: UIImage? {
        get {
            return self.selectedImageView.image
        }
        set {
            switch newValue {
            case nil:
                self.selectedImageView.image = nil
            default:
                self.selectedImageView.image = newValue
            }
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        selectImgBtn.layer.cornerRadius = 4
        
        fetchAssets()
        
    }
    
    private func setupCollectionView() {
//        galleryCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: cellID)
    }
    
    private func fetchAssets() {
        fetchResult = PHAsset.fetchAssets(with: .ascendingOptions)
    }


    
    @IBAction func selectPhotoAction(_ sender: Any) {
        
        if self.imagePickerController != nil {
            self.imagePickerController?.delegate = nil
            self.imagePickerController = nil
        }
        
        self.imagePickerController = UIImagePickerController.init()
        
        let alert = UIAlertController.init(title: "Select Source", message: nil, preferredStyle: .actionSheet)
        
        if UIImagePickerController.isSourceTypeAvailable((.camera)) {
            alert.addAction(UIAlertAction.init(title: "Camera", style: .default, handler: {(_) in
                self.presentImagePicker(controller: self.imagePickerController!, source: .camera)
            }))
        }

        if UIImagePickerController.isSourceTypeAvailable((.photoLibrary)) {
            alert.addAction(UIAlertAction.init(title: "Photo Library", style: .default, handler: {(_) in
                self.presentImagePicker(controller: self.imagePickerController!, source: .photoLibrary)
            }))
        }
        
        if UIImagePickerController.isSourceTypeAvailable((.savedPhotosAlbum)) {
            alert.addAction(UIAlertAction.init(title: "Saved Albums", style: .default, handler: {(_) in
                self.presentImagePicker(controller: self.imagePickerController!, source: .savedPhotosAlbum)
            }))
        }
        
        alert.addAction(UIAlertAction.init(title: "Cancel", style: .cancel))
        
        self.present(alert, animated: true)
        
    }
    
    internal func presentImagePicker(controller: UIImagePickerController, source: UIImagePickerController.SourceType) {
        controller.delegate = self
        controller.sourceType = source
        self.present(controller, animated: true)
    }
    
}


extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
            return self.imagePickerControllerDidCancel(picker)
        }
        
        self.selectedImage = image
        
        self.refUrl = info[UIImagePickerController.InfoKey.referenceURL] as? URL
        
        NSLog("Image Url: \(String(describing: refUrl))")
        
        picker.dismiss(animated: true) {
            picker.delegate = nil
            self.imagePickerController = nil
        }
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            picker.delegate = nil
            self.imagePickerController = nil
        }
    }
}

extension PHFetchOptions {
    static var ascendingOptions: PHFetchOptions = {
        let option = PHFetchOptions()
        option.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        return option
    }()
}
