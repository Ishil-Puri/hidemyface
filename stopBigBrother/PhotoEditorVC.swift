//
//  PhotoEditorVC.swift
//  stopBigBrother
//
//  Created by ip on 1/7/21.
//  Copyright © 2021 Hide My Face Inc. All rights reserved.
//

import Foundation
import UIKit
import iOSPhotoEditor

class PhotoEditorVC: UIViewController, PhotoEditorDelegate{
    
    func doneEditing(image: UIImage) {
        print("done editing")
    }
    
    func canceledEditing() {
        print("canceled editing")
    }
    
    private var annotatedImage: UIImage = UIImage()
    
    override func viewDidLoad() {
        let photoEditor = UIStoryboard(name: "PhotoEditor", bundle: Bundle(for: PhotoEditorViewController.self)).instantiateViewController(withIdentifier: "PhotoEditorViewController") as! PhotoEditorViewController

        //PhotoEditorDelegate
        photoEditor.photoEditorDelegate = self

        //The image to be edited
        photoEditor.image = annotatedImage

        //Stickers that the user will choose from to add on the image
        photoEditor.stickers.append(UIImage(named: "sticker" )!)

        //To hide controls - array of enum control
        photoEditor.hiddenControls = [.crop, .draw, .share]

        //Present the View Controller
        self.present(photoEditor, animated: true, completion: {
//            self.saveImage(image: annotatedImage, index: 0)
            print("present!")
        })
    }
    
}
