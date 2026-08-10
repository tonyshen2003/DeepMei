//
//  CreditsView.swift
//  DeepMei
//

import SwiftUI

/// 创作者条目。
private struct CreditPerson: Identifiable {
    let name: String
    var alias: String? = nil
    let role: String
    let contribution: String

    var id: String { name }
}

/// 创作者名单：集中管理 DeepMei 的程序员、画师等贡献者。
/// 后续新增贡献者只需在下方数组中追加条目。
struct CreditsView: View {
    /// 程序开发
    private let programmers: [CreditPerson] = [
        CreditPerson(
            name: "沈孙丰",
            role: "开发 / 维护",
            contribution: ""
        )
    ]

    /// 开发支持
    private let supporters: [CreditPerson] = [
        CreditPerson(
            name: "顾衡庭",
            role: "技术指导",
            contribution: "以专业经验为 DeepMei 的开发提供技术指导，为项目稳健推进保驾护航。"
        ),
        CreditPerson(
            name: "黄柯睿",
            role: "开发协助",
            contribution: "在 DeepMei 开发过程中提供辅助与支持，为项目的顺利完成贡献力量。"
        ),
        CreditPerson(
            name: "周熠嘉",
            role: "项目支持",
            contribution: "推动社团数字化转型，为 DeepMei 的开发与落地提供重要支持。"
        )
    ]

    /// 美术设计
    private let artists: [CreditPerson] = [
        CreditPerson(
            name: "刘熙冉",
            role: "Logo 画师",
            contribution: "绘制 DeepMei Logo（应用图标）。"
        ),
        CreditPerson(
            name: "黄绮月",
            role: "Logo 画师",
            contribution: "绘制 DeepMei Logo（应用图标）。"
        )
    ]

    /// 测试
    private let testers: [CreditPerson] = [
        CreditPerson(name: "贾奕博", role: "测试", contribution: ""),
        CreditPerson(name: "顾臻煜", role: "测试", contribution: ""),
        CreditPerson(name: "许楚晗", role: "测试", contribution: "")
    ]

    var body: some View {
        List {
            // MARK: - 程序开发
            Section {
                ForEach(programmers) { person in
                    CreditRow(person: person)
                }
            } header: {
                Text("程序开发")
            }

            // MARK: - 开发支持
            Section {
                ForEach(supporters) { person in
                    CreditRow(person: person)
                }
            } header: {
                Text("开发支持")
            }

            // MARK: - 美术设计
            Section {
                ForEach(artists) { person in
                    CreditRow(person: person)
                }
            } header: {
                Text("美术设计")
            }

            // MARK: - 测试
            Section {
                ForEach(testers) { person in
                    CreditRow(person: person)
                }
            } header: {
                Text("测试")
            }
        }
        .navigationTitle("创作者名单")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 单条创作者展示。
private struct CreditRow: View {
    let person: CreditPerson

    private var displayName: String {
        if let alias = person.alias, !alias.isEmpty {
            return "\(person.name)（\(alias)）"
        }
        return person.name
    }

    private var detail: String {
        person.contribution.isEmpty ? person.role : "\(person.role) · \(person.contribution)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayName)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        CreditsView()
    }
}
