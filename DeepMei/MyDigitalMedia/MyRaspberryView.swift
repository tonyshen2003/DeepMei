//
//  MyRaspberryView.swift
//  DeepMei
//

import SwiftUI


struct MyRaspberryView: View {


    @State private var member: Member?


    @State private var memberId: String = ""


    @State private var notFound: Bool = false


    var body: some View {


        NavigationStack {


            VStack(spacing:30) {


                Image(systemName:"apple.logo")
                    .font(.system(size:60))


                Text("我的树莓")
                    .font(.largeTitle)



                if let member {


                    VStack(spacing:10) {


                        Text(member.name)
                            .font(.title)


                        Text(member.title)


                        Text(member.generation)


                    }


                }
                else {


                    Text("未识别身份")



                    TextField(
                        "请输入社员号或姓名",
                        text: $memberId
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("社员号或姓名输入框")
                    .accessibilityHint("请输入您的社员号或姓名进行身份识别")



                    Button {

                        let found =
                        MemberStore.shared.find(
                            id: memberId
                        ) ?? MemberStore.shared.find(
                            name: memberId
                        )

                        member = found

                        notFound = (found == nil && !memberId.isEmpty)

                    } label: {

                        Label(
                            "确认",
                            systemImage:"checkmark.circle"
                        )

                    }



                    if notFound {

                        Text("未找到该社员，请检查输入")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityLabel("未找到社员提示")

                    }


                }


            }
            .navigationTitle("我的树莓")

        }


    }


}
