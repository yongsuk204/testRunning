// testRunningWatch Watch App/HealthManager.swift

import Foundation
import HealthKit

class HealthManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKQuery?
    
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
            HKObjectType.activitySummaryType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                print("HealthKit 권한 획득 성공")
                self.startActivityMonitoring()
            } else {
                print("HealthKit 권한 획득 실패: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func startActivityMonitoring() {
        // 모션 액티비티 변화 감지
        startObservingHeartRate()
    }
    
    private func startObservingHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        // 최신 심박수를 지속적으로 관찰
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
            self?.fetchLatestHeartRate()
            completionHandler()
        }
        
        healthStore.execute(query)
    }
    
    private func fetchLatestHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] query, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let heartRate = sample.quantity.doubleValue(for: heartRateUnit)
            
            DispatchQueue.main.async {
                self?.heartRate = heartRate
                
                // 심박수가 100 이상이면 런닝 중으로 판단 (간단한 휴리스틱)
                let wasRunning = self?.isRunning ?? false
                let isNowRunning = heartRate > 100
                
                if isNowRunning != wasRunning {
                    self?.isRunning = isNowRunning
                    if isNowRunning {
                        self?.connectivity?.sendMessage(action: "running", heartRate: heartRate)
                        self?.startHeartRateStreaming()
                    } else {
                        self?.connectivity?.sendMessage(action: "standing", heartRate: 0)
                        self?.stopHeartRateStreaming()
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func startHeartRateStreaming() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        heartRateQuery = query
        healthStore.execute(query)
    }
    
    private func stopHeartRateStreaming() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else { return }
        
        DispatchQueue.main.async { [weak self] in
            if let sample = heartRateSamples.last {
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let heartRate = sample.quantity.doubleValue(for: heartRateUnit)
                self?.heartRate = heartRate
                
                if self?.isRunning == true {
                    self?.connectivity?.sendMessage(action: "running", heartRate: heartRate)
                }
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
            
            workoutSession?.delegate = self
            builder?.delegate = self
            
            workoutSession?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { [weak self] success, error in
                if success {
                    DispatchQueue.main.async {
                        self?.isRunning = true
                        self?.startHeartRateStreaming()
                    }
                } else {
                    print("워크아웃 시작 실패: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        } catch {
            print("워크아웃 세션 생성 실패: \(error.localizedDescription)")
        }
    }
    
    func stopRunning() {
        workoutSession?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.isRunning = false
                    self?.stopHeartRateStreaming()
                    self?.heartRate = 0
                    self?.connectivity?.sendMessage(action: "standing", heartRate: 0)
                }
                
                self?.builder?.finishWorkout { workout, error in
                    self?.workoutSession = nil
                    self?.builder = nil
                }
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension HealthManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isRunning = true
            case .ended, .stopped:
                self.isRunning = false
                self.stopHeartRateStreaming()
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("워크아웃 세션 에러: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension HealthManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // 이벤트 수집 시 처리
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                if let statistics = workoutBuilder.statistics(for: quantityType) {
                    let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    if let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                        DispatchQueue.main.async {
                            self.heartRate = value
                            self.connectivity?.sendMessage(action: "running", heartRate: value)
                        }
                    }
                }
            }
        }
    }
}
