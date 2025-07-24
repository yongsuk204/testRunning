// testRunning/ContentView.swift

import SwiftUI
import SceneKit

struct ContentView: View {
    // Watch 연결 객체를 관찰하여 뷰를 업데이트합니다.
    @StateObject private var connectivity = Connectivity()

    // 앱이 시작될 때 두 개의 3D 씬을 미리 로드합니다.
    private let standingScene = SCNScene(named: "Stand.dae")
    private let runningScene = SCNScene(named: "Run.dae")

    var body: some View {
        // isRunning 상태 값에 따라 렌더링할 뷰를 결정합니다.
        Group {
            if connectivity.isRunning {
                // 달리기 상태일 때
                SceneView(scene: runningScene, options: .allowsCameraControl)
            } else {
                // 정지 상태일 때
                SceneView(scene: standingScene, options: .allowsCameraControl)
            }
        }
        .ignoresSafeArea() // 전체 화면으로 표시
    }
}
