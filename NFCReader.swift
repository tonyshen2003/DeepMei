//
//  Untitled.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/23.
//

import Foundation
import CoreNFC


class NFCReader: NSObject, ObservableObject {

    var session: NFCNDEFReaderSession?


    func startScanning() {

        guard NFCNDEFReaderSession.readingAvailable else {
            print("设备不支持NFC")
            return
        }


        session = NFCNDEFReaderSession(
            delegate: self,
            queue: DispatchQueue.main
        )

        session?.alertMessage = "请靠近社员卡"

        session?.begin()
    }
}


extension NFCReader: NFCNDEFReaderSessionDelegate {


    func readerSessionDidBecomeActive(
        _ session: NFCNDEFReaderSession
    ) {

        print("NFC开始扫描")

    }



    func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetectNDEFs messages: [NFCNDEFMessage]
    ) {

        print("读取成功")

        for message in messages {

            for record in message.records {

                let data = record.payload

                print(data)

            }

        }

    }


    func readerSession(
        _ session: NFCNDEFReaderSession,
        didInvalidateWithError error: Error
    ) {

        print(
            "NFC结束:",
            error.localizedDescription
        )

    }

}
