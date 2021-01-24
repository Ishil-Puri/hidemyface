//
//  Aim.swift
//  stopBigBrother
//
//  Created by ip on 1/8/21.
//  Copyright © 2021 Hide My Face Inc. All rights reserved.
//

import Foundation
import UIKit
import Photos

//  Encapsulate each component – asset, image, metadata (AIM) – into an object.
class Aim {
    var asset: PHAsset
    var image: UIImage
    var metadata: Dictionary<String, Any>
    var position: Int
    
    init(asset: PHAsset, metadata: Dictionary<String, Any>, position: Int) {
        self.asset = asset
        self.image = UIImage()
        self.metadata = metadata
        self.position = position
    }
}
