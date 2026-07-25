//
//  MemberStore.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/26.
//

import Foundation


class MemberStore {

    static let shared = MemberStore()


    var members:[Member] = []


    init(){

        load()

    }


    func load(){

        guard let url =
                Bundle.main.url(
                    forResource:"Member",
                    withExtension:"json"
                )
        else {
            print("Member.json 未找到")
            return
        }


        do {

            let data =
            try Data(contentsOf:url)


            members =
            try JSONDecoder()
                .decode(
                    [Member].self,
                    from:data
                )


        }catch{

            print(error)

        }

    }


    func find(id:String)->Member?{

        members.first{
            $0.id == id
        }

    }


    func find(name:String)->Member?{

        members.first{
            $0.name.lowercased() == name.lowercased()
        }

    }

}
