// testRunning/ContentView.swift
// 역할: iPhone 앱의 메인 UI - 심박수를 시각적으로 표시

import SwiftUI
import SceneKit

struct ContentView: View {
    // @StateObject: 뷰가 소유하는 ObservableObject 인스턴스
    @StateObject private var connectivity = Connectivity()  // Watch와의 통신 담당
    
    // @State: 뷰의 상태를 저장하는 프로퍼티 래퍼
    @State private var heartScale: CGFloat = 1.0     // 하트 아이콘의 크기 (애니메이션용)
    @State private var pulseAnimation = false         // 펄스 효과 애니메이션 트리거
    
    // 심박수에 따른 색상 계산 (computed property)
    private var heartColor: Color {
        // 심박수를 60-200 범위에서 0-1로 정규화
        // 60 BPM 이하: 0, 200 BPM 이상: 1
        let normalizedRate = min(max((connectivity.heartRate - 60) / 140, 0), 1)
        
        // 빨간색 성분: 0.5에서 1.0 (심박수가 높을수록 더 빨갛게)
        // 초록/파랑 성분: 0.2에서 0 (심박수가 높을수록 감소)
        return Color(
            red: 0.5 + normalizedRate * 0.5,
            green: 0.2 * (1 - normalizedRate),
            blue: 0.2 * (1 - normalizedRate)
        )
    }
    
    // 심박수에 따른 애니메이션 속도 계산
    private var animationDuration: Double {
        guard connectivity.heartRate > 0 else { return 1.0 }
        // 60 BPM = 1초에 1번, 120 BPM = 0.5초에 1번
        return 60.0 / connectivity.heartRate
    }
    
    var body: some View {
        ZStack {  // 레이어를 겹쳐서 표시하는 컨테이너
            // 배경 그라데이션
            LinearGradient(
                colors: connectivity.isRunning ?
                    [Color.black, Color.red.opacity(0.3)] :    // 런닝 중: 검정-빨강 그라데이션
                    [Color.black, Color.gray.opacity(0.3)],    // 대기 중: 검정-회색 그라데이션
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()  // 안전 영역 무시하고 전체 화면 채우기
            
            VStack(spacing: 40) {  // 수직 스택, 요소 간 간격 40
                // 상태 표시 텍스트
                Text(connectivity.isRunning ? "RUNNING" : "IDLE")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .foregroundColor(connectivity.isRunning ? .green : .gray)
                    .shadow(color: connectivity.isRunning ? .green : .gray, radius: 10)  // 네온 효과
                
                if connectivity.isRunning {
                    // 런닝 중일 때 심박수 표시 영역
                    VStack(spacing: 20) {
                        // 애니메이션 하트 영역
                        ZStack {
                            // 배경 펄스 효과 (원이 커지면서 사라지는 효과)
                            Circle()
                                .fill(heartColor.opacity(0.2))
                                .frame(width: 200, height: 200)
                                .scaleEffect(pulseAnimation ? 1.3 : 1.0)  // 1.0에서 1.3배로 확대
                                .opacity(pulseAnimation ? 0 : 1)           // 불투명에서 투명으로
                                .animation(.easeOut(duration: animationDuration), value: pulseAnimation)
                            
                            // 메인 하트 아이콘
                            Image(systemName: "heart.fill")
                                .font(.system(size: 100))
                                .foregroundColor(heartColor)
                                .scaleEffect(heartScale)  // 박동 애니메이션용 크기 조절
                                .shadow(color: heartColor, radius: 20)  // 그림자 효과
                        }
                        .onAppear {
                            startHeartAnimation()  // 뷰가 나타날 때 애니메이션 시작
                        }
                        .onChange(of: connectivity.heartRate) { oldValue, newValue in
                            startHeartAnimation()  // 심박수가 변경될 때마다 애니메이션 재시작
                        }
                        
                        // 심박수 수치 표시
                        VStack(spacing: 5) {
                            Text("\(Int(connectivity.heartRate))")  // 정수로 표시
                                .font(.system(size: 60, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("BPM")  // Beats Per Minute
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        
                        // 심박수 범위 표시 바 (5단계)
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
                    // IDLE 상태 아이콘 (서 있는 사람 모양)
                    Image(systemName: "figure.stand")
                        .font(.system(size: 150))
                        .foregroundColor(.gray)
                        .opacity(0.5)
                }
            }
            .padding()
        }
    }
    
    // 하트 박동 애니메이션 시작 함수
    private func startHeartAnimation() {
        // 1. 하트 크기 확대 (박동의 수축기)
        withAnimation(.easeInOut(duration: animationDuration * 0.3)) {
            heartScale = 1.2
        }
        
        // 2. 하트 크기 축소 (박동의 이완기)
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.3) {
            withAnimation(.easeInOut(duration: animationDuration * 0.3)) {
                heartScale = 1.0
            }
        }
        
        // 3. 펄스 애니메이션 시작
        pulseAnimation = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pulseAnimation = true
        }
        
        // 4. 다음 박동을 위한 재귀 호출
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            if connectivity.isRunning && connectivity.heartRate > 0 {
                startHeartAnimation()  // 런닝 중이고 심박수가 있으면 계속 반복
            }
        }
    }
    
    // 심박수 범위 바의 색상 결정 함수
    private func heartRateBarColor(index: Int) -> Color {
        // 각 바의 임계값: 50, 80, 110, 140, 170 BPM
        let threshold = Double(index + 1) * 30 + 50
        // 현재 심박수가 임계값 이상이면 활성 색상, 아니면 회색
        return connectivity.heartRate >= threshold ? heartColor : Color.gray.opacity(0.3)
    }
}
