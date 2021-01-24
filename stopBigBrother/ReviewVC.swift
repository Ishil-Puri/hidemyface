//
//  ReviewVC.swift
//  stopBigBrother
//
//  Created by ip on 1/9/21.
//  Copyright © 2021 Hide My Face Inc. All rights reserved.
//

import Foundation
import UIKit
import Photos
import iOSPhotoEditor

class ReviewVC: UIViewController, PhotoEditorDelegate {
    
    var receiveAimMap = Dictionary<String, Aim>()
    var receiveAimOrderedIDs = [String]()
    var segueSettings: Dictionary<String, Any> = Dictionary()
    var numberOfSavedImages = 0
    var spinner = SpinnerViewController()
    
    @IBOutlet weak var skipBtn: UIButton!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var editBtn: UIButton!
    @IBOutlet weak var trashBtn: UIButton!
    @IBOutlet weak var acceptBtn: UIButton!
    @IBOutlet weak var exitBtn: UIButton!
    @IBOutlet weak var hStack: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        skipBtn.layer.cornerRadius = 15
        imgView.layer.cornerRadius = 15
        imgView.contentMode = .scaleAspectFill
        imgView.layer.borderWidth = 2.5
        imgView.layer.borderColor = UIColor.white.cgColor.copy(alpha: 0.8)
        hStack.layoutMargins = UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 40)
        hStack.isLayoutMarginsRelativeArrangement = true
        self.setNextImage()
        
        if #available(iOS 12, *) {
            if traitCollection.userInterfaceStyle == .light {
                imgView.layer.borderColor = UIColor.black.cgColor.copy(alpha: 0.8)
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 12, *) {
            if traitCollection.userInterfaceStyle == .light {
                imgView.layer.borderColor = UIColor.black.cgColor.copy(alpha: 0.8)
            } else {
                imgView.layer.borderColor = UIColor.white.cgColor.copy(alpha: 0.8)
            }
        }
    }
    
    func setNextImage() {
        if receiveAimOrderedIDs.isEmpty {
            exitBtn.sendActions(for: .touchUpInside)
        } else {
            imgView.image = receiveAimMap[receiveAimOrderedIDs.first!]!.image
        }
    }
    
    @IBAction func trashAction(_ sender: Any) {
        let index = receiveAimOrderedIDs.removeFirst()
        receiveAimMap.removeValue(forKey: index)
        setNextImage()
    }
    
    @IBAction func editAction(_ sender: Any) {
        // do editing stuff and store image again
        let photoEditor = PhotoEditorViewController(nibName:"PhotoEditorViewController", bundle: Bundle(for: PhotoEditorViewController.self))

        //PhotoEditorDelegate
        photoEditor.photoEditorDelegate = self

        //The image to be edited
        photoEditor.image = receiveAimMap[receiveAimOrderedIDs.first!]!.image

        //Stickers that the user will choose from to add on the image
        photoEditor.stickers.append(UIImage(named: "sticker")!)

        //Optional: To hide controls - array of enum control
        photoEditor.hiddenControls = [.save, .text, .crop]

        //Optional: Colors for drawing and Text, If not set default values will be used
        photoEditor.colors = [.black]

        photoEditor.modalPresentationStyle = .fullScreen
        //Present the View Controller
        present(photoEditor, animated: true, completion: nil)
    }
    
    func doneEditing(image: UIImage) {
        receiveAimMap[receiveAimOrderedIDs.first!]!.image = image
        imgView.image = image
    }
    func canceledEditing() {}
    
    @IBAction func acceptAction(_ sender: Any) {
        showSpinner()
        saveNextImage(recursive: false)
        setNextImage()
    }
    
    @IBAction func skipAction(_ sender: Any) {
        showSpinner()
        saveNextImage(recursive: true)
    }
    
    private func saveNextImage(recursive: Bool){
        numberOfSavedImages += 1
        let index = receiveAimOrderedIDs.removeFirst()
        if(segueSettings["save"] as! Bool) {
            let aimObj = receiveAimMap[index]!
            PHPhotoLibrary.shared().performChanges({ [self] in
                let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: aimObj.image)
                if(!(segueSettings["delete"] as! Bool)){
                    creationRequest.location = aimObj.metadata["location"] as? CLLocation
                }
            }, completionHandler: { [self] success, error in
                if !success {
                    print("Error creating asset: \(String(describing: error))")
                }
                receiveAimMap.removeValue(forKey: index)
                if(recursive) {
                    if(receiveAimOrderedIDs.isEmpty) {
                        removeSpinner()
                        DispatchQueue.main.sync {
                            exitBtn.sendActions(for: .touchUpInside)
                        }
                    } else {
                        saveNextImage(recursive: recursive)
                    }
                } else {
                    removeSpinner()
                    DispatchQueue.main.async {
                        setNextImage()
                    }
                }
            })
        }
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
