# Sparc
Sparc is an OS X menubar application that runs in the background and notifies you when your Phabricator Diffs are ready to be landed, if your reviewers requested changes, or if there are new Diffs that you should review.

## Installation

You can grab a zip of the [latest release](http://github.com/ox/sparc/releases), unzip it, and run it. It's been shown to work on OS X 10.10. It should work for OS X 10.9.

You could also download the XCode project. Install [Cocoapods](http://cocoapods.org/), and then run `$ pod install` in the root directory of the project. Afterwards open the `Sparc.xcworkspace` and Run the default Schema. You should see your open diffs start popping up in the Notifications Center.

If you don't see anything, or an error, make sure that your `~/.arcrc` file is set up and that there is a host, user, and cert present.
