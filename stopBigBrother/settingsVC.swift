//
//  settingsVC.swift
//  stopBigBrother
//
//  Created by ip on 6/28/20.
//  Copyright © 2020 Hide My Face Inc. All rights reserved.
//

import UIKit
import BuyMeACoffee

class settingsVC: UIViewController {
    
    @IBOutlet weak var saveBtn: UIButton!
    @IBOutlet weak var deleteLocationSwitch: UISwitch!
    @IBOutlet weak var blurFacesSwitch: UISwitch!
    @IBOutlet weak var saveAsCopySwitch: UISwitch!
    @IBOutlet weak var compressionSlider: UISlider!
    
    @IBOutlet weak var aboutBtn: UIButton!
    @IBOutlet weak var websiteBtn: UIButton!
    @IBOutlet weak var aboutTxtView: UITextView!
    @IBOutlet weak var mainStackView: UIStackView!
    
    
    var segueSettings: Dictionary<String, Any> = Dictionary()
    
    override func viewDidLoad() {
        BMCManager.shared.presentingViewController = self
        BMCManager.shared.thankYouMessage = "Thank you for supporting 🎉 Hide My Face !"
        
        saveBtn.layer.cornerRadius = 15
        aboutBtn.layer.cornerRadius = 15
        websiteBtn.layer.cornerRadius = 15
        deleteLocationSwitch.setOn(segueSettings["delete"] as! Bool, animated: false)
        blurFacesSwitch.setOn(segueSettings["blur"] as! Bool, animated: false)
        saveAsCopySwitch.setOn(segueSettings["save"] as! Bool, animated: false)
        compressionSlider.setValue(segueSettings["slider"] as! Float, animated: true)
        aboutTxtView.isHidden = true
        if UIDevice().userInterfaceIdiom == .phone {
            if UIScreen.main.nativeBounds.height < 1920{
                print("[-] reduced spacing")
                mainStackView.spacing = 24
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("[-] Settings Saved:\n• Delete location: \(deleteLocationSwitch.isOn)\n• Blur faces: \(blurFacesSwitch.isOn)\n• Save as copy: \(saveAsCopySwitch.isOn)\n• Slider val: \(compressionSlider.value)")
    }
    
    @IBAction func aboutAction(_ sender: Any) {
        aboutTxtView.isHidden = !aboutTxtView.isHidden
    }
    
    @IBAction func websiteAtion(_ sender: Any) {
        let ac = UIAlertController(title: "Open Link", message: "Website will now launch in Safari. Do you want to continue?", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "No", style: .cancel))
        ac.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
            if let url = NSURL(string: "http://www.hidemyface.xyz") {
                if UIApplication.shared.canOpenURL(url as URL) {
                    print("[-] Launching website")
                    UIApplication.shared.open(url as URL)
                }
            }
        }))
        self.present(ac, animated: true)
    }
}
