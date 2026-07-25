//
//  NFCScanner.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/26.
//


import Foundation
import CoreNFC


class NFCScanner:
NSObject,
ObservableObject,
NFCNDEFReaderSessionDelegate {


    var session:NFCNDEFReaderSession?


    var result:String=""


    func scan(){


        session =
        NFCNDEFReaderSession(
            delegate:self,
            queue:nil
        )


        session?.alertMessage =
        "请靠近树莓 NFC 卡"


        session?.begin()

    }


    func readerSession(
        _ session:NFCNDEFReaderSession,
        didInvalidateWithError error:Error
    ){

        print(error)

    }


    func readerSession(
        _ session:NFCNDEFReaderSession,
        didDetectNDEFs messages:[NFCNDEFMessage]
    ){

        for message in messages {


            for record in message.records {


                if let text =
                    String(
                    data:record.payload,
                    encoding:.utf8
                    ){

                    result=text

                }

            }

        }

    }

}