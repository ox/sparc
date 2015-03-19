//
//  AppDelegate.swift
//  Sparc
//
//  Created by Artem Titoulenko on 3/18/15.
//  Copyright (c) 2015 Artem Titoulenko. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    
    var statusBar = NSStatusBar.systemStatusBar()
    @IBOutlet weak var statusBarItem: NSMenu!
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        var userDefaults = NSUserDefaults.standardUserDefaults()
        let defaultsToRegister = ["DisplayWindowOnStartup": true]
        userDefaults.registerDefaults(defaultsToRegister)
        userDefaults.synchronize()
        

        //Add statusBarIt em
        statusBarItem = statusBar.statusItemWithLength(-1)
        statusBarItem.menu = menu
        statusBarItem.title = "Presses"
        
        //Add menuItem to menu
        menuItem.title = "Clicked"
        menuItem.action = Selector("setWindowVisible:")
        menuItem.keyEquivalent = ""
        menu.addItem(menuItem)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func setWindowVisible(sender: AnyObject){
        self.window!.orderFront(self)
    }
    
    @IBAction func quit(sender: AnyObject?) {
        self.quit(true)
    }
}

