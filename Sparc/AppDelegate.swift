//
//  AppDelegate.swift
//  Sparc
//
//  Created by Artem Titoulenko on 3/18/15.
//  Copyright (c) 2015 Artem Titoulenko. All rights reserved.
//

import Cocoa
import Foundation

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

