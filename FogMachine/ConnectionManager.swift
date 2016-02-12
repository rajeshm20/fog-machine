//
//  ConnectionManager.swift
//  FogMachine
//
//  Created by Tyler Burgett on 8/10/15.
//  Copyright (c) 2015 NGA. All rights reserved.
//

import Foundation
import PeerKit
import MultipeerConnectivity

protocol MPCSerializable {
    var mpcSerialized: NSData { get }
    init(mpcSerialized: NSData)
}


struct ConnectionManager {
    

    static private let serialQueue = dispatch_queue_create("mil.nga.magic.fog", DISPATCH_QUEUE_SERIAL)
    static private var receiptAssurance = ReceiptAssurance(sender: Worker.getMe().displayName)
    
    
    // MARK: Properties
    
    
    private static var peers: [MCPeerID] {
        return PeerKit.masterSession.allConnectedPeers() ?? []
    }
    
    static var otherWorkers: [Worker] {
        return peers.map { Worker(peer: $0) }
    }
    
    static var allWorkers: [Worker] {
        return [Worker.getMe()] + otherWorkers
    }
    
    
    // MARK: Start
    
    
    static func start() {
        NSLog("Transceiving")
        transceiver.startTransceiving(serviceType: Fog.SERVICE_TYPE)
    }
    
    
    // MARK: Event handling
    
    
    static func onConnect(run: PeerBlock?) {
        NSLog("Connection made")
        PeerKit.onConnect = run
    }
    
    static func onDisconnect(run: PeerBlock) {
        PeerKit.onDisconnect = run
    }
    
    static func onEvent(event: Event, run: ObjectBlock?) {
        if let run = run {
            PeerKit.eventBlocks[event.rawValue] = run
        } else {
            PeerKit.eventBlocks.removeValueForKey(event.rawValue)
        }
    }
    
    
    // MARK: Sending
    
    
    static func sendEvent(event: Event, object: [String: MPCSerializable]? = nil, toPeers peers: [MCPeerID]? =
        PeerKit.masterSession.allConnectedPeers()) {
        var anyObject: [String: NSData]?
        if let object = object {
            anyObject = [String: NSData]()
            for (key, value) in object {
                anyObject![key] = value.mpcSerialized
            }
        }
        PeerKit.sendEvent(event.rawValue, object: anyObject, toPeers: peers)
    }
    
    
    static func processResult(event: Event, responseEvent: Event, sender: String, object: [String: MPCSerializable], responseMethod: () -> (), completeMethod: () -> ()) {
        //dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
        dispatch_barrier_async(self.serialQueue) {
        
            responseMethod()
            printOut("processResult from \(sender)")
            receiptAssurance.updateForReceipt(responseEvent, receiver: sender)
            
          //  dispatch_async(dispatch_get_main_queue()) {

            if receiptAssurance.checkAllReceived(responseEvent) {
                printOut("Running completeMethod()")
                completeMethod()
                receiptAssurance.removeAllForEvent(responseEvent)
            } else if receiptAssurance.checkForTimeouts(responseEvent) {
                printOut("Timeout found")
                self.reprocessWork(responseEvent)
            } else {
                printOut("Not done and no timeouts yet.")
            }
            
         //   }
        }
    }
    
    
    static func sendEventTo(event: Event, object: [String: MPCSerializable]? = nil, sendTo: String) {
        var anyObject: [String: NSData]?
        if let object = object {
            anyObject = [String: NSData]()
            for (key, value) in object {
                anyObject![key] = value.mpcSerialized
            }
        }
        
        for peer in peers {
            if peer.displayName == sendTo {
                let toPeer:[MCPeerID] = [peer]
                //if willThrottle {
                    //This is not currently needed, but keeping it here in case it's used for other testing/debugging
                    //self.throttle()
                //}
                PeerKit.sendEvent(event.rawValue, object: anyObject, toPeers: toPeer)
                break
            }
        }

    }
    
    
    static func throttle() {
        // I dislike sleep's but this was being used so the Multipeer Connectivity doesn't send events too fast to the same peer. (The events will go *poof* and never get sent if the sleep doesn't throttle them.) Although this does not always work so it might be related to some other unknown issue.
        let sleepAmount:UInt32 = UInt32(peers.count * 5 + 1)
        //Output is here as a reminder that there is a sleep
        NSLog("I NEEDZ NAP FOR \(sleepAmount) SECONDZ")
        let alignment = "\t\t\t\t\t\t\t\t\t\t\t\t\t"
        print("\(alignment)           /\\_/\\ ")
        print("\(alignment)      ____/ o o \\ ")
        print("\(alignment)    /~____  =ø= /  ")
        print("\(alignment)   (______)__m_m)  ")
        sleep(UInt32(arc4random_uniform(sleepAmount) + sleepAmount))
    }
    
    
//    static func sendEventToPeer<T: Work>(event: Event, willThrottle: Bool = false, workForPeer: (count: Int) -> (T), workForSelf: (Int) -> (), log: (String) -> (), selectedWorkersCount: Int, selectedPeers: Array<String>) { //, peerName: String) {
//        
//        workForSelf(selectedWorkersCount)
//        // The barrier is used to sync sends to receipts and prevent a really fast device from finishing and sending results back before any other device has been sent their results, causing the response queue to only have one sent entry
//        // The processResult function uses the same barrier so the first result is not processed until all the Work has been sent out
//        dispatch_barrier_async(self.serialQueue) {
//            for peerName in selectedPeers {
//                //if peer.displayName == peerName {
//                hasReceivedResponse[Worker.getMe().displayName] = [event.rawValue:[peerName: false]]
//                let theWork = workForPeer(count: selectedWorkersCount)
//                self.sendEventTo(event, willThrottle: willThrottle, object: [event.rawValue: theWork], sendTo: peerName)
//                log(peerName)
//            }
//        }
//    }
    
    static func sendEventToAll<T: Work>(event: Event, timeoutSeconds: Double = 30.0, workForPeer: (Int) -> (T), workForSelf: (Int) -> (), log: (String) -> ()) {
        
        workForSelf(allWorkers.count)
        
        // The barrier is used to sync sends to receipts and prevent a really fast device from finishing and sending results back before any other device has been sent their results, causing the response queue to only have one sent entry
        // The processResult function uses the same barrier so the first result is not processed until all the Work has been sent out
        dispatch_barrier_async(self.serialQueue) {
            for peer in peers {
                let theWork = workForPeer(allWorkers.count)
                
                receiptAssurance.add(peer.displayName, event: event, work: theWork, timeoutSeconds:  timeoutSeconds)
                
                self.sendEventTo(event, object: [event.rawValue: theWork], sendTo: peer.displayName)
                log(peer.displayName)
            }
        }
        receiptAssurance.startTimer(event, timeoutSeconds: timeoutSeconds)
    }
    
    
    static func checkForTimeouts(responseEvent: Event) {
        printOut("timer in ConnectionManager")
        
        while receiptAssurance.checkForTimeouts(responseEvent) {
            printOut("detected timed out work")
            self.reprocessWork(responseEvent)
        }
    }
    
    
    static func reprocessWork(responseEvent: Event) {
        let peer = receiptAssurance.getFinishedPeer(responseEvent)
        
        if let finishedPeer = peer {
            printOut("found peer \(finishedPeer) to finish work")
            let work = receiptAssurance.getNextTimedOutWork(responseEvent)
            
            if let timedOutWork = work {
                printOut("found work to finish")
                self.sendEventTo(responseEvent, object: [responseEvent.rawValue: timedOutWork], sendTo: finishedPeer)
            }
        }
    }
    
    
    static func sendEventForEach(event: Event, objectBlock: () -> ([String: MPCSerializable])) {
        for peer in peers {
            sendEvent(event, object: objectBlock(), toPeers: [peer])
        }
    }
 
    
    static func printOut(output: String) {
        dispatch_async(dispatch_get_main_queue()) {
            //NSLog(output)
        }
    }
    
}
