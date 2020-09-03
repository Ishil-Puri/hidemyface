//
//  settingsVC.swift
//  stopBigBrother
//
//  Created by ip on 6/28/20.
//  Copyright © 2020 The Brotherhood Inc. All rights reserved.
//

import UIKit

class settingsVC: UIViewController {
    
    @IBOutlet weak var saveBtn: UIButton!
    @IBOutlet weak var deleteLocationSwitch: UISwitch!
    @IBOutlet weak var blurFacesSwitch: UISwitch!
    @IBOutlet weak var saveAsCopySwitch: UISwitch!
    
    @IBOutlet weak var aboutBtn: UIButton!
    @IBOutlet weak var websiteBtn: UIButton!
    @IBOutlet weak var aboutTxtView: UITextView!
    
    
    var segueSettings: Dictionary<String, Bool> = Dictionary()
    
    override func viewDidLoad() {
        print("[-] Settings VC loaded")
        saveBtn.layer.cornerRadius = 15
        aboutBtn.layer.cornerRadius = 15
        websiteBtn.layer.cornerRadius = 15
        deleteLocationSwitch.setOn(segueSettings["delete"]!, animated: false)
        blurFacesSwitch.setOn(segueSettings["blur"]!, animated: false)
        saveAsCopySwitch.setOn(segueSettings["save"]!, animated: false)
        aboutTxtView.isHidden = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("[-] Settings Saved:\nDelete location data = \(deleteLocationSwitch.isOn)\nBlur faces in image = \(blurFacesSwitch.isOn)\nSave as a copy = \(saveAsCopySwitch.isOn)")
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
                    print("[–] Launching website")
                    UIApplication.shared.open(url as URL)
                }
            }
        }))
        self.present(ac, animated: true)
    }
}
