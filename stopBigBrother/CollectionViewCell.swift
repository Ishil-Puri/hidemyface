//
//  CollectionViewCell.swift
//  stopBigBrother
//
//  Created by ip on 7/4/20.
//  Copyright © 2020 Hide My Face Inc. All rights reserved.
//

import UIKit

class CollectionViewCell: UICollectionViewCell {

    
    @IBOutlet weak var cellBtn: UIButton!
    @IBOutlet weak var indexLbl: UILabel!
    
    var viewMetadataTapAction : (()->())?
    var index = 0
    
    func displayContent(image: UIImage, index: Int) {
        cellBtn.imageView?.contentMode = .scaleAspectFill
        cellBtn.setImage(image, for: .normal)
        indexLbl.textColor = UIColor.white
        indexLbl.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
        indexLbl.layer.cornerRadius = 4
        indexLbl.layer.masksToBounds = true
        self.index = index
        indexLbl.text = "\(self.index+1)"
    }

    @IBAction func cellBtnAction(_ sender: Any) {
        viewMetadataTapAction?()
    }
    
    
}
