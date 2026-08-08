//
//  EmojiWatchView.swift
//  DeepMeiWatch
//
//  手表版第一个功能：点击切换 49 个树莓酱表情包。
//

import SwiftUI
import WatchKit

struct EmojiWatchView: View {
    @State private var emojiIndex = Int.random(in: 1...49)

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
                    .contentTransition(.opacity)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                randomize()
            }
        }
        .ignoresSafeArea()
        .accessibilityLabel("树莓酱表情")
        .accessibilityHint("点击随机切换")
    }

    private func randomize() {
        var next = Int.random(in: 1...49)
        if next == emojiIndex {
            next = emojiIndex == 49 ? 1 : emojiIndex + 1
        }
        WKInterfaceDevice.current().play(.click)
        withAnimation(.easeInOut(duration: 0.2)) {
            emojiIndex = next
        }
    }
}

#Preview {
    EmojiWatchView()
}
