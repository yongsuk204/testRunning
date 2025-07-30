// testRunningWatch Watch App/WatchConnectivity.swift

// Foundation: 기본적인 데이터 타입(String, Double 등)과 컬렉션 등을 사용하기 위해 필요한 프레임워크입니다.
import Foundation
// WatchConnectivity: Apple Watch와 iPhone 간의 통신을 관리하는 프레임워크입니다.
import WatchConnectivity

// Watch Connectivity 통신을 관리하는 클래스입니다.
// NSObject: WCSessionDelegate를 채택하려면 NSObject를 상속해야 합니다.
// WCSessionDelegate: Watch Connectivity 세션에서 발생하는 이벤트(예: 메시지 수신, 연결 상태 변경)를 처리하기 위한 델리게이트입니다.
// ObservableObject: SwiftUI 뷰가 이 객체의 변경사항을 감지하고 UI를 자동으로 업데이트할 수 있게 해줍니다.
class WatchConnectivity: NSObject, WCSessionDelegate, ObservableObject {
    // WCSession.default: Watch와 iPhone 간의 통신을 담당하는 싱글톤 세션 객체입니다. 앱 전체에서 단 하나의 인스턴스만 사용됩니다.
    // private으로 선언하여 클래스 외부에서의 직접적인 접근을 막습니다.
    private let session = WCSession.default

    // 클래스의 인스턴스가 생성될 때 호출되는 초기화 메서드입니다.
    override init() {
        // 부모 클래스(NSObject)의 초기화 메서드를 호출합니다.
        super.init()
        
        // WCSession.isSupported(): 현재 기기에서 Watch Connectivity를 지원하는지 확인합니다. (iPad 등에서는 지원하지 않음)
        // 이 확인을 통해 지원하지 않는 환경에서 코드가 실행되어 앱이 비정상 종료되는 것을 방지합니다.
        if WCSession.isSupported() {
            // session의 delegate를 현재 클래스의 인스턴스(self)로 지정합니다.
            // 이렇게 해야 WCSessionDelegate에 정의된 메서드들이 이 클래스에서 호출됩니다.
            session.delegate = self
            
            // Watch Connectivity 세션을 활성화합니다.
            // 이 과정은 비동기적으로 진행되며, 연결 설정을 시작하는 역할을 합니다.
            // 활성화 결과는 아래의 'session(_:activationDidCompleteWith:error:)' 델리게이트 메서드를 통해 전달됩니다.
            session.activate()
        }
    }

    // 아이폰으로 메시지를 보내는 함수 (심박수 포함)
    // - action: 메시지의 종류를 구분하기 위한 문자열 (예: "start", "stop")
    // - heartRate: 전송할 심박수 값
    func sendMessage(action: String, heartRate: Double) {
        // guard session.isReachable else { return }:
        // isReachable은 상대방 iOS 앱이 현재 실행 중이고 실시간 통신이 가능한 상태인지 확인합니다.
        // true가 아니면 메시지를 보내지 않고 함수를 즉시 종료하여 불필요한 오류를 방지합니다.
        // sendMessage는 상대방 앱이 활성화된 상태에서의 실시간 통신에 적합합니다.
        guard session.isReachable else { return }
        
        // session.sendMessage(...): 실시간으로 메시지를 전송하는 메서드입니다.
        session.sendMessage([
            // 전송할 데이터를 [String: Any] 형태의 딕셔너리로 구성합니다.
            "action": action,
            "heartRate": heartRate
        ], replyHandler: nil, errorHandler: { error in
            // replyHandler: nil -> 메시지에 대한 응답을 받지 않겠다는 의미입니다. 만약 응답 처리가 필요하다면 이곳에 클로저를 구현합니다.
            // errorHandler: 메시지 전송에 실패했을 경우 호출되는 클로저입니다.
            // 실패 원인이 담긴 error 객체를 이용해 로그를 출력합니다.
            print("메시지 전송 실패: \(error.localizedDescription)")
        })
    }
    
    // --- WCSessionDelegate 필수 구현 항목 ---
    // 이 메서드는 WCSessionDelegate 프로토콜을 따르기 위해 필수로 구현해야 합니다.
    // session.activate() 호출이 완료된 후 시스템에 의해 자동으로 호출됩니다.
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // activationState: 세션의 활성화 상태를 나타냅니다 (.activated, .inactive, .notActivated).
        // error: 활성화 과정에서 오류가 발생한 경우, 해당 오류 정보가 담깁니다. (오류가 없으면 nil)
        if let error = error {
            print("세션 활성화 오류: \(error.localizedDescription)")
        }
        
        // 실제 앱에서는 활성화 상태(activationState)에 따라 다른 로직을 처리할 수 있습니다.
        // 예: switch activationState { case .activated: ... }
    }
}
