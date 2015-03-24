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
  var notifyClosedDiffFromReviewees = false
  @IBAction func toggleClosedDiffNotification(sender: NSButton) {
    notifyClosedDiffFromReviewees = !notifyClosedDiffFromReviewees
    userDefaults.setBool(notifyClosedDiffFromReviewees, forKey:"NotifyClosedDiffFromReviewees")
    userDefaults.synchronize()
  }
  
  // NSMenu
  var statusBar = NSStatusBar.systemStatusBar()
  var statusMenu: NSMenu = NSMenu()
  var statusItem : NSStatusItem = NSStatusItem()
  
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    let defaultsToRegister = ["PhabricatorUrl": "", "NotifyClosedDiffFromReviewees": false]
    userDefaults.registerDefaults(defaultsToRegister)
    userDefaults.synchronize()
    
    // Variable length StatusItem
    statusItem = statusBar.statusItemWithLength(-1)

    // Change size of menubar icon to be no bigger than the statusbar
    // TODO: Figure out how to get OSX to do this for me
    var menubarIcon = NSImage(named: "Menubar Icon")
    let thickness = NSStatusBar.systemStatusBar().thickness
    menubarIcon?.size = NSSize(width: thickness, height: thickness)
    statusItem.image = menubarIcon
    // Bug in OSX? Title text appears cut-off on initial load.
    statusItem.title = " ";
    statusItem.menu = statusMenu

    
    API = Phabricator(arcRCFilePath: "~/.arcrc".stringByExpandingTildeInPath)
    if let api = API {
      api.connect()
        .then { _ in
          self.refreshDiffs()
          self.timer = NSTimer.scheduledTimerWithTimeInterval(20, target: self, selector: Selector("refreshDiffs"), userInfo: [:], repeats: true)
        }.catch { error in
          NSLog("error connecting to Phabricator: %@", error as NSError!)
        }
    }
  }
  
  func refreshDiffs() {
    if let api = self.API {      
      whenBoth(api.getAuthoredDiffs(), api.getDiffsToReview())
        .then { authored, toReview in
          if let authored = authored as? [Diff] {
            if let toReview = toReview as? [Diff] {
              
              let totalDiffsToView = authored.count + toReview.count
              if totalDiffsToView > 0 {
                var newTitle = String(format: "%d", totalDiffsToView)
                self.statusItem.title = newTitle
              } else {
                self.statusItem.title = ""
              }
              
              let items = self.statusMenu.itemArray as Array<NSMenuItem>

              // Rebuild the menu, from the bottom up as adding NSMenuItems inserts at index 0.
              self.statusMenu.removeAllItems()
              
              for (index, diff) in enumerate(authored) {
                self.addMenuItemForDiff(diff,
                  keyEquivalent: String(format: "%d", (toReview.count + authored.count) - index))
                self.notifyAboutDiffIfNew(diff, items: items)
              }
              
              if authored.count > 0 {
                self.statusMenu.addItem(NSMenuItem.separatorItem())
              }
              
              for (index, diff) in enumerate(toReview) {
                self.addMenuItemForDiff(diff,
                  keyEquivalent: String(format: "%d", toReview.count - index))
                self.notifyAboutDiffIfNew(diff, items: items)
              }
              
              if toReview.count > 0 {
                self.statusMenu.addItem(NSMenuItem.separatorItem())
              }
              
              self.statusMenu.addItem(NSMenuItem(title: "Differential", action: Selector("openDifferentialHostURL:"), keyEquivalent: ""))
              self.statusMenu.addItem(NSMenuItem(title: "Settings", action: Selector("openSettings:"), keyEquivalent: ""))
              self.statusMenu.addItem(NSMenuItem(title: "Quit", action: Selector("quit:"), keyEquivalent: "q" ))
            }
          }
        }.catch { error in
          NSLog("error fetching authored and diffs to review: %@", error as NSError!)
        }
    }
  }
  
  //Add menuItem to menu
  func addMenuItemForDiff(diff : Diff, keyEquivalent: String) {
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
    menuItem.keyEquivalent = keyEquivalent
    menuItem.tag = diff.ID
    statusMenu.insertItem(menuItem, atIndex:0)
  }
  
  // MARK: Opening Things
  
  func openDiffURL(sender : AnyObject) {
    if let diffUrl = sender.representedObject as? String {
      NSWorkspace.sharedWorkspace().openURL(NSURL(string: diffUrl)!)
    }
    
    if let diffUrl = sender as? String {
      NSWorkspace.sharedWorkspace().openURL(NSURL(string: diffUrl)!)
    }
  }
  
  func openSettings(sender: AnyObject) {
    settingsWindow.makeKeyAndOrderFront(sender)
    NSApp.activateIgnoringOtherApps(true)
  }
  
  func openDifferentialHostURL(sender: AnyObject) {
    if let hostURL = self.API?.host {
      let differential = hostURL.URLByDeletingLastPathComponent!.URLByAppendingPathComponent("/differential")
      NSWorkspace.sharedWorkspace().openURL(differential)
    }
  }

  // MARK: Notifications
  
  func notifyAboutDiffIfNew(diff : Diff, items : Array<NSMenuItem>) {
    let existed = items.filter { return $0.title == diff.MenuBarTitle() }
    if existed.count == 0 {
      self.notifyAboutDiff(diff)
    }
  }
  
  func notifyAboutDiff(diff: Diff) {
    var notification:NSUserNotification = NSUserNotification()
    
    if let status : DiffStatus = diff.status {
      switch status {
      case .Closed:
        // Don't notify the user that a diff has closed
        return
      case .NeedsReview where diff.authorPHID == self.API?.userPHID:
        // Don't notify the user that they submitted a diff.
        return
      case .NeedsReview:
        notification.title = String(format: "D%d Needs Review", diff.ID)
        notification.informativeText = "You have been requested to review a Diff"
      case .NeedsRevision where diff.authorPHID == self.API?.userPHID:
        notification.title = String(format: "D%d Needs Revision", diff.ID)
        notification.informativeText = "The reviewers requested changes to your Diff"
      case .Accepted where diff.authorPHID == self.API?.userPHID:
        notification.title = String(format: "D%d Accepted", diff.ID)
        notification.informativeText = "Your Diff has been accepted! You may land it now"
      case .Accepted:
        // Notify the user that another reviewer has accepted this diff
        notification.title = String(format: "D%d Was Accepted By Another Reviewer", diff.ID)
        notification.informativeText = "A Diff you were meant to review was accepted by another reviewer"
      case .Abandoned where diff.authorPHID != self.API?.userPHID:
        notification.title = String(format: "D%d Was Abandoned", diff.ID)
        notification.informativeText = "The Diff was abandoned by the author"
      default:
        notification.title = String(format: "D%d %@", diff.ID, diff.statusName)
        notification.informativeText = "A Diff changed it's status"
      }
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

  // MARK: NSApplication - Other
  
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

