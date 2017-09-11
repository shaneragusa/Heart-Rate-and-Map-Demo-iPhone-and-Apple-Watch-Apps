//
//  PhoneHealthManager.swift
//  Heart Rate and Map Demo
//
//  Created by Shane Ragusa on 7/7/17.
//  Copyright © 2017 Shane Ragusa. All rights reserved.
//

import Foundation
import HealthKit

class PhoneHealthManager{
    
    let healthKitStore: HKHealthStore = HKHealthStore()
    
    
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
    
    
    
    
}
