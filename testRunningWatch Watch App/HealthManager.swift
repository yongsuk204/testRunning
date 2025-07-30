// testRunningWatch Watch App/HealthManager.swift

import Foundation
import HealthKit

class HealthManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    @Published var heartRate: Double = 0
    @Published var isRunning = false
    
    private var connectivity: WatchConnectivity?
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    func setConnectivity(_ connectivity: WatchConnectivity) {
        self.connectivity = connectivity
    }
    
    private func requestAuthorization() {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                self.startObservingWorkouts()
            }
        }
    }
    
    private func startObservingWorkouts() {
        let workoutPredicate = HKQuery.predicateForWorkouts(with: .running)
        
        let query = HKObserverQuery(sampleType: HKWorkoutType.workoutType(), predicate: workoutPredicate) { query, completionHandler, error in
            self.checkCurrentWorkout()
            completionHandler()
        }
        
        healthStore.execute(query)
        checkCurrentWorkout()
    }
    
    private func checkCurrentWorkout() {
        let workoutPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600), end: nil, options: .strictEndDate)
        ])
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: HKWorkoutType.workoutType(), predicate: workoutPredicate, limit: 1, sortDescriptors: [sortDescriptor]) { query, samples, error in
            if let workout = samples?.first as? HKWorkout, workout.endDate == nil {
                // 런닝 중
                DispatchQueue.main.async {
                    if !self.isRunning {
                        self.isRunning = true
                        self.startHeartRateQuery()
                        self.connectivity?.sendMessage(action: "running", heartRate: self.heartRate)
                    }
                }
            } else {
                // 런닝 중이 아님
                DispatchQueue.main.async {
                    if self.isRunning {
                        self.isRunning = false
                        self.stopHeartRateQuery()
                        self.connectivity?.sendMessage(action: "standing", heartRate: 0)
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private var heartRateQuery: HKQuery?
    
    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { query, samples, deletedObjects, anchor, error in
            self.processHeartRateSamples(samples)
        }
        
        query.updateHandler = { query, samples, deletedObjects, anchor, error in
            self.processHeartRateSamples(samples)
        }
        
        heartRateQuery = query
        healthStore.execute(query)
    }
    
    private func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else { return }
        
        DispatchQueue.main.async {
            if let sample = heartRateSamples.last {
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let heartRate = sample.quantity.doubleValue(for: heartRateUnit)
                self.heartRate = heartRate
                self.connectivity?.sendMessage(action: "running", heartRate: heartRate)
            }
        }
    }
    
    // 수동으로 런닝 시작/중지 (테스트용)
    func startRunning() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = workoutSession?.associatedWorkoutBuilder()
            
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            workoutSession?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.isRunning = true
                        self.startHeartRateQuery()
                    }
                }
            }
        } catch {
            print("Error starting workout: \(error)")
        }
    }
    
    func stopRunning() {
        workoutSession?.end()
        builder?.endCollection(withEnd: Date()) { success, error in
            if success {
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.stopHeartRateQuery()
                    self.heartRate = 0
                    self.connectivity?.sendMessage(action: "standing", heartRate: 0)
                }
            }
        }
    }
}
