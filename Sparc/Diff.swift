//
//  Diff.swift
//  Sparc
//
//  Created by Artem Titoulenko on 3/21/15.
//  Copyright (c) 2015 Artem Titoulenko. All rights reserved.
//

import Foundation
import JSONHelper

enum DiffStatus : Int {
  case NeedsReview = 0,
      NeedsRevision,
      Accepted,
      Closed,
      Abandoned
}

class Diff : Deserializable {
  var ID : Int = 0
  
  // The Status of a Diff can be one of several numbers:
  //
  //    0 - Needs Review
  //    1 - Needs Revision
  //    2 - Accepted
  //    3 - Closed
  //    4 - Abandoned
  var status : DiffStatus?
  var statusName : String = ""
  
  var title : String = ""
  var branch : String = ""
  var URI : NSURL = NSURL()
  
  var createdAt : NSDate = NSDate()
  var modifiedAt : NSDate = NSDate()
  
  var authorPHID : String = ""
  var reviewerPHIDs : [String] = []

  convenience required init(data : [String: AnyObject]) {
    self.init()
    ID <<< data["id"]
    
    var statusInt : Int?
    statusInt <<< data["status"]
    if let statusInt = statusInt {
      self.status = DiffStatus(rawValue: statusInt)
    }
    
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
    
    authorPHID <<< data["authorPHID"]
    reviewerPHIDs <<< data["reviewers"]
  }
  
  func MenuBarTitle() -> String {
    var dateFormatter = NSDateFormatter()
    dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
    dateFormatter.dateStyle = NSDateFormatterStyle.ShortStyle
    dateFormatter.doesRelativeDateFormatting = true
    return String(format: "%@: D%d (%@)", self.statusName, self.ID, dateFormatter.stringFromDate(self.modifiedAt))
  }
  
  // TODO(artem): conforming to NSCoding should happen some day? not sure if it's necessary
}