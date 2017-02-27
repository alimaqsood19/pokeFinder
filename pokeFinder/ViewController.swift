//
//  ViewController.swift
//  pokeFinder
//
//  Created by Ambar Maqsood on 2016-10-19.
//  Copyright © 2016 Ali Maqsood. All rights reserved.
//

import UIKit
import MapKit // 1. Import Mapkit
import FirebaseDatabase


class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
// 2. Imported MKMapViewDelegate Protocol
    @IBOutlet weak var mapView: MKMapView!
    
     let locationManager = CLLocationManager() //4. Location manager needed
    var mapHasCenteredOnce: Bool = true
     var geoFire: GeoFire!
    var geoFireRef: FIRDatabaseReference!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self  //3. delegate needed when imported protocl
        mapView.userTrackingMode = MKUserTrackingMode.follow // 5. Follows user when moving on map
        
        geoFireRef = FIRDatabase.database().reference() //Firebase database reference 
        geoFire = GeoFire(firebaseRef: geoFireRef) //Geofire is initiliazed
    
    }
    override func viewDidAppear(_ animated: Bool) {
        locationAuthStatus() //Every time view is loaded call the function so it only tracks location when app is on otherwise drains battery
    }
    func locationAuthStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            mapView.showsUserLocation = true // 6. Func for location when app is running only not in background
        }else {
            locationManager.requestWhenInUseAuthorization()
        }// THIS ASKS FOR AUTHORIZATION
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        //If they say yes then userlocation activates
        if status == CLAuthorizationStatus.authorizedWhenInUse {
            mapView.showsUserLocation = true
        }else {
            locationManager.requestWhenInUseAuthorization()
            //if NO Asks for it again
        }
    }
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 2000, 2000)
        //THIS zooms the map in on current location centers map
        
        mapView.setRegion(coordinateRegion, animated: true)//Centers on map shows user
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
        if let location = userLocation.location {
            //Centers back on user when updated location
            if !mapHasCenteredOnce {
                centerMapOnLocation(location: location)
                mapHasCenteredOnce = true
                //Only centers once when app is loaded
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Customizes your pins/annotations
        let annoIdentifier = "Pokemon"
        var annotationView: MKAnnotationView?
        
        if annotation.isKind(of: MKUserLocation.self) {
            
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "User")
            annotationView?.image = UIImage(named: "ash")
            //Gets rid of default tracker for User with a picture of ash
        }else if let deqAnno = mapView.dequeueReusableAnnotationView(withIdentifier: annoIdentifier) {
            annotationView = deqAnno
            annotationView?.annotation = annotation
        }else {
            let annoView = MKAnnotationView(annotation: annotation, reuseIdentifier: annoIdentifier)
            annoView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)// popup appears with mapicon
            annotationView = annoView
            
        }
        
        if let annotationView = annotationView, let anno = annotation as? PokeAnnotation {
            
            annotationView.canShowCallout = true
            annotationView.image = UIImage(named: "\(anno.pokemonNumber)")
            let btn = UIButton()
            btn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            btn.setImage(UIImage(named: "map"), for: .normal)
            annotationView.rightCalloutAccessoryView = btn
            
        }
        
        return annotationView
    }

    func createSighting(forLocation location: CLLocation, withPokemon pokeId: Int) {
        
        geoFire.setLocation(location, forKey: "\(pokeId)")
        //Geofire goes into the data base, goes through all the database references in the geographical location you have specified
        //The function stores the location and key being the pokemon ID into the database
    }
    
    func showSightingsOnMap(location: CLLocation) {
        //Shows the pokemon on the map, creating a query
        let circleQuery = geoFire!.query(at: location, withRadius: 2.5) //2.5 in KiloMeters
        
        _ = circleQuery?.observe(GFEventType.keyEntered, with: { (key, location) in
            
            if let key = key, let location = location {
                let anno = PokeAnnotation(coordinate: location.coordinate, pokemonNumber: Int(key)!)
                self.mapView.addAnnotation(anno) // Adds a pin or annotation on the map, running through the database with all the objects attached to a location
                
                
            }
            
        })
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude) // whenever user pans away it updates it outside of the 2.5km radius
        
        showSightingsOnMap(location: loc)
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        if let anno = view.annotation as? PokeAnnotation {
            let place = MKPlacemark(coordinate: anno.coordinate) // creates a placemark with directions to location
            let destination = MKMapItem(placemark: place) //the destination
            destination.name = "Pokemon Sighting" //shows up on apple map
            let regionDistance: CLLocationDistance = 1000
            let regionSpan = MKCoordinateRegionMakeWithDistance(anno.coordinate, regionDistance, regionDistance)
            //Apple map needs placemark and destination, distance, region distance and region span
            let options = [MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center), MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span), MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving] as [String : Any]
            //Shows driving directions for options
            
            MKMapItem.openMaps(with: [destination], launchOptions: options)
        }
        
    }
    
    @IBAction func spotRandomPokemon(_ sender: AnyObject) {
        
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude) //Everytime pokeball pressed gets the coordinates of center of map
        
        let rand = arc4random_uniform(151) + 1
        createSighting(forLocation: loc, withPokemon: Int(rand))  //Grab a random pokemon number adds a sighting for that pokemon, which calls Geofire which sets a location in the geofire database
        //calls the function createSighting() which stores the coordinate in the geofire database
    }


}

