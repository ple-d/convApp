//
//  structs.swift
//  conversationApp
//
//  Created by XO on 23.08.2021.
//  Copyright © 2021 XO. All rights reserved.
//

import Foundation

struct Message: MessageType {
    var sender: Sender
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
}

struct Sender: SenderType {
    var photoURL: String
    var senderId: String
    var displayName: String
}
