# Sparc
Sparc is an OS X menubar application that tells you when your Phabricator Diffs are ready to be landed, or others need to be looked at.

*NOTE(artem): Still in development*

## Installation/Building

Download the XCode project. Install [Cocoapods](http://cocoapods.org/), and then run `$ pod install` in the root directory of the project. Afterwards open the `Sparc.xcworkspace` and Run the default Schema. You should see your open diffs show up in the console.

If you don't see anything, or an error, make sure that your `~/.arcrc` file is set up and that there is a host, user, and cert present.
