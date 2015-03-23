//
//  Diff.swift
//  Sparc
//
//  Created by Artem Titoulenko on 3/21/15.
//  Copyright (c) 2015 Artem Titoulenko. All rights reserved.
//

import Foundation
import JSONHelper

class Diff : Deserializable {
  var ID : Int = 0
  var status : Int?
  var statusName : String = ""
  var title : String = ""
  var branch : String = ""
  var URI : NSURL = NSURL()
  
  var createdAt : NSDate = NSDate()
  var modifiedAt : NSDate = NSDate()
  
  var reviewerPHIDs : [String] = []

  convenience required init(data : [String: AnyObject]) {
    self.init()
    ID <<< data["id"]
    status <<< data["status"]
    statusName <<< data["statusName"]
    title <<< data["title"]
    branch <<< data["branch"]
    URI <<< data["uri"]
    
    var createdAtInterval : Int = 0
    createdAtInterval <<< data["dateCreated"]
    createdAt = NSDate(timeIntervalSince1970: NSTimeInterval(createdAtInterval))
    
    var modifiedAtInterval : Int = 0
    modifiedAtInterval <<< data["dateModified"]
    modifiedAt = NSDate(timeIntervalSince1970: NSTimeInterval(modifiedAtInterval))
    
    reviewerPHIDs <<< data["reviewers"]
  }
  
  func MenuBarTitle() -> String {
    var dateFormatter = NSDateFormatter()
    dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
    dateFormatter.dateStyle = NSDateFormatterStyle.ShortStyle
    dateFormatter.doesRelativeDateFormatting = true
    return String(format: "%@: %d (%@)", self.statusName, self.ID, dateFormatter.stringFromDate(self.modifiedAt))
  }
  
  // TODO(artem): conforming to NSCoding should happen some day? not sure if it's necessary
}