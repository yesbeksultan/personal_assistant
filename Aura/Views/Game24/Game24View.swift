import SwiftUI
import SwiftData

// MARK: - Game24View

struct Game24View: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm = Game24ViewModel()
    @State private var showHistory = false
    @FocusState private var expressionFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppColors.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Difficulty Picker
                    difficultyPicker
                        .padding(.top, 8)

                    if vm.gameState == .idle {
                        idleScreen
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                // Timer
                                timerRow

                                // Cards
                                cardRow

                                // Expression input
                                expressionSection

                                // Action Buttons
                                actionButtons

                                // Result Banner
                                if vm.gameState == .solved || vm.gameState == .failed {
                                    resultBanner
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 120)
                        }
                    }
                }
            }
            .navigationTitle("Игра 24")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .foregroundStyle(AppColors.textPrimary.opacity(0.65))
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                Game24HistoryView()
            }
            .overlay {
                if vm.showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                vm.showConfetti = false
                            }
                        }
                }
            }
        }
    }

    // MARK: - Difficulty Picker

    private var difficultyPicker: some View {
        HStack(spacing: 0) {
            ForEach(Game24Difficulty.allCases, id: \.rawValue) { level in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        vm.difficulty = level
                    }
                } label: {
                    Text("\(level.emoji) \(level.title)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(vm.difficulty == level
                            ? Color(hex: level.colorHex)
                            : AppColors.textPrimary.opacity(0.4))
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(
                            vm.difficulty == level
                                ? Color(hex: level.colorHex).opacity(0.15)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(4)
        .background(AppColors.textPrimary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Idle Screen

    private var idleScreen: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(spacing: 16) {
                Text("24")
                    .font(.system(size: 100, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "f093fb"), Color(hex: "f5576c")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "f5576c").opacity(0.4), radius: 20, x: 0, y: 10)

                Text("Математическая головоломка")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.6))

                Text("Из 4 чисел получи 24\nиспользуя + − × ÷")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.4)) {
                    vm.startNewGame()
                }
                expressionFocused = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Начать игру")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "f093fb"), Color(hex: "f5576c")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: Color(hex: "f5576c").opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Timer Row

    private var timerRow: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: 13))
                Text(vm.timerDisplay)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(AppColors.textPrimary.opacity(0.55))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(AppColors.textPrimary.opacity(0.07))
            .clipShape(Capsule())
        }
        .padding(.top, 12)
    }

    // MARK: - Card Row

    private var cardRow: some View {
        HStack(spacing: 14) {
            ForEach(Array(vm.cards.enumerated()), id: \.offset) { _, num in
                CardTile(number: num, difficulty: vm.difficulty)
            }
        }
    }

    // MARK: - Expression Section

    private var expressionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Твоё выражение")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.textPrimary.opacity(0.4))

            HStack(spacing: 12) {
                TextField("например: (3 + 1) × 6", text: $vm.expression)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppColors.textPrimary)
                    .focused($expressionFocused)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !vm.expression.isEmpty {
                    Button {
                        vm.expression = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                    }
                }
            }
            .padding(16)
            .background(AppColors.textPrimary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.textPrimary.opacity(0.1), lineWidth: 1)
            )

            // Quick operator buttons
            HStack(spacing: 10) {
                ForEach(["+", "-", "×", "÷", "(", ")"], id: \.self) { op in
                    Button {
                        vm.expression += op
                    } label: {
                        Text(op)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(AppColors.textPrimary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            // Error message
            if let error = vm.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .font(.system(size: 13))
                }
                .foregroundStyle(Color(hex: "f5576c"))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Give up
            Button {
                withAnimation {
                    vm.giveUp(modelContext: modelContext)
                }
            } label: {
                Text("Сдаться")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AppColors.textPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Check
            Button {
                withAnimation {
                    vm.submitExpression(modelContext: modelContext)
                }
                expressionFocused = false
            } label: {
                Text("Проверить")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "f093fb"), Color(hex: "f5576c")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color(hex: "f5576c").opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
    }

    // MARK: - Result Banner

    private var resultBanner: some View {
        VStack(spacing: 16) {
            if vm.gameState == .solved {
                VStack(spacing: 8) {
                    Text("🎉 Решено!")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "43e97b"))
                    Text("Время: \(vm.timerDisplay)")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                }
            } else {
                VStack(spacing: 8) {
                    Text("😔 Не получилось")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "f5576c"))
                    Text("Попробуй ещё раз!")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                }
            }

            Button {
                withAnimation(.spring(response: 0.4)) {
                    vm.startNewGame()
                }
                expressionFocused = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.trianglehead.clockwise")
                    Text("Новая задача")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "f093fb"), Color(hex: "f5576c")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color(hex: "f5576c").opacity(0.35), radius: 10, x: 0, y: 5)
            }
        }
        .padding(20)
        .background(AppColors.textPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}

// MARK: - Card Tile

struct CardTile: View {
    let number: Int
    let difficulty: Game24Difficulty

    @State private var appeared = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: difficulty.colorHex).opacity(0.25),
                            Color(hex: difficulty.colorHex).opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(hex: difficulty.colorHex).opacity(0.35), lineWidth: 1.5)
                )

            Text("\(number)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: difficulty.colorHex))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.72, contentMode: .fit)
        .shadow(color: Color(hex: difficulty.colorHex).opacity(0.2), radius: 8, x: 0, y: 4)
        .scaleEffect(appeared ? 1 : 0.5)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(Double.random(in: 0...0.2))) {
                appeared = true
            }
        }
        .onChange(of: number) {
            appeared = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(Double.random(in: 0...0.2))) {
                appeared = true
            }
        }
    }
}

// MARK: - Confetti View (simple particle burst)

struct ConfettiView: View {
    private let particles = (0..<60).map { _ in ConfettiParticle() }

    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { i in
                ConfettiParticleView(particle: particles[i])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

struct ConfettiParticle {
    var x: CGFloat = CGFloat.random(in: 0.1...0.9)
    var color: Color = [
        Color(hex: "f093fb"), Color(hex: "43e97b"),
        Color(hex: "4facfe"), Color(hex: "fee140"),
        Color(hex: "f5576c")
    ].randomElement()!
    var size: CGFloat = CGFloat.random(in: 6...14)
    var delay: Double = Double.random(in: 0...0.5)
    var rotation: Double = Double.random(in: 0...360)
}

struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    @State private var offsetY: CGFloat = -50
    @State private var opacity: Double = 1

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 2)
                .fill(particle.color)
                .frame(width: particle.size, height: particle.size * 0.5)
                .rotationEffect(.degrees(particle.rotation))
                .position(x: geo.size.width * particle.x, y: offsetY)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.8).delay(particle.delay)) {
                        offsetY = geo.size.height + 60
                        opacity = 0
                    }
                }
        }
    }
}
