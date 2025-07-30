// testRunning/Connectivity.swift

import Foundation
import WatchConnectivity

class Connectivity: NSObject, WCSessionDelegate, ObservableObject {
    @Published var isRunning: Bool = false
    @Published var heartRate: Double = 0

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("세션 활성화 오류: \(error.localizedDescription)")
            return
        }
        print("세션 활성화 완료! 상태: \(activationState.rawValue)")
    }

    // Watch로부터 메시지를 수신
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let action = message["action"] as? String {
                self.isRunning = (action == "running")
            }
            
            if let heartRate = message["heartRate"] as? Double {
                self.heartRate = heartRate
            }
        }
    }

    // --- WCSessionDelegate 필수 구현 항목 ---
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
