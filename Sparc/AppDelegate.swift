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
    
    var userDefaults = NSUserDefaults.standardUserDefaults()
    
    var requestURL : NSURL?
    
    // Settings window
    @IBOutlet weak var settingsWindow: NSWindow!
    @IBOutlet var phabricatorUrlField: NSTextField!
    @IBAction func connectToPhabricator(sender: NSButton) {
        requestURL = NSURL(string: self.phabricatorUrlField.stringValue)!
        userDefaults.setValue(self.phabricatorUrlField.stringValue, forKey: "PhabricatorUrl")
        userDefaults.setValue(self.phabricatorCertificate.stringValue, forKey: "PhabricatorCertificate")
        userDefaults.synchronize()
        
        // TODO -- Create a phabricator connection manager, and just do connection.test(NSURL)?
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(requestURL!) {(data, response, error) in
            println(NSString(data: data, encoding: NSUTF8StringEncoding))

            if let output = (NSString(data: data, encoding: NSUTF8StringEncoding)) {
                var parseError: NSError?
                let parsedObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parseError)
                
                NSLog("%s", parsedObject!.stringValue!)
            }
        }
        
        task.resume()
    }
    
    @IBOutlet var phabricatorCertificate: NSTextField!
    @IBAction func fetchCertificatePressed(sender: AnyObject) {
        let certUrl = requestURL?.URLByAppendingPathComponent("/settings/panel/conduit/")
        NSWorkspace.sharedWorkspace().openURL(certUrl!)
    }
    
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
        
        requestURL = NSURL(string: userDefaults.stringForKey("PhabricatorUrl")!)!
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

