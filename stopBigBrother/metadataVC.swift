//
//  metadataVC.swift
//  stopBigBrother
//
//  Created by ip on 6/18/20.
//  Copyright © 2020 The Brotherhood Inc. All rights reserved.
//

import UIKit

class metadataVC: UIViewController {
    
    @IBOutlet weak var metadataTxtView: UITextView!
    @IBOutlet weak var dismissBtn: UIButton!
    
    var receiveMD: String = String()
    
    override func viewDidLoad() {
        dismissBtn.layer.cornerRadius = 15
        metadataTxtView.text = receiveMD
    }
}
