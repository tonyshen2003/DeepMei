//
//  MyRaspberryView.swift
//  DeepMei
//

import SwiftUI


struct MyRaspberryView: View {


    @State private var member: Member?


    @State private var memberId: String = ""


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
                        "请输入社员号",
                        text: $memberId
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("社员号输入框")
                    .accessibilityHint("请输入您的社员号进行身份识别")



                    Button {

                        member =
                        MemberStore.shared.find(
                            id: memberId
                        )

                    } label: {

                        Label(
                            "确认",
                            systemImage:"checkmark.circle"
                        )

                    }


                }


            }
            .navigationTitle("我的树莓")

        }


    }


}
