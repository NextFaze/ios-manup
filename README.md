# <img src="https://github.com/NextFaze/ManUp/raw/master/icon.png" width="40"> ManUp

[![Build Status](https://travis-ci.org/NextFaze/ManUp.svg?style=flat)](https://travis-ci.org/NextFaze/ManUp)
[![Version](https://img.shields.io/cocoapods/v/ManUp.svg?style=flat)](http://cocoapods.org/pods/ManUp)
[![License](https://img.shields.io/cocoapods/l/ManUp.svg?style=flat)](http://cocoapods.org/pods/ManUp)
[![Platform](https://img.shields.io/cocoapods/p/ManUp.svg?style=flat)](http://cocoapods.org/pods/ManUp)

Adds a server side check for a mandatory app update and server-side configuration options to your iOS/tvOS application.

## Installation

The preferred method is via CocoaPods:

    pod 'ManUp'


## Usage

ManUp will download a ManUp configuration file (json) that is hosted on a server of your choice. This file will have the current app store version, the minimum version, and a URL to the app store or app website.

    {
        "ios": {
            "url": "https://itunes.apple.com/app/id0000000?mt=8",
            "latest": "2.0",
            "minimum": "1.1",
            "enabled": true
        }
    }

Running ManUp will download this file and compare it to the installed app's version to determine if there is an update available (`latest`), or if there is a mandatory update required (`minimum`).

#### Swift

	@import ManUp
	
    // keep a strong reference
    let manUp = ManUp()
    
    // typically in applicationDidBecomeActive
    self.manUp.configURL = URL(string: "https://clientfiles.nextfaze.com/eva/maintenanceMode.json")
    self.manUp.delegate = nil
    self.manUp.validate()


#### Objective-C

    #import <ManUp/ManUp.h>
    
    // keep a strong reference
    @property (nonatomic, strong) ManUp *manUp;

    self.manUp = [[ManUp alloc] initWithConfigURL:[NSURL URLWithString:@"https://yourserver.com/config.json"] delegate:self];
    [self.manUp validate];

	
You can also add any keys and values to the json file, which will be accessible like so:

    id value = [ManUp settingForKey:"key"];

This can be used however you see fit, for example to enable/disable app features.
