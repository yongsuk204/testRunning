// testRunning/ContentView.swift

import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var connectivity = Connectivity()
    @State private var heartScale: CGFloat = 1.0
    @State private var pulseAnimation = false
    
    // 심박수에 따른 색상 계산
    private var heartColor: Color {
        let normalizedRate = min(max((connectivity.heartRate - 60) / 140, 0), 1)
        return Color(
            red: 0.5 + normalizedRate * 0.5,
            green: 0.2 * (1 - normalizedRate),
            blue: 0.2 * (1 - normalizedRate)
        )
    }
    
    // 심박수에 따른 애니메이션 속도
    private var animationDuration: Double {
        guard connectivity.heartRate > 0 else { return 1.0 }
        return 60.0 / connectivity.heartRate
    }
    
    var body: some View {
        ZStack {
            // 배경 그라데이션
            LinearGradient(
                colors: connectivity.isRunning ?
                    [Color.black, Color.red.opacity(0.3)] :
                    [Color.black, Color.gray.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // 상태 표시
                Text(connectivity.isRunning ? "RUNNING" : "IDLE")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .foregroundColor(connectivity.isRunning ? .green : .gray)
                    .shadow(color: connectivity.isRunning ? .green : .gray, radius: 10)
                
                if connectivity.isRunning {
                    // 심박수 표시 영역
                    VStack(spacing: 20) {
                        // 애니메이션 하트
                        ZStack {
                            // 배경 펄스 효과
                            Circle()
                                .fill(heartColor.opacity(0.2))
                                .frame(width: 200, height: 200)
                                .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                                .opacity(pulseAnimation ? 0 : 1)
                                .animation(.easeOut(duration: animationDuration), value: pulseAnimation)
                            
                            // 메인 하트
                            Image(systemName: "heart.fill")
                                .font(.system(size: 100))
                                .foregroundColor(heartColor)
                                .scaleEffect(heartScale)
                                .shadow(color: heartColor, radius: 20)
                        }
                        .onAppear {
                            startHeartAnimation()
                        }
                        .onChange(of: connectivity.heartRate) { _ in
                            startHeartAnimation()
                        }
                        
                        // 심박수 수치
                        VStack(spacing: 5) {
                            Text("\(Int(connectivity.heartRate))")
                                .font(.system(size: 60, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("BPM")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        
                        // 심박수 범위 표시
                        HStack {
                            ForEach(0..<5) { index in
                                Rectangle()
                                    .fill(heartRateBarColor(index: index))
                                    .frame(width: 40, height: 20)
                                    .cornerRadius(5)
                            }
                        }
                        .padding(.top, 20)
                    }
                } else {
                    // IDLE 상태 아이콘
                    Image(systemName: "figure.stand")
                        .font(.system(size: 150))
                        .foregroundColor(.gray)
                        .opacity(0.5)
                }
            }
            .padding()
        }
    }
    
    private func startHeartAnimation() {
        withAnimation(.easeInOut(duration: animationDuration * 0.3)) {
            heartScale = 1.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.3) {
            withAnimation(.easeInOut(duration: animationDuration * 0.3)) {
                heartScale = 1.0
            }
        }
        
        // 펄스 애니메이션
        pulseAnimation = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pulseAnimation = true
        }
        
        // 반복
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            if connectivity.isRunning && connectivity.heartRate > 0 {
                startHeartAnimation()
            }
        }
    }
    
    private func heartRateBarColor(index: Int) -> Color {
        let threshold = Double(index + 1) * 30 + 50 // 50, 80, 110, 140, 170
        return connectivity.heartRate >= threshold ? heartColor : Color.gray.opacity(0.3)
    }
}
