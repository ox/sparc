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
  
  required init(data : [String: AnyObject]) {
    ID <<< data["id"]
    statusName <<< data["statusName"]
    title <<< data["title"]
  }
  
  func DisplayTitle() -> String {
    let displayTitle = String(format: "%@: %d - %@", self.statusName, self.ID, self.title)
    return displayTitle
  }
}