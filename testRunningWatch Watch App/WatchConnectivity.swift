// testRunningWatch Watch App/WatchConnectivity.swift

import Foundation
import WatchConnectivity

class WatchConnectivity: NSObject, WCSessionDelegate, ObservableObject {
    private let session = WCSession.default

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // 아이폰으로 메시지를 보내는 함수 (심박수 포함)
    func sendMessage(action: String, heartRate: Double) {
        guard session.isReachable else { return }
        session.sendMessage([
            "action": action,
            "heartRate": heartRate
        ], replyHandler: nil) { error in
            print("메시지 전송 실패: \(error.localizedDescription)")
        }
    }
    
    // --- WCSessionDelegate 필수 구현 항목 ---
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("세션 활성화 오류: \(error.localizedDescription)")
        }
    }
}
