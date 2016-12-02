# <img src="https://github.com/NextFaze/ManUp/raw/master/icon.png" width="40"> ManUp

[![Build Status](https://travis-ci.org/NextFaze/ManUp.svg?style=flat)](https://travis-ci.org/NextFaze/ManUp)
[![Version](https://img.shields.io/cocoapods/v/ManUp.svg?style=flat)](http://cocoapods.org/pods/ManUp)
[![License](https://img.shields.io/cocoapods/l/ManUp.svg?style=flat)](http://cocoapods.org/pods/ManUp)
[![Platform](https://img.shields.io/cocoapods/p/ManUp.svg?style=flat)](http://cocoapods.org/pods/ManUp)

Adds a server side check for a mandatory app update and server-side configuration options to your iOS/tvOS application.

## Installation

### Via CocoaPods

    pod 'ManUp'

### Manually

Copy the folder `ManUp` into your project.

## Usage

ManUp will download a ManUp configuration file (json) that is hosted on a server of your choice. This file will have the current app store version, the minimum version, and a URL to the app store or app website.

    { 
        "manUpAppUpdateLink": "https://itunes.apple.com/app/id0000000?mt=8",
        "manUpAppVersionCurrent": "2.0",
        "manUpAppVersionMin": "1.1"
    }

Running ManUp will download this file and compare it to the installed app's version to determine if there is an update available (`manUpAppVersionCurrent`), or if there is a mandatory update required (`manUpAppVersionMin`).
	
	[[ManUp sharedInstance] manUpWithDefaultJSONFile:[[NSBundle mainBundle] pathForResource:@"config_manup" ofType:@"json"]
                                     serverConfigURL:[NSURL URLWithString:@"https://yourserver.com/config.json"]
                                            delegate:self];
	
You can also add any keys and values to the json file, which will be accessible like so:

    id value = [ManUp settingForKey:"key"];

This can be used however you see fit, for example to enable/disable app features.
