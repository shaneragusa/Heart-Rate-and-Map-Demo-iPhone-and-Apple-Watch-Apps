//
//  InterfaceController.swift
//  Heart Rate and Map Demo WatchKit Extension
//
//  Created by Shane Ragusa on 7/7/17.
//  Copyright © 2017 Shane Ragusa. All rights reserved.
//
//  Heart rate data collection uses code by Coolioxlr on GitHub

import WatchKit
import Foundation
import HealthKit
import CoreLocation
import WatchConnectivity
import UserNotifications


class InterfaceController: WKInterfaceController, CLLocationManagerDelegate, WCSessionDelegate {

    var healthKitStore: HKHealthStore = HKHealthStore()
    
    var workoutSession: HKWorkoutSession!
    let heartRateUnit = HKUnit(from: "count/min")
    var anchor = HKQueryAnchor(fromValue: Int(HKAnchoredObjectQueryNoAnchor))
    
    @IBOutlet var heartRateLabel: WKInterfaceLabel!
    
    @IBOutlet var triggerButton: WKInterfaceButton!
    
    var coordinates: CLLocationCoordinate2D!
    
    var currentHeartRate: UInt16 = 0

    @IBOutlet var latitudeLabel: WKInterfaceLabel!
    
    @IBOutlet var longitudeLabel: WKInterfaceLabel!
    
    var locationManager: CLLocationManager = CLLocationManager()
    
    var watchManager: WCSession = WCSession.default()
    

    var monitoring: Bool = false
    
    var time: Timer!
    


    
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        authorizeServices()
        setupMonitoring()
        
        
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        ensureTriggerText()
        
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    @IBAction func trigger() {
        
        if(!monitoring){
            monitoring = true
            triggerButton.setTitle("Stop")
            beginMonitoring()
        }
        
        else if(monitoring){
            monitoring = false
            triggerButton.setTitle("Start")
            stopMonitoring()
        }
    }
    
    func ensureTriggerText(){
        
        if(!monitoring){
            triggerButton.setTitle("Start")
            print("monitoring = false")
        }
        else if(monitoring){
            triggerButton.setTitle("Stop")
            print("monitoring = true")
        }
        
    }
    
    func authorizeServices(){
        authorizeHealthKit()
        authorizeLocation()
    }
    
    
    func setupMonitoring(){
        setupWorkout()
        setupLocation()
        setupWCSession()
    }
    
    
    func beginMonitoring(){
        startWorkout()
        startLocation()
        monitoring = true
    }
    
    func stopMonitoring(){
        stopWorkout()
        setupWorkout()
        stopLocation()
        monitoring = false
    }
    
    
    
    
    /*
     * Functions using HealthKit to monitor heart rate
    */
    

    func authorizeHealthKit(){
        
        
        var readTypes = Set<HKObjectType>()
        readTypes.insert(HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!)
        
        if HKHealthStore.isHealthDataAvailable(){
            
            healthKitStore.requestAuthorization(toShare: nil, read: readTypes) { (success, error) -> Void in
                if success {
                    print("success")
                } else {
                    print("failure")
                }
                
                if let error = error { print(error) }
            }
        }
        
    }
    
    func setupWorkout(){
        
        let configuration = HKWorkoutConfiguration()
        
        configuration.activityType = .walking
        configuration.locationType = .unknown
        
        do {
            workoutSession = try HKWorkoutSession(configuration: configuration)
            
            workoutSession.delegate = self as? HKWorkoutSessionDelegate
        }
        
        catch let error as NSError {
            fatalError("*** Unable to create the workout session: \(error.localizedDescription)***")
        }
    
    }
    
    
    func startWorkout(){

        
        healthKitStore.start(workoutSession)

        if let query = createHeartRateStream(){
            healthKitStore.execute(query)
        }
        
        print("beginMonitoring")
    }
    

    
    func stopWorkout(){
        healthKitStore.end(workoutSession)
        if let query = createHeartRateStream(){
            healthKitStore.stop(query)
        }
        else {
            print("cannot stop")
        }
        print("stopMonitoring")
    }
    
    func createHeartRateStream() -> HKQuery? {
        
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {return nil}
        
        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType, predicate: nil, anchor: anchor, limit: Int(HKObjectQueryNoLimit)){ (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            guard let newAnchor = newAnchor else {return}
            self.anchor = newAnchor
            self.updateHeartRate(samples: sampleObjects)
        }
        
        heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            self.anchor = newAnchor!
            self.updateHeartRate(samples: samples)
        }
        
        return heartRateQuery
        
    }
    
    func updateHeartRate(samples: [HKSample]?){
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        
        DispatchQueue.main.async {
            guard let sample = heartRateSamples.first else{return}
            self.currentHeartRate = UInt16(sample.quantity.doubleValue(for: self.heartRateUnit))

            self.heartRateLabel.setText("\(String(self.currentHeartRate)) bpm")
            
            self.sendHeartRateToPhone()

        }
    }
    
    
    
    /*
    * Functions for Core Location
    */
    
    func authorizeLocation(){
        
        locationManager.delegate = self
        let authorizationStatus = CLLocationManager.authorizationStatus()
        
        switch authorizationStatus{
            case .notDetermined:
                locationManager.requestAlwaysAuthorization()
                break
            
            default: break
        }
        
    }
    
    func ensureLocation(){
        let authorizationStatus = CLLocationManager.authorizationStatus()
        
        if authorizationStatus != .authorizedWhenInUse{
            authorizeLocation()
            return
        }
        
        if !CLLocationManager.locationServicesEnabled(){
            authorizeLocation()
            return
        }
    }
    
    func setupLocation(){
        
        ensureLocation()
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.delegate = self
        
    }
    
    func getLocation(){
        locationManager.requestLocation()
    }
    
    
    func startLocation(){
        
       locationManager.startUpdatingLocation()
 
    
        
    }
    
    
    func stopLocation(){
        
        
        locationManager.stopUpdatingLocation()

        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .denied{
            stopLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){

        let location = locations.last!
        coordinates = location.coordinate
        latitudeLabel.setText("Lat: \(coordinates.latitude)")
        longitudeLabel.setText("Lon: \(coordinates.longitude)")
        sendCoordinatesToPhone()
        
    }
    
    
    /*
     * Functions to use Watch Connectivity
     */
    
    func setupWCSession(){
        watchManager.delegate = self
        watchManager.activate()
    }
    
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func sendHeartRateToPhone(){
        if(watchManager.isReachable){
            watchManager.sendMessage(["heartRate": currentHeartRate], replyHandler: nil, errorHandler: nil)
        }
    }
    
    func sendCoordinatesToPhone(){
        if(watchManager.isReachable){
            let latitude = coordinates.latitude
            let longitude = coordinates.longitude
            watchManager.sendMessage(["latitude":latitude, "longitude":longitude], replyHandler: nil, errorHandler: nil)
        }
    }
    

    
    
    
    
    
    
    

}
