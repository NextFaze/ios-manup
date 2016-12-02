//
//  ManUp.m
//  ManUp
//
//  Created by Jeremy Day on 23/10/12.
//  Copyright (c) 2012 Burleigh Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Default config.json keys
 Use these keys in your applications config json file to be served to ManUp
 
    manUpAppVersionCurrent: the current App Store version, eg 2.0
    manUpAppVersionMin: the minimum required version, which will force a mandatory update, eg 1.1
    manUpAppUpdateURL: the URL to be opened to update the app, eg an App Store URL or a website
    manUpAppDeploymentTarget: the minimum required OS for this update, optional, eg 8.1
 */
static NSString *const kManUpConfigAppVersionCurrent    = @"manUpAppVersionCurrent";
static NSString *const kManUpConfigAppVersionMin        = @"manUpAppVersionMin";
static NSString *const kManUpConfigAppUpdateURL         = @"manUpAppUpdateURL";
static NSString *const kManUpConfigAppDeploymentTarget  = @"manUpAppDeploymentTarget";

@protocol ManUpDelegate <NSObject>

@optional
- (void)manUpConfigUpdateStarting;
- (void)manUpConfigUpdateFailed:(NSError *)error;
- (void)manUpConfigUpdated:(NSDictionary *)newSettings;
- (BOOL)manUpShouldShowAlert;
- (void)manUpUpdateRequired;
- (void)manUpUpdateAvailable;

@end

@interface ManUp : NSObject

+ (ManUp *)sharedInstance;

- (void)manUpWithDefaultDictionary:(NSDictionary *)defaultSettingsDict
                   serverConfigURL:(NSURL *)serverConfigURL
                          delegate:(NSObject<ManUpDelegate> *)delegate;

- (void)manUpWithDefaultJSONFile:(NSString *)defaultSettingsPath
                 serverConfigURL:(NSURL *)serverConfigURL
                        delegate:(NSObject<ManUpDelegate> *)delegate;

@property (nonatomic, weak) NSObject<ManUpDelegate> *delegate;

/**
 Enable console logging
 
 @param enableConsoleLogging set to YES and ManUp will log its output to the console
 */
@property (nonatomic, assign) BOOL enableConsoleLogging;

/**
 @param serverConfigURL URL to the remote config.json file
 */
@property (nonatomic, readonly) NSURL *serverConfigURL;

/**
 @param lastUpdated the date that the configuration was last successfully updated from the server
 */
@property (nonatomic, readonly) NSDate *lastUpdated;

/**
 Specify custom keys to be used instead of the default keys
 
 @param customConfigKeyMapping a dictionary that provides a new key for each default key that should be custom mapped
 */
@property (nonatomic, strong) NSDictionary *customConfigKeyMapping;

/**
 Fetch a stored setting
 
 @param key the key used in the config json file
 */
+ (id)settingForKey:(NSString *)key;

/** 
 String version comparison

 Compare two strings, which represent versions, that are integers separated by dots (.)
 
 @param firstVersion the version to compare
 @param secondVersion the version being compared to
 */
+ (NSComparisonResult)compareVersion:(NSString *)firstVersion toVersion:(NSString *)secondVersion;

@end
