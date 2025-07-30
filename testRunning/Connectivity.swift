// testRunning/Connectivity.swift
// 역할: iPhone 앱에서 Apple Watch와의 통신을 담당하는 클래스

import Foundation
import WatchConnectivity  // Apple Watch와 iPhone 간 통신을 위한 프레임워크

// WCSessionDelegate: Watch Connectivity 세션의 이벤트를 처리하는 프로토콜
// ObservableObject: SwiftUI에서 뷰를 자동으로 업데이트하기 위한 프로토콜
class Connectivity: NSObject, WCSessionDelegate, ObservableObject {
    // @Published: 이 속성이 변경되면 SwiftUI 뷰가 자동으로 다시 렌더링됨
    @Published var isRunning: Bool = false  // 현재 런닝 중인지 여부
    @Published var heartRate: Double = 0    // 현재 심박수 (BPM)

    override init() {
        super.init()
        
        // WCSession: Watch와 iPhone 간 통신 세션을 관리하는 싱글톤 객체
        if WCSession.isSupported() {  // 현재 기기가 Watch Connectivity를 지원하는지 확인
            let session = WCSession.default  // 기본 세션 인스턴스 가져오기
            session.delegate = self          // 이 클래스가 세션 이벤트를 처리하도록 설정
            session.activate()               // 세션 활성화 (통신 시작)
        }
    }
    
    // 세션 활성화가 완료되었을 때 호출되는 델리게이트 메서드
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("세션 활성화 오류: \(error.localizedDescription)")
            return
        }
        
        // activationState: .activated, .notActivated, .inactive 중 하나
        print("세션 활성화 완료! 상태: \(activationState.rawValue)")
    }

    // Watch로부터 메시지를 수신했을 때 호출되는 델리게이트 메서드
    // message: [String: Any] 형태의 딕셔너리로 데이터 전달
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // UI 업데이트는 반드시 메인 스레드에서 실행해야 함
        DispatchQueue.main.async {
            // "action" 키로 전달된 값 확인
            if let action = message["action"] as? String {
                // "running"이면 true, 아니면 false
                self.isRunning = (action == "running")
            }
            
            // "heartRate" 키로 전달된 심박수 값 확인
            if let heartRate = message["heartRate"] as? Double {
                self.heartRate = heartRate
            }
        }
    }

    // --- WCSessionDelegate 필수 구현 항목 (iOS에서만 필요) ---
    
    // 세션이 비활성화될 때 호출 (다중 Watch 지원 시)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    // 세션이 비활성화된 후 호출 (다중 Watch 전환 시)
    func sessionDidDeactivate(_ session: WCSession) {
        // 새로운 Watch와 연결하기 위해 세션 다시 활성화
        session.activate()
    }
}
