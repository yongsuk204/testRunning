// testRunning/Connectivity.swift

import Foundation
import WatchConnectivity

// Watch로부터 메시지를 받아 앱의 상태(@Published)를 변경하는 클래스
class Connectivity: NSObject, WCSessionDelegate, ObservableObject {
    // isRunning 값이 바뀌면 SwiftUI 뷰가 자동으로 업데이트됩니다.
    @Published var isRunning: Bool = false

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // 세션 활성화가 완료되었을 때 처리할 코드를 여기에 작성합니다.
        // 예를 들어, 활성화 상태를 출력하거나 오류를 처리할 수 있습니다.
        if let error = error {
            print("세션 활성화 오류: \(error.localizedDescription)")
            return
        }
        
        print("세션 활성화 완료! 상태: \(activationState.rawValue)")
    }

    // Watch로부터 메시지를 성공적으로 수신했을 때 호출됩니다.
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // UI 업데이트는 메인 스레드에서 처리해야 합니다.
        DispatchQueue.main.async {
            if let action = message["action"] as? String {
                self.isRunning = (action == "running")
            }
        }
    }

    // --- WCSessionDelegate 필수 구현 항목 ---
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
