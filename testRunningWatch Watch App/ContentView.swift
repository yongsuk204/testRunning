// testRunning Watch App/ContentView.swift

import SwiftUI

struct ContentView: View {
    // 통신 객체와 현재 상태를 관리하는 변수
    @StateObject private var connectivity = WatchConnectivity()
    @State private var status: String = "IDLE"

    var body: some View {
        VStack(spacing: 15) {
            Text("STATUS: \(status)")
                .font(.headline)
                .bold()

            // 달리기 버튼
            Button(action: {
                connectivity.sendMessage(action: "running")
                self.status = "RUNNING"
            }) {
                Text("Run").bold()
                    .frame(maxWidth: .infinity)
            }
            .tint(.green) // iOS 15+ 스타일

            // 정지 버튼
            Button(action: {
                connectivity.sendMessage(action: "standing")
                self.status = "STANDING"
            }) {
                Text("Stop").bold()
                    .frame(maxWidth: .infinity)
            }
            .tint(.red) // iOS 15+ 스타일
        }
        .font(.title2)
    }
}
