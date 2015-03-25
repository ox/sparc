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

class Host : Deserializable {
  var host : String = ""
  var user : String?
  var cert : String?

  required init(data: [String : AnyObject]) {
    user <<< data["user"]
    cert <<< data["cert"]
  }
}

class ArcRC : Deserializable {
  var hosts : [String:Host]?
  
  required init(data: [String:AnyObject]) {
    for (hostURL, contents) in data {
      var lhost : Host?
      lhost <<<< contents
      lhost?.host = hostURL
    }
  }
}

class Phabricator {
  var host : NSURL?
  var connected : Bool = false
  var userPHID : String = ""
  private var username : String?
  private var certificate : String?
  private var sessionKey : String?
  private var connectionID : Int?
  
  init(atURL: NSURL, forUser: String, withCert: String) {
    self.host = atURL
    self.username = forUser
    self.certificate = withCert
  }
  
  init?(arcRCFilePath: String) {
    var readError : NSError?
    let jsonData = NSData(contentsOfFile: arcRCFilePath, options: .DataReadingMappedIfSafe, error: &readError)
    if readError != nil {
      NSLog("error reading ~/.arcrc: %@", readError!)
      return nil
    }
    
    var jsonError : NSError?
    var arc = NSJSONSerialization.JSONObjectWithData(jsonData!, options: .MutableContainers, error: &jsonError) as NSDictionary
    if jsonError != nil {
      NSLog("error parsing json in ~/.arcrc: %@", jsonError!)
      return nil
    }

    if let hosts = arc["hosts"] as? NSDictionary {
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
    let requestUrl = host?.URLByAppendingPathComponent(endpoint)
    
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
  
    var promise = PromiseSource<AnyObject>()
    Alamofire.request(.POST, requestUrl!, parameters: parameters)
      .responseJSON { (request: NSURLRequest, response: NSHTTPURLResponse?, json, error) in
        NSLog("%@ request to %@ with body:\n\t%@", request.HTTPMethod!, requestUrl!,
          NSString(data: request.HTTPBody!, encoding: NSUTF8StringEncoding)!)
        
        if let json = JSONObject(json) {
          NSLog("response from %@ with:\n\t%@", requestUrl!, json)
        }
      }
      .responseJSONPromise()
      .then { json in
          let swiftyjson = JSON(json)
          
          // Check if there's an error returned from Phabricator
          if let error_info = swiftyjson["error_info"].string {
            NSLog("request error: %@", error_info)
            promise.reject(NSError(domain: "json", code: 3, userInfo: ["error": error_info]))
            return
          }
 
          promise.resolve(json)
        }
    
    return promise.promise
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
      "host": String(format: "%@://%@", host!.scheme!, host!.host!),
      "authToken": token,
      "authSignature": signature.lowercaseString
    ]
    
    // Request a connectionID, sessionKey, and the user PHID
    sendRequest(.POST, endpoint: "conduit.connect", params: conduitParameters)
      .then { json in
        let json = JSON(json)
        // The token request was good, save the values
        let result = json["result"]
        self.connectionID = result["connectionID"].int
        self.sessionKey = result["sessionKey"].string
        self.userPHID = result["userPHID"].string!
        self.connected = true
        promise.resolve([:])
      }
    
    return promise.promise
  }
  
  func getAuthoredDiffs() -> Promise<AnyObject> {
    var promise = PromiseSource<AnyObject>()
    
    if !self.connected {
      promise.reject(NSError(domain: "err", code: 2, userInfo: nil))
      return promise.promise
    }
    
    let queryParams : [String:AnyObject] = [
      "authors" : NSArray(object: self.userPHID),
      "status": "status-open"
    ]
    
    sendRequest(.POST, endpoint: "differential.query", params: queryParams)
      .then { json in
        let json = JSON(json)
        let result = json["result"]
        var diffs : [Diff]?
        diffs <<<<* result.rawValue
        promise.resolve(diffs!.filter { $0.status == .NeedsRevision || $0.status == .Accepted })
      }
    
    return promise.promise
  }
  
  func getDiffsToReview() -> Promise<AnyObject> {
    var promise = PromiseSource<AnyObject>()
    
    if !self.connected {
      promise.reject(NSError(domain: "err", code: 2, userInfo: nil))
      return promise.promise
    }
    
    let queryParams : [String:AnyObject] = [
      "reviewers" : NSArray(object: self.userPHID),
      "status": "status-open"
    ]
    
    sendRequest(.POST, endpoint: "differential.query", params: queryParams)
      .then { json in
        let json = JSON(json)
        let result = json["result"]
        var diffs : [Diff]?
        diffs <<<<* result.rawValue
        promise.resolve(diffs!.filter { $0.status == .NeedsReview })
    }
    
    return promise.promise
  }
}
