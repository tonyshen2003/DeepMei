//
//  NFCScanner.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/26.
//
import Foundation
import CoreNFC
public import Combine


@MainActor
class NFCScanner: NSObject, ObservableObject {


    @Published var result = ""


    private var session:NFCNDEFReaderSession?


    func scan() {

        session =
        NFCNDEFReaderSession(
            delegate:self,
            queue:nil, invalidateAfterFirstRead: true
        )

        session?.alertMessage =
        "请靠近树莓身份卡"

        session?.begin()

    }

}



extension NFCScanner:
NFCNDEFReaderSessionDelegate {


    nonisolated func readerSession(
        _ session:NFCNDEFReaderSession,
        didInvalidateWithError error:Error
    ){

        print(error)

    }


    nonisolated func readerSession(
        _ session:NFCNDEFReaderSession,
        didDetectNDEFs messages:[NFCNDEFMessage]
    ){

        for message in messages {

            for record in message.records {


                if let value =
                String(
                    data:record.payload,
                    encoding:.utf8
                ){

                    Task { @MainActor in

                        self.result = value

                    }

                }

            }
        }

    }

}
