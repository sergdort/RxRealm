//
//  RxRealmLinkingObjectsTests.swift
//  RxRealm
//
//  Created by Marin Todorov on 5/1/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest

import RxSwift
import RealmSwift
import RxRealm
import RxTests

class RxRealmLinkingObjectsTests: XCTestCase {
    
    private func realmInMemory(name: String) -> Realm {
        var conf = Realm.Configuration()
        conf.inMemoryIdentifier = name
        return try! Realm(configuration: conf)
    }
    
    private func clearRealm(realm: Realm) {
        try! realm.write {
            realm.deleteAll()
        }
    }
    
    func testLinkingObjectsType() {
        let expectation1 = expectationWithDescription("LinkingObjects<User> first")
        
        let realm = realmInMemory(#function)
        clearRealm(realm)
        let bag = DisposeBag()
        
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(LinkingObjects<User>)
        
        let message = Message("first")
        try! realm.write {
            realm.add(message)
        }
        
        let users$ = message.mentions.asObservable().shareReplay(1)
        users$.scan(0, accumulator: {acc, _ in return acc+1})
            .filter { $0 == 3 }.map {_ in ()}.subscribeNext(expectation1.fulfill).addDisposableTo(bag)
        users$
            .subscribe(observer).addDisposableTo(bag)
        
        //interact with Realm here
        let user1 = User("user1")
        user1.lastMessage = message

        delay(0.1) {
            try! realm.write {
                realm.add(user1)
            }
        }
        delay(0.2) {
            try! realm.write {
                realm.delete(user1)
            }
        }
        
        scheduler.start()
        
        waitForExpectationsWithTimeout(0.5) {error in
            //do tests here
            
            XCTAssertTrue(error == nil)
            XCTAssertEqual(observer.events.count, 3)
            XCTAssertEqual(message.mentions.count, 0)
        }
    }
    
    func testLinkingObjectsTypeChangeset() {
        let expectation1 = expectationWithDescription("LinkingObjects<User> first")
        
        let realm = realmInMemory(#function)
        clearRealm(realm)
        let bag = DisposeBag()
        
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(String)
        
        let message = Message("first")
        try! realm.write {
            realm.add(message)
        }
        
        let users$ = message.mentions.asObservableChangeset().shareReplay(1)
        users$.scan(0, accumulator: {acc, _ in return acc+1})
            .filter { $0 == 3 }.map {_ in ()}.subscribeNext(expectation1.fulfill).addDisposableTo(bag)
        users$
            .map {linkingObjects, changes in
                if let changes = changes {
                    return "i:\(changes.inserted) d:\(changes.deleted) u:\(changes.updated)"
                } else {
                    return "initial"
                }
            }
            .subscribe(observer).addDisposableTo(bag)
        
        //interact with Realm here
        let user1 = User("user1")
        user1.lastMessage = message
        
        delay(0.1) {
            try! realm.write {
                realm.add(user1)
            }
        }
        delay(0.2) {
            try! realm.write {
                realm.delete(user1)
            }
        }
        
        scheduler.start()
        
        waitForExpectationsWithTimeout(0.5) {error in
            //do tests here
            
            XCTAssertTrue(error == nil)
            XCTAssertEqual(observer.events.count, 3)
            XCTAssertEqual(observer.events[0].value.element!, "initial")
            XCTAssertEqual(observer.events[1].value.element!, "i:[0] d:[] u:[]")
            XCTAssertEqual(observer.events[2].value.element!, "i:[] d:[0] u:[]")
        }
    }
}