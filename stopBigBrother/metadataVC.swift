//
//  metadataVC.swift
//  stopBigBrother
//
//  Created by ip on 6/18/20.
//  Copyright © 2020 The Brotherhood Inc. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class metadataVC: UIViewController {
    
    @IBOutlet weak var metadataTxtView: UITextView!
    @IBOutlet weak var dismissBtn: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    
    var receiveMD: Dictionary<String, Any> = [:]
    
    override func viewDidLoad() {
        dismissBtn.layer.cornerRadius = 15
        metadataTxtView.text = ppMetadata(dict: receiveMD)
        metadataTxtView.layer.cornerRadius = 15
        mapView.layer.cornerRadius = 15
        configureMap()
    }
    
    fileprivate func configureMap() {
        let location = receiveMD["location"] as? CLLocation
        let point = MKPointAnnotation()
        let geoCoder = CLGeocoder()
        var placeMark: CLPlacemark!
        
        if location != nil {

            var address = ""
            
            geoCoder.reverseGeocodeLocation(location!, completionHandler: { (placemarks, error) -> Void in
                placeMark = placemarks?[0]
                
                if placeMark != nil {
                    if let streetNumber = placeMark.subThoroughfare {
                        address += streetNumber
                    }
                    if let streetName = placeMark.thoroughfare {
                        address += " \(streetName)"
                    }
                    if let city = placeMark.locality {
                        address += "\n\(city)"
                    }
                    if let state = placeMark.administrativeArea {
                        address += ", \(state)"
                    }
                    if let zip = placeMark.postalCode {
                        address += " \(zip)"
                    }
                }
                
                point.coordinate = location!.coordinate
                point.title = address != "" ? address : "Image location found"
                self.mapView.addAnnotation(point)
                self.mapView.setCenter(point.coordinate, animated: true)
            })
            
        } else {
            mapView.isUserInteractionEnabled = false
            let overlay = UIView(frame: CGRect(x: 0, y: 0, width: mapView.bounds.width + 40, height: mapView.bounds.height))
            overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            let message = UILabel(frame: CGRect(x: 0, y: 0, width: 205, height: 50))
            message.textColor = UIColor.white
            message.text = "No location data available."
            message.center = CGPoint(x: view.frame.width/2, y: overlay.bounds.height/2)
            overlay.addSubview(message)
            mapView.addSubview(overlay)
        }
    }
    
    fileprivate func ppMetadata(dict: Dictionary<String, Any>) -> String {
//        let mediaType = "\(dict["mediaType"] ?? "no media type")"
        let date = dict["creationDate"]
            != nil ? " \(dict["creationDate"]!)" : "No date info found :("
//        let mediaSubtypes = "\(dict["mediaSubtypes"] ?? "no subtype")"
//        let sourceType = dict["sourceType"] ?? "no source type"
        let location = dict["location"] != nil ? " \(dict["location"]!)" : "No Location info found :("
//        let isFavorite = asset.isFavorite
//        let isHidden = asset.isHidden
        let dimensions = "\(dict["pixelWidth"] ?? 0)x\(dict["pixelHeight"] ?? 0)"
        let modificationDate = dict["modificationDate"]
        != nil ? " \(dict["modificationDate"]!)" : "No modification date info found :("
        // Media Type: \(mediaType)\nMedia Subtype: \(mediaSubtypes)\nSource Type: \(sourceType)\n
        return "Creation Date: \(date)\n\nLocation: \(location)\n\nDimensions: \(dimensions)\n\nLast Modified: \(modificationDate)"
    }
    
}
