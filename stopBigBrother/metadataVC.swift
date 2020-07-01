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
    
    var receiveMD: String = String()
    var location: CLLocation?
    
    override func viewDidLoad() {
        dismissBtn.layer.cornerRadius = 15
        metadataTxtView.text = receiveMD
        mapView.layer.cornerRadius = 15
        configureMap()
    }
    
    fileprivate func configureMap() {
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
                
                point.coordinate = self.location!.coordinate
                point.title = address != "" ? address : "Image location found"
                self.mapView.addAnnotation(point)
                self.mapView.setCenter(point.coordinate, animated: true)
            })
            
        } else {
            mapView.isUserInteractionEnabled = false
            let mkViewRect = mapView.bounds
            let overlay = UIView(frame: mkViewRect)
            overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            let message = UILabel(frame: CGRect(x: 0, y: 0, width: 210, height: 50))
            message.text = "No location data available."
            message.center = CGPoint(x: overlay.bounds.width/2, y: overlay.bounds.height/2)
            overlay.addSubview(message)
            mapView.addSubview(overlay)
        }
    }
}
