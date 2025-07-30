// testRunningWatch Watch App/ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var connectivity = WatchConnectivity()
    @StateObject private var healthManager = HealthManager()
    
    var body: some View {
        VStack(spacing: 15) {
            Text(healthManager.isRunning ? "RUNNING" : "IDLE")
                .font(.headline)
                .bold()
                .foregroundColor(healthManager.isRunning ? .green : .gray)
            
            if healthManager.isRunning {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .scaleEffect(healthManager.heartRate > 0 ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: healthManager.heartRate)
                    
                    Text("\(Int(healthManager.heartRate)) BPM")
                        .font(.title2)
                        .bold()
                }
            }
            
            // 테스트용 수동 컨트롤
            VStack(spacing: 10) {
                Text("Manual Control")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Button(action: {
                        healthManager.startRunning()
                    }) {
                        Image(systemName: "play.fill")
                            .foregroundColor(.green)
                    }
                    .disabled(healthManager.isRunning)
                    
                    Button(action: {
                        healthManager.stopRunning()
                    }) {
                        Image(systemName: "stop.fill")
                            .foregroundColor(.red)
                    }
                    .disabled(!healthManager.isRunning)
                }
            }
        }
        .onAppear {
            healthManager.setConnectivity(connectivity)
        }
    }
}
