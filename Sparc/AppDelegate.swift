//
//  AppDelegate.swift
//  Sparc
//
//  Created by Artem Titoulenko on 3/18/15.
//  Copyright (c) 2015 Artem Titoulenko. All rights reserved.
//

import Cocoa
import Foundation
import Promissum

@NSApplicationMain
class AppDelegate: NSObject, NSUserNotificationCenterDelegate, NSApplicationDelegate {
  
  var userDefaults = NSUserDefaults.standardUserDefaults()

  var API : Phabricator?
  var timer : NSTimer?

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
    if let api = API {
      api.connect()
        .then { _ in
          self.refreshDiffs()
          self.timer = NSTimer.scheduledTimerWithTimeInterval(60, target: self, selector: Selector("refreshDiffs"), userInfo: [:], repeats: true)
        }
    }
  }
  
  func refreshDiffs() {
    if let api = self.API {
      api.getAuthoredDiffs()
        .then { diffs in
          var newTitle = String(format: "Sparc: %d", diffs.count)
          self.statusItem.title = newTitle
          for diff in diffs as [Diff] {
            self.addMenuItemForDiff(diff)
          }
      }
    }
  }
  
  func openDiffURL(sender : AnyObject) {
    if let diffUrl = sender.representedObject as? String {
      NSWorkspace.sharedWorkspace().openURL(NSURL(string: diffUrl)!)
    }
    
    if let diffUrl = sender as? String {
      NSWorkspace.sharedWorkspace().openURL(NSURL(string: diffUrl)!)
    }
  }
  
  func notifyAboutDiff(diff: Diff) {
    var notification:NSUserNotification = NSUserNotification()
    
    let status : Int = diff.status!
    switch status {
    case 0:
      // Status 0 means their diff needs initial review. Don't notify the user about that.
      return;
    case 1:
      notification.title = String(format: "D%d Needs Revision", diff.ID)
      notification.informativeText = "The reviewers requested changes to your Diff"
    case 2:
      notification.title = String(format: "D%d Accepted", diff.ID)
      notification.informativeText = "Your Diff has been accepted! You may land it now."
    default:
      notification.title = String(format: "D%d %@", diff.ID, diff.statusName)
      notification.informativeText = "Something happened to your Diff."
    }

    notification.hasActionButton = true
    notification.actionButtonTitle = "View"
    notification.userInfo = NSDictionary(object: diff.URI.URLString, forKey: "URL")
    notification.deliveryDate = NSDate(timeIntervalSinceNow: 0)
    
    var notificationcenter = NSUserNotificationCenter.defaultUserNotificationCenter()
    notificationcenter.delegate = self
    notificationcenter.scheduleNotification(notification)
  }
  
  func userNotificationCenter(center: NSUserNotificationCenter, didActivateNotification notification: NSUserNotification) {
    if let dict : NSDictionary = notification.userInfo {
      if let diff = dict["URL"] as? String {
        self.openDiffURL(diff)
      }
    }
    center.removeDeliveredNotification(notification)
  }

  func userNotificationCenter(center: NSUserNotificationCenter,
    shouldPresentNotification notification: NSUserNotification) -> Bool {
      return true
  }

  //Add menuItem to menu
  func addMenuItemForDiff(diff : Diff) {
    // Check if the item already exists, update it's title if it does
    if let item = statusMenu.itemWithTag(diff.ID) {
      // If there was a change of status for the diff, notify the user
      if item.title != diff.MenuBarTitle() {
        self.notifyAboutDiff(diff)
      }
      
      item.title = diff.MenuBarTitle()
      return
    }
    
    var menuItem : NSMenuItem = NSMenuItem()
    menuItem.title = diff.MenuBarTitle()
    menuItem.action = Selector("openDiffURL:")
    menuItem.representedObject = diff.URI.URLString
    menuItem.keyEquivalent = ""
    menuItem.tag = diff.ID
    statusMenu.insertItem(menuItem, atIndex:0)
    self.notifyAboutDiff(diff)
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    // Insert code here to tear down your application
    timer?.invalidate()
  }
  
  func setWindowVisible(sender: AnyObject){
    self.settingsWindow.orderFront(self)
  }
  
  func shouldDisplayWindowOnBoot() -> Bool {
    return userDefaults.boolForKey("DisplayWindowOnStartup")
  }
  
  @IBAction func quit(sender: AnyObject?) {
    timer?.invalidate()
    NSApplication.sharedApplication().terminate(self)
  }
}

