//
//  AppDelegate.swift
//  Sparc
//
//  Created by Artem Titoulenko on 3/18/15.
//  Copyright (c) 2015 Artem Titoulenko. All rights reserved.
//

import Cocoa
import Foundation
import Alamofire
import CryptoSwift

typealias PhabricatorToken = NSString

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
  private func sendRequest(type: Alamofire.Method, endpoint : String, params : [String:AnyObject],
    completionHandler: ((NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void)?) {
      
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

    if let handler = completionHandler? {
      Alamofire.request(.POST, requestUrl, parameters: parameters)
        .responseJSON(completionHandler: handler)
    }

  }
  
  // Connect to conduit to retrieve a session key, connection ID, and the user PHID
  func connect(callback: ((NSError!) -> Void)?) {
    
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
    sendRequest(.POST, endpoint: "conduit.connect", params: conduitParameters) { (_, _, JSON, error) in
      if error != nil {
        NSLog("error contacting Phabricator: %@", error!)
        if let handler = callback {
          handler(error)
        }
        return
      }
      
      // Check if there's an error returned from Phabricator
      if let error_info = JSON!["error_info"] as? String {
        NSLog("request error: %@", error_info)
        return
      }
      
      // The token request was good, save the values
      if let result = JSON!["result"] as? NSDictionary {
        self.connectionID = result["connectionID"] as? Int
        self.sessionKey = result["sessionKey"] as? String
        self.userPHID = result["userPHID"] as? String
        
        self.connected = true
        if let handler = callback {
          handler(error)
        }
      }
    }
  }
  
  func getAuthoredDiffs() -> NSError! {
    if !self.connected {
      return NSError(domain: "err", code: 2, userInfo: nil)
    }
    
    let queryParams : [String:AnyObject] = [
      "authors" : NSArray(object: self.userPHID!),
      "status": "status-open"
    ]
  
    sendRequest(.POST, endpoint: "differential.query", params: queryParams) { (request, _, JSON, error) in
      if error != nil {
        NSLog("error contacting Phabricator: %@", error!)
        return
      }
      
      // Check if there's an error returned from Phabricator
      if let error_info = JSON!["error_info"] as? String {
        NSLog("request error: %@", error_info)
        return
      }
      
      if let result = JSON!["result"] as? NSArray {
        println("diffs:\n")
        for diff in result {
          let ldiff = diff as? NSDictionary
          let statusName = ldiff?.valueForKey("statusName") as String!
          let id = ldiff?.valueForKey("id") as String!
          let title = ldiff?.valueForKey("title") as String!
          let diffTitle = NSString(format: "%@: %@ - %@", statusName, id, title)
          println(diffTitle)
        }
      }
    }
    
    return nil
  }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var userDefaults = NSUserDefaults.standardUserDefaults()
  
    var API : Phabricator?
  
    // Settings window
    @IBOutlet weak var settingsWindow: NSWindow!
    
    // NSMenu
    @IBOutlet weak var statusMenu: NSMenu!
    @IBAction func settingsMenuItem(sender: AnyObject) {
        settingsWindow.makeKeyAndOrderFront(sender)
        NSApp.activateIgnoringOtherApps(true)
    }
    
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let defaultsToRegister = ["PhabricatorUrl": ""]
        userDefaults.registerDefaults(defaultsToRegister)
        userDefaults.synchronize()
        
        // The text that will be shown in the menu bar
        statusItem.title = "Sparc";
        statusItem.menu = statusMenu
        
        API = Phabricator(arcRCFilePath: "~/.arcrc".stringByExpandingTildeInPath)
        API!.connect { (error: NSError!) -> Void in
          self.API?.getAuthoredDiffs()
          return
        }
    }
    
    func addMenuItem(title: String, selector: Selector) {
        //Add menuItem to menu
        var menuItem : NSMenuItem = NSMenuItem()
        menuItem.title = title
        menuItem.action = selector
        menuItem.keyEquivalent = ""
        statusMenu.addItem(menuItem)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func setWindowVisible(sender: AnyObject){
        self.settingsWindow.orderFront(self)
    }
    
    func shouldDisplayWindowOnBoot() -> Bool {
        return userDefaults.boolForKey("DisplayWindowOnStartup")
    }
    
    @IBAction func quit(sender: AnyObject?) {
        NSApplication.sharedApplication().terminate(self)
    }
}

