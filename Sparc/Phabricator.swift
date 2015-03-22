//
//  Phabricator.swift
//  Sparc
//
//  Created by Artem Titoulenko on 3/21/15.
//  Copyright (c) 2015 Artem Titoulenko. All rights reserved.
//

import Cocoa
import Foundation
import Alamofire
import CryptoSwift
import SwiftyJSON
import JSONHelper
import Promissum

class Phabricator {
  var host : NSURL
  var connected : Bool = false
  private var username : String?
  private var certificate : String?
  private var sessionKey : String?
  private var connectionID : Int?
  private var userPHID : String?
  
  init(atURL: NSURL) {
    host = atURL
  }
  
  init(arcRCFilePath: String) {
    self.host = NSURL(string: "")!
    
    let jsonData = NSData(contentsOfFile: arcRCFilePath, options: .DataReadingMappedIfSafe, error: nil)
    var jsonError : NSError?
    var arc = NSJSONSerialization.JSONObjectWithData(jsonData!, options: .MutableContainers, error: &jsonError) as NSDictionary
    
    if let hosts = arc["hosts"]! as? NSDictionary {
      let key = hosts.allKeys[0] as String
      let firstHost = hosts.valueForKey(key) as NSDictionary
      self.host = NSURL(string: key)!
      
      if let uname = firstHost["user"] as? String {
        self.username = uname
      }
      
      if let cert = firstHost["cert"] as? String {
        self.certificate = cert
      }
    } else {
      NSLog("json error: \(jsonError)")
    }
  }
  
  // send a request to Conduit. This method json serialzes the Dictionary, and provides a pretty raw callback which will be called
  // when the request returns
  private func sendRequest(type: Alamofire.Method, endpoint : String, params : [String:AnyObject]) -> Promise<AnyObject> {
      
      let requestUrl = host.URLByAppendingPathComponent(endpoint)
      
      var localParams = params
      
      if self.connected {
        localParams["__conduit__"] = [
          "sessionKey": self.sessionKey!,
          "connectionID": self.connectionID!
        ]
      }
      
      let jsonSerializedConduitParams = NSJSONSerialization.dataWithJSONObject(localParams, options:NSJSONWritingOptions(0), error: nil)
      let stringEncodedSerializedConduitParams = NSString(data: jsonSerializedConduitParams!, encoding: NSUTF8StringEncoding) as NSString!
      
      var parameters : [String: AnyObject] = [
        "params": stringEncodedSerializedConduitParams,
        "output": "json",
        "__conduit__": true
      ]
      
      return Alamofire.request(.POST, requestUrl, parameters: parameters).responseJSONPromise()
  }
  
  // Connect to conduit to retrieve a session key, connection ID, and the user PHID
  func connect() -> Promise<AnyObject> {
    var promise = PromiseSource<AnyObject>()
    
    // Create the conduit request to be able to fetch a token
    let date = NSDate()
    let token = Int(date.timeIntervalSince1970)
    var bytes = String(format: "%d%@", token, self.certificate!)
    let data : NSData = NSData(bytes: &bytes, length: sizeof(bytes.dynamicType))
    let signature = bytes.sha1() as String!
    let conduitParameters : [String:AnyObject] = [
      "client": "Sparc",
      "clientVersion": 0,
      "clientDescription": "A menubar app for managing your diffs",
      "user": username!,
      "host": String(format: "%@://%@", host.scheme!, host.host!),
      "authToken": token,
      "authSignature": signature.lowercaseString
    ]
    
    // Request a connectionID, sessionKey, and the user PHID
    sendRequest(.POST, endpoint: "conduit.connect", params: conduitParameters)
      .then { json in
        let json = JSON(json)
        
        // Check if there's an error returned from Phabricator
        if let error_info = json["error_info"].string {
          NSLog("request error: %@", error_info)
          promise.reject(NSError(domain: "err", code: 2, userInfo: [:]))
          return
        }
    
        // The token request was good, save the values
        let result = json["result"]
        self.connectionID = result["connectionID"].int
        self.sessionKey = result["sessionKey"].string
        self.userPHID = result["userPHID"].string
        self.connected = true
        promise.resolve([:])
      }
    
    return promise.promise
  }
  
  func getAuthoredDiffs(_: AnyObject) -> Promise<AnyObject> {
    var promise = PromiseSource<AnyObject>()
    
    if !self.connected {
      promise.reject(NSError(domain: "err", code: 2, userInfo: nil))
      return promise.promise
    }
    
    let queryParams : [String:AnyObject] = [
      "authors" : NSArray(object: self.userPHID!),
      "status": "status-open"
    ]
    
    sendRequest(.POST, endpoint: "differential.query", params: queryParams)
      .then { json in
        let json = JSON(json)

        // Check if there's an error returned from Phabricator
        if let error_info = json["error_info"].string {
          NSLog("request error: %@", error_info)
          return
        }
        
        let result = json["result"]
        
        println(result)
        
        var diffs : [Diff]?
        diffs <<<<* result.rawValue // I really hate this syntax
        promise.resolve(diffs!)
      }
    
    return promise.promise
  }
}
