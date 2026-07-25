//
//  MyRaspberryView.swift
//  DeepMei
//

import SwiftUI


struct MyRaspberryView: View {


    @State private var member: Member?


    @StateObject
    private var scanner = NFCScanner()



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



                    Button {


                        scanner.scan()


                    } label: {


                        Label(
                            "刷 NFC 卡",
                            systemImage:"wave.3.right"
                        )


                    }


                }


            }
            .navigationTitle("我的树莓")

        }


        // NFC读取完成
        .onChange(of: scanner.result) { oldValue, newValue in

            guard !newValue.isEmpty else {
                return
            }

            member =
            MemberStore.shared.find(
                id: newValue
            )

        }


    }


}
