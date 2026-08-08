//
//  EmojiWatchView.swift
//  DeepMeiWatch
//
//  手表版第一个功能：长按切换 49 个树莓酱表情包，按住加速变成随机抽卡。
//

import SwiftUI
import WatchKit

struct EmojiWatchView: View {
    @State private var emojiIndex = Int.random(in: 1...49)
    @State private var isPressing = false
    @State private var spinActive = false
    @State private var switchTask: Task<Void, Never>?

    /// 所有表情统一整体下移的偏移量（pt）。只调这个数字即可整体调整位置。
    private let verticalAdjustment: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                Image("\(emojiIndex)")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .center
                    )
                    .offset(y: verticalAdjustment)
                    .scaleEffect(isPressing ? 0.94 : 1)
                    .contentTransition(.opacity)
            }
            .contentShape(Rectangle())
            .onLongPressGesture(
                minimumDuration: 0.4,
                maximumDistance: 40,
                pressing: { isPressing in
                    if isPressing {
                        beginPress()
                    } else {
                        endPress()
                    }
                },
                perform: startSpin
            )
        }
        .ignoresSafeArea()
        .accessibilityLabel("树莓酱表情")
        .accessibilityHint("长按加速抽卡，松手出结果")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            switchEmoji(haptic: true)
        }
    }

    private func beginPress() {
        withAnimation(.easeOut(duration: 0.12)) {
            isPressing = true
        }
    }

    private func endPress() {
        let didSpin = spinActive
        withAnimation(.easeIn(duration: 0.12)) {
            isPressing = false
        }
        spinActive = false
        switchTask?.cancel()
        switchTask = nil
        if didSpin {
            WKInterfaceDevice.current().play(.success)
        }
    }

    /// 长按成功后：先切一次并震动，然后开始越来越快的连续切换。
    private func startSpin() {
        spinActive = true
        switchEmoji(haptic: true)

        switchTask?.cancel()
        switchTask = Task { @MainActor in
            // 初始 0.35 秒一次，每步加快 0.025 秒，最快 0.05 秒一次（上限）。
            var interval: UInt64 = 350_000_000
            let minimum: UInt64 = 50_000_000
            while !Task.isCancelled, spinActive {
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled, spinActive else { return }
                switchEmoji(haptic: false)
                if interval > minimum {
                    interval = max(minimum, interval - 25_000_000)
                }
            }
        }
    }

    private func switchEmoji(haptic: Bool) {
        var next = Int.random(in: 1...49)
        if next == emojiIndex {
            next = emojiIndex == 49 ? 1 : emojiIndex + 1
        }
        if haptic {
            WKInterfaceDevice.current().play(.click)
        }
        withAnimation(.easeInOut(duration: haptic ? 0.2 : 0.06)) {
            emojiIndex = next
        }
    }
}

#Preview {
    EmojiWatchView()
}
