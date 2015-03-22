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
  var statusName : String = ""
  var title : String = ""
  var branch : String = ""
  var URI : NSURL = NSURL()
  
  var createdAt : NSDate = NSDate()
  var modifiedAt : NSDate = NSDate()
  
  var reviewerPHIDs : [String] = []

  required init(data : [String: AnyObject]) {
    ID <<< data["id"]
    statusName <<< data["statusName"]
    title <<< data["title"]
    branch <<< data["branch"]
    URI <<< data["uri"]
    
    createdAt <<< data["dateCreated"]
    modifiedAt <<< data["dateModified"]
    
    reviewerPHIDs <<< data["reviewers"]
  }
  
  func DisplayTitle() -> String {
    return String(format: "%@: %d - %@ (%@), created on %@, modified on: %@",
      self.statusName, self.ID, self.title, self.URI, self.createdAt, self.modifiedAt)
  }
  
  func MenuBarTitle() -> String {
    return String(format: "%@: %d", self.statusName, self.ID)
  }
}