//
//  DatabaseManager.swift
//  conversationApp
//
//  Created by XO on 23.08.2021.
//  Copyright © 2021 XO. All rights reserved.
//

import Foundation
import FirebaseDatabase




class DatabaseManager {
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAdress: String) -> String {
        var safeEmail = emailAdress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    /*
     
        "unique" {
            "messages": [
                {
                "id": String,
                "type": text, photo, video,
                "content": String,
                "date": Date(),
                "sender_email": String,
                "isRead": true/false
                }
            ]
        }
     
        conversation => [
        [
            "conversation_id":
            "other_user_email":
            "latest_message": => {
                "date": Date()
                "latest_message": "message"
                "is_read": true/false
            }
        ]
     ]
     */
    
    
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping(Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
        let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAdress: currentEmail)
        let reference = database.child("\(safeEmail)")
        reference.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("User not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch firstMessage.kind {
                case .text(let messageText):
                    message = messageText
                case .attributedText(_):
                    return "attributed_text"
                case .photo(_):
                    return "photo"
                case .video(_):
                    return "video"
                case .location(_):
                    return "location"
                case .emoji(_):
                    return "emoji"
                case .audio(_):
                    return "audio"
                case .contact(_):
                    return "contact"
                case .custom(_):
                    return "custom"
            }
            
            let converstionId = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recepient_newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            
            
            
            //update receppitent conversation entry
            self.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: value, with { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    // append
                    conversations.append(recepient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else {
                    // create case
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recepient_newConversationData])
                }
            })
            //update current user conversation entry
            
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                reference.setValue(value: userNode, withCompltionBlock{ [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name,
                                                     conversationID: converstionId,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                    })
            } else {
                userNode["conversations"] = [
                    newConversationData
                ]
                reference.setValue(value: userNode, withCompltionBlock{ [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name,
                                                    conversationID: converstionId,
                                                    firstMessage: firstMessage,
                                                    completion: completion)
                })
            }
        })
    }
    
    private func finishCreatingConversation(name: String, conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
//        {
//        "id": String,
//        "type": text, photo, video,
//        "content": String,
//        "date": Date(),
//        "sender_email": String,
//        "isRead": true/false
//        }
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)

        
        var message = ""
        switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .custom(_):
                break
        }
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(emailAdress: myEmail)
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name
        ]
        
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        database.child("\(email)/conversations").observe(.value, with { snapshot in
            guard let value = snapshot.value as? [[String : Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({dictionary in
                guard let conversationId = dictionary["id"] as? String,
                    let name = dictionary["name"] as? String,
                    let otherUserEmail = dictionary["other_user_email"] as? Bool,
                    let latestMessage = dictionary["latest_message"] as? [String: Any],
                    let date = latestMessage["date"] as? String,
                    let message = latestMessage["message"] as? String,
                    let isRead = latestMessage["is_read"] as? Bool else {
                        return nil
                }
                
            let latestMessageObject = LatestMessage(date: date,
                                                    text: message,
                                                    isRead: isRead)
            return Conversation(id: conversationId,
                                name: name,
                                otherUserEmail: otherUserEmail,
                                latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    
    /// получение всех сообщений из выбранного диалога
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<String, Error>) -> Void) {
        database.child("\(id)/messages").observe(.value, with { snapshot in
            guard let value = snapshot.value as? [[String : Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap({dictionary in
                guard let name = dictionary["name"] as? String,
                let isRead = dictionary["is_read"] as? Bool,
                let messageID = dictionary["id"] as? String,
                let content = dictionary["content"] as? String,
                let senderEmail = dictionary["sender_email"] as? String,
                let type = dictionary["type"] as? String,
                let dateString = dictionary["date"] as? String,
                let date = ChatViewController.dateFormatter.date(from: dateString) else {
                        return nil
                }
                
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: .text(content))
            })
            
            completion(.success(messages))
        })
    }
    
    /// Отправка сообщения
    public func sendMessage(to conversation: String, name: String, newMessage: Message, completion: @escaping(Bool) -> Void) {
        // add new message to messages
        // update sender latest message
        // update recepient latest message
        
        database.child("\(conversation)/messages").observerSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)

            var message = ""
            switch newMessage.kind {
                case .text(let messageText):
                    message = messageText
                case .attributedText(_):
                    break
                case .photo(_):
                    break
                case .video(_):
                    break
                case .location(_):
                    break
                case .emoji(_):
                    break
                case .audio(_):
                    break
                case .contact(_):
                    break
                case .custom(_):
                    break
            }
            
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }
            
            let currentUserEmail = DatabaseManager.safeEmail(emailAdress: myEmail)
            
            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name": name
            ]
            
            currentMessages.append(newMessageEntry)
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                completion(true)
            }
        })
    }
}

extension DatabaseManager {
    
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        self.database.child("\(path)").observeSingleEvent(of: .value) {snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
            
        }
    }
}

// MARK: - Account Managment

extension DatabaseManager {
    
    /// Добавление пользователей
    public func insertUser(with user: ChatAppUser) {
        database.child(user.safeEmail).setValue( [
            "first_name": user.firstName,
            "email_adress": user.emailAdress
        ])
    }
    
}
