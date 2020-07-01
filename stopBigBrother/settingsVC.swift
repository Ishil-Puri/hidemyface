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
    
    var segueSettings: Dictionary<String, Bool> = Dictionary()
    
    override func viewDidLoad() {
        print("[-] Settings VC loaded")
        saveBtn.layer.cornerRadius = 15
        deleteLocationSwitch.setOn(segueSettings["delete"]!, animated: false)
        blurFacesSwitch.setOn(segueSettings["blur"]!, animated: false)
        saveAsCopySwitch.setOn(segueSettings["save"]!, animated: false)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("[-] Settings Saved:\nDelete location data = \(deleteLocationSwitch.isOn)\nBlur faces in image = \(blurFacesSwitch.isOn)\nSave as a copy = \(saveAsCopySwitch.isOn)")
    }
}
