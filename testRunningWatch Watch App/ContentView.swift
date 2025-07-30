// testRunningWatch Watch App/ContentView.swift

// SwiftUI: Apple 플랫폼에서 UI를 선언적으로 빌드하기 위한 프레임워크입니다.
import SwiftUI

// 앱의 메인 UI를 정의하는 구조체입니다.
struct ContentView: View {
    // @StateObject: SwiftUI 뷰의 생명주기 동안 ObservableObject 인스턴스를 안전하게 생성하고 관리하는 프로퍼티 래퍼입니다.
    // 뷰가 다시 그려져도 인스턴스는 파괴되지 않고 유지됩니다.
    // connectivity: iPhone과의 통신을 처리하는 WatchConnectivity 클래스의 인스턴스입니다.
    @StateObject private var connectivity = WatchConnectivity()
    
    // healthManager: HealthKit과 상호작용하여 운동 상태(isRunning)와 심박수(heartRate)를 관리하는 HealthManager 클래스의 인스턴스입니다.
    @StateObject private var healthManager = HealthManager()
    
    // body 프로퍼티는 뷰의 콘텐츠와 레이아웃을 정의합니다.
    var body: some View {
        // VStack: 자식 뷰들을 수직으로 배열하는 컨테이너입니다. spacing은 뷰 사이의 간격을 15포인트로 설정합니다.
        VStack(spacing: 15) {
            // healthManager의 isRunning 프로퍼티 값에 따라 텍스트를 동적으로 변경합니다.
            // true이면 "RUNNING", false이면 "IDLE"을 표시합니다.
            Text(healthManager.isRunning ? "RUNNING" : "IDLE")
                .font(.headline) // 폰트를 헤드라인 스타일로 설정합니다.
                .bold()          // 텍스트를 굵게 만듭니다.
                // isRunning 상태에 따라 텍스트 색상을 녹색 또는 회색으로 변경합니다.
                .foregroundColor(healthManager.isRunning ? .green : .gray)
            
            // healthManager.isRunning이 true일 때만 내부의 UI 요소를 화면에 표시합니다.
            if healthManager.isRunning {
                // HStack: 자식 뷰들을 수평으로 배열하는 컨테이너입니다.
                HStack {
                    // "heart.fill"이라는 이름의 SF Symbol 이미지를 표시합니다.
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red) // 아이콘 색상을 빨간색으로 설정합니다.
                        // heartRate가 0보다 클 때 아이콘 크기를 1.2배로, 아니면 1.0배로 조절합니다.
                        .scaleEffect(healthManager.heartRate > 0 ? 1.2 : 1.0)
                        // heartRate 값이 변경될 때마다 애니메이션을 적용합니다.
                        // 0.3초 동안 부드럽게 커졌다가 작아지는 효과를 무한 반복하여 심장이 뛰는 것처럼 보이게 합니다.
                        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: healthManager.heartRate)
                    
                    // 현재 심박수를 정수(Int)로 변환하여 "BPM" 단위와 함께 표시합니다.
                    Text("\(Int(healthManager.heartRate)) BPM")
                        .font(.title2) // 폰트를 title2 스타일로 설정합니다.
                        .bold()        // 텍스트를 굵게 만듭니다.
                }
            }
            
            // 테스트용 수동 컨트롤 버튼들을 담는 VStack입니다.
            VStack(spacing: 10) {
                Text("Manual Control")
                    .font(.caption) // 폰트를 캡션 스타일로 설정합니다.
                    .foregroundColor(.gray) // 텍스트 색상을 회색으로 설정합니다.
                
                HStack {
                    // 시작 버튼
                    Button(action: {
                        // 버튼을 탭하면 healthManager의 startRunning 함수를 호출합니다.
                        healthManager.startRunning()
                    }) {
                        // 버튼의 모양으로 "play.fill" 아이콘을 사용합니다.
                        Image(systemName: "play.fill")
                            .foregroundColor(.green)
                    }
                    // healthManager.isRunning이 true이면(즉, 이미 실행 중이면) 버튼을 비활성화합니다.
                    .disabled(healthManager.isRunning)
                    
                    // 정지 버튼
                    Button(action: {
                        // 버튼을 탭하면 healthManager의 stopRunning 함수를 호출합니다.
                        healthManager.stopRunning()
                    }) {
                        // 버튼의 모양으로 "stop.fill" 아이콘을 사용합니다.
                        Image(systemName: "stop.fill")
                            .foregroundColor(.red)
                    }
                    // healthManager.isRunning이 false이면(즉, 실행 중이 아니면) 버튼을 비활성화합니다.
                    .disabled(!healthManager.isRunning)
                }
            }
        }
        // .onAppear: ContentView가 화면에 처음 나타날 때 한 번 실행되는 코드 블록입니다.
        .onAppear {
            // HealthManager가 iPhone으로 데이터를 보낼 수 있도록, 생성된 connectivity 객체를 전달합니다.
            // 이를 통해 HealthManager와 WatchConnectivity 두 객체가 협력할 수 있게 됩니다.
            healthManager.setConnectivity(connectivity)
        }
    }
}
