//
//  ViewController.swift
//  Heart Rate and Map Demo
//
//  Created by Shane Ragusa on 7/7/17.
//  Copyright © 2017 Shane Ragusa. All rights reserved.
//

import UIKit
import HealthKit
import MapKit
import WatchConnectivity
import CoreLocation
import UserNotifications

class ViewController: UIViewController, WCSessionDelegate, UNUserNotificationCenterDelegate, CLLocationManagerDelegate{
    
    var watchManager: WCSession!

    @IBOutlet weak var heartRateLabel: UILabel!
    
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    
    var heartRate: UInt16 = 0
    
    var currentLatitude: Double = 0.0
    var currentLongitude: Double = 0.0
    
    var destinations = [Double: Double]()
    
    var currentAnnotation: MKPointAnnotation!
    
    let locationManager: CLLocationManager = CLLocationManager()
    
    let notificationCenter = UNUserNotificationCenter.current()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setupWatchManager()
        createGestures()
        
        authorizeLocation()
        locationManager.requestLocation()
        

    }
   
   //Automatically send a notification regardless of proximity to location pin
    @IBAction func triggerNotification(_ sender: Any) {
      Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(sendAlert), userInfo: nil, repeats: false)
    }

   @IBAction func resetPins(_ sender: Any) {
      destinations = [:]
      let allAnnotations = map.annotations
      map.removeAnnotations(allAnnotations)
      
   }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupWatchManager(){
        if(WCSession.isSupported()){
            watchManager = WCSession.default()
            watchManager.delegate = self
            watchManager.activate()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]){
        
        let keys = message.keys
        
        if(keys.contains("heartRate")){
            heartRate = message["heartRate"] as! UInt16
            DispatchQueue.main.async {
                self.heartRateLabel.text = "Heart rate: \(self.heartRate) bpm"
            }
            
        }
        
        else if(keys.contains("latitude") && keys.contains("longitude")){
            
            if (currentAnnotation == nil) {
                currentAnnotation = MKPointAnnotation()
            }
            
            DispatchQueue.main.sync {
                self.currentLatitude = message["latitude"] as! Double
                self.currentLongitude = message["longitude"] as! Double
                let location = CLLocationCoordinate2D(latitude: self.currentLatitude, longitude: self.currentLongitude)
                
                
                let span = MKCoordinateSpanMake(0.000001, 0.000001)
                
                let region = MKCoordinateRegion(center: location, span: span)
                
                self.map.setRegion(region, animated: true)
                
                
                
                self.currentAnnotation.coordinate = location
                self.map.addAnnotation(self.currentAnnotation)
                self.latitudeLabel.text = "Latitude: \(self.currentLatitude)"
                self.longitudeLabel.text = "Longitude: \(self.currentLongitude)"
                
                if (destinations != [:]) {checkDistance()}
                
            }
            
            
            
            
        }
        
    }
    
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    func createGestures(){
        let gestureRecognizer = UITapGestureRecognizer(target: self, action:#selector(handleTap(gestureReconizer:)))
        gestureRecognizer.delegate = self as? UIGestureRecognizerDelegate
        map.addGestureRecognizer(gestureRecognizer)
    }
    
    func handleTap(gestureReconizer: UILongPressGestureRecognizer) {
        
        let destination = MKPointAnnotation()
 
        let location = gestureReconizer.location(in: map)
        let coordinates = map.convert(location,toCoordinateFrom: map)
        
        destinations[coordinates.latitude] = coordinates.longitude
        
        // Add annotation:
        destination.coordinate = coordinates
        destination.title = "Destination"
        map.addAnnotation(destination)
    }
    
    func sendAlert(){
        
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: "Alert", arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: "You have reached your destination!", arguments: nil)
        content.sound = UNNotificationSound.default()
        
      
        let request = UNNotificationRequest(identifier: "any", content: content, trigger: nil)
        
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.add(request, withCompletionHandler: { (error) in
            if let error = error {
                print(error)
            }
            else {
                print("completed")
            }
        })
        
        
    }
    
    func checkDistance(){
        print("checkDistance Called")
        
        for(destinationLatitude, destinationLongitude) in destinations{
            let distanceLatitude = Swift.abs(currentLatitude-destinationLatitude)
            let distanceLongitude = Swift.abs(currentLongitude-destinationLongitude)
            
            if ( distanceLatitude < 0.00005 && distanceLongitude < 0.00005){
                print("closeEnough")
                sendAlert()
            }
        
            if (watchManager.isReachable){
                watchManager.sendMessage(["alert": "alert"], replyHandler: nil, errorHandler: nil)
            }
        }
    }
    
    func authorizeLocation(){
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        let authorizationStatus = CLLocationManager.authorizationStatus()
        
        if(authorizationStatus != CLAuthorizationStatus.authorizedAlways){
            locationManager.requestAlwaysAuthorization()
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        
        let beginningLocation = locations[0].coordinate
        let latitude = beginningLocation.latitude
        let longitude = beginningLocation.longitude
        
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        
        let span = MKCoordinateSpanMake(0.000001, 0.000001)
        
        let region = MKCoordinateRegion(center: location, span: span)
        
        self.map.setRegion(region, animated: true)

        
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .denied{
            print("error with locationManager")
        }
    }


}

