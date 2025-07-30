// testRunningWatch Watch App/HealthManager.swift
// 역할: Apple Watch에서 운동 데이터와 심박수를 관리하는 클래스

import Foundation
import HealthKit  // Apple의 건강 데이터 프레임워크

// HKWorkoutSessionDelegate: 운동 세션의 상태 변화를 감지
// HKLiveWorkoutBuilderDelegate: 실시간 운동 데이터를 수집
class HealthManager: NSObject, ObservableObject {
    // HealthKit 데이터 저장소 접근을 위한 객체
    private let healthStore = HKHealthStore()
    
    // 운동 세션 관련 객체들
    private var workoutSession: HKWorkoutSession?      // 운동 세션 관리
    private var builder: HKLiveWorkoutBuilder?         // 실시간 운동 데이터 수집
    private var heartRateQuery: HKQuery?               // 심박수 쿼리 저장용
    
    // UI 업데이트를 위한 Published 속성
    @Published var heartRate: Double = 0    // 현재 심박수 (BPM)
    @Published var isRunning = false        // 런닝 중 여부
    
    // iPhone과의 통신을 위한 참조
    private var connectivity: WatchConnectivity?
    
    override init() {
        super.init()
        requestAuthorization()  // HealthKit 권한 요청
    }
    
    // WatchConnectivity 객체 설정
    func setConnectivity(_ connectivity: WatchConnectivity) {
        self.connectivity = connectivity
    }
    
    // HealthKit 권한 요청 함수
    private func requestAuthorization() {
        // 쓰기 권한이 필요한 데이터 타입
        let typesToShare: Set = [
            HKQuantityType.workoutType()  // 운동 기록 저장
        ]
        
        // 읽기 권한이 필요한 데이터 타입
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,           // 심박수
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,  // 활동 칼로리
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!, // 이동 거리
            HKObjectType.activitySummaryType()  // 활동 요약
        ]
        
        // 권한 요청 (사용자에게 권한 요청 팝업 표시)
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                print("HealthKit 권한 획득 성공")
                // 자동 모니터링은 시작하지 않음 (수동 시작만 지원)
            } else {
                print("HealthKit 권한 획득 실패: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    // 활동 모니터링 시작 (현재는 사용하지 않음)
    private func startActivityMonitoring() {
        startObservingHeartRate()
    }
    
    // 심박수 변화 관찰 시작
    private func startObservingHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        // HKObserverQuery: 특정 데이터 타입의 변화를 감지하는 쿼리
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
            self?.fetchLatestHeartRate()  // 변화 감지 시 최신 심박수 가져오기
            completionHandler()           // 완료 핸들러 호출 (필수)
        }
        
        healthStore.execute(query)
    }
    
    // 최신 심박수 데이터 가져오기
    private func fetchLatestHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        // 시작 날짜 기준 내림차순 정렬 (최신 데이터가 첫 번째)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        // HKSampleQuery: HealthKit에서 샘플 데이터를 가져오는 쿼리
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,           // 필터 없음 (모든 심박수 데이터)
            limit: 1,                 // 최신 1개만
            sortDescriptors: [sortDescriptor]
        ) { [weak self] query, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            // 심박수 단위: count/min (분당 횟수)
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let heartRate = sample.quantity.doubleValue(for: heartRateUnit)
            
            DispatchQueue.main.async {
                self?.heartRate = heartRate
                
                // 간단한 휴리스틱: 심박수 100 이상이면 런닝으로 판단
                let wasRunning = self?.isRunning ?? false
                let isNowRunning = heartRate > 100
                
                // 상태가 변경되었을 때만 처리
                if isNowRunning != wasRunning {
                    self?.isRunning = isNowRunning
                    if isNowRunning {
                        self?.connectivity?.sendMessage(action: "running", heartRate: heartRate)
                        self?.startHeartRateStreaming()  // 실시간 스트리밍 시작
                    } else {
                        self?.connectivity?.sendMessage(action: "standing", heartRate: 0)
                        self?.stopHeartRateStreaming()   // 스트리밍 중지
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    // 실시간 심박수 스트리밍 시작
    private func startHeartRateStreaming() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        // HKAnchoredObjectQuery: 특정 시점 이후의 새로운 데이터를 실시간으로 가져오는 쿼리
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,              // nil = 모든 데이터부터 시작
            limit: HKObjectQueryNoLimit  // 제한 없음
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)  // 초기 데이터 처리
        }
        
        // 업데이트 핸들러: 새로운 심박수 데이터가 들어올 때마다 호출
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        heartRateQuery = query
        healthStore.execute(query)
    }
    
    // 심박수 스트리밍 중지
    private func stopHeartRateStreaming() {
        if let query = heartRateQuery {
            healthStore.stop(query)  // 쿼리 중지
            heartRateQuery = nil
        }
    }
    
    // 심박수 샘플 데이터 처리
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else { return }
        
        DispatchQueue.main.async { [weak self] in
            // 가장 최근 샘플 사용
            if let sample = heartRateSamples.last {
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let heartRate = sample.quantity.doubleValue(for: heartRateUnit)
                self?.heartRate = heartRate
                
                // 런닝 중일 때만 iPhone으로 전송
                if self?.isRunning == true {
                    self?.connectivity?.sendMessage(action: "running", heartRate: heartRate)
                }
            }
        }
    }
    
    // 수동으로 런닝 시작 (테스트용)
    func startRunning() {
        // 운동 구성 설정
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running     // 운동 종류: 달리기
        configuration.locationType = .outdoor     // 장소: 실외
        
        do {
            // 운동 세션 생성
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = workoutSession?.associatedWorkoutBuilder()
            
            // 실시간 데이터 소스 설정
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // 델리게이트 설정
            workoutSession?.delegate = self
            builder?.delegate = self
            
            // 운동 시작
            workoutSession?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { [weak self] success, error in
                if success {
                    DispatchQueue.main.async {
                        self?.isRunning = true
                        self?.startHeartRateStreaming()
                        // 초기 상태를 iPhone으로 전송
                        self?.connectivity?.sendMessage(action: "running", heartRate: self?.heartRate ?? 0)
                    }
                } else {
                    print("워크아웃 시작 실패: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        } catch {
            print("워크아웃 세션 생성 실패: \(error.localizedDescription)")
        }
    }
    
    // 런닝 중지
    func stopRunning() {
        workoutSession?.end()  // 세션 종료
        builder?.endCollection(withEnd: Date()) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.isRunning = false
                    self?.stopHeartRateStreaming()
                    self?.heartRate = 0
                    self?.connectivity?.sendMessage(action: "standing", heartRate: 0)
                }
                
                // 운동 데이터 저장 및 정리
                self?.builder?.finishWorkout { workout, error in
                    self?.workoutSession = nil
                    self?.builder = nil
                }
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
// 운동 세션의 상태 변화를 처리하는 델리게이트
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
// 실시간 운동 데이터 수집을 처리하는 델리게이트
extension HealthManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // 운동 이벤트 수집 시 처리 (예: 랩 타임, 일시정지 등)
    }
    
    // 새로운 운동 데이터가 수집되었을 때 호출
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            // 심박수 데이터인 경우 처리
            if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                if let statistics = workoutBuilder.statistics(for: quantityType) {
                    let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    // mostRecentQuantity: 가장 최근 측정값
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
