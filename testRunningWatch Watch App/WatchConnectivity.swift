// testRunning Watch App/WatchConnectivity.swift

import Foundation
import WatchConnectivity

// 아이폰으로 메시지를 보내는 역할만 담당하는 클래스
class WatchConnectivity: NSObject, WCSessionDelegate, ObservableObject {
    private let session = WCSession.default

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // 아이폰으로 메시지를 보내는 함수
    func sendMessage(action: String) {
        guard session.isReachable else { return } // 아이폰 연결 상태 확인
        session.sendMessage(["action": action], replyHandler: nil)
    }
    
    // --- WCSessionDelegate 필수 구현 항목 ---
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
