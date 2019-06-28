//
//  ManUp.m
//  ManUp
//
//  Created by Jeremy Day on 23/10/12.
//  Copyright (c) 2012 Burleigh Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Default config.json keys
 Use these keys in your applications config json file to be served to ManUp
 
    latest: the current App Store version, eg 2.0
    minimum: the minimum required version, which will force a mandatory update, eg 1.1
    url: the URL to be opened to update the app, eg an App Store URL or a website
    target: the minimum required OS for this update, optional, eg 8.1
 */
static NSString *const kManUpConfigiOSContainer             = @"ios";
static NSString *const kManUpConfigAppVersionCurrent        = @"latest";
static NSString *const kManUpConfigAppVersionMin            = @"minimum";
static NSString *const kManUpConfigAppUpdateURL             = @"url";
static NSString *const kManUpConfigAppDeploymentTarget      = @"target";
static NSString *const kManUpConfigAppIsEnabled             = @"enabled";
static NSString *const kManUpConfigAppIsEnabledForVersions  = @"enabledForVersions";

@protocol ManUpDelegate <NSObject>

@optional
- (void)manUpConfigUpdateStarting;
- (void)manUpConfigUpdateFailed:(NSError *)error;
- (void)manUpConfigUpdated:(NSDictionary *)newSettings;
- (BOOL)manUpShouldShowAlert;
- (void)manUpUpdateRequired;
- (void)manUpUpdateAvailable;
- (void)manUpMaintenanceMode;

@end

@interface ManUp : NSObject

- (instancetype)initWithConfigURL:(nullable NSURL *)url delegate:(nullable NSObject<ManUpDelegate> *)delegate;

/**
 Run the ManUp validation, if it's already running it will not start another check.
 */
- (void)validate;

/**
 A delegate to receive callbacks during the lifecycle of a validation.
 */
@property (nonatomic, weak, nullable) NSObject<ManUpDelegate> *delegate;

/**
 If set to YES, log the output to the console.
 */
@property (nonatomic, assign) BOOL enableConsoleLogging;

/**
 The URL pointing to the remote config.json file.
 */
@property (nonatomic, strong, nullable) NSURL *configURL;

/**
 The date that the configuration was last successfully updated from the server.
 */
@property (nonatomic, readonly, nullable) NSDate *lastUpdated;

/**
 Maps the default configuration keys to custom ones.
 */
@property (nonatomic, strong, nullable) NSDictionary *customConfigKeyMapping;

/**
 Fetch a stored setting
 
 @param key the key used in the config json file
 */
- (id)settingForKey:(NSString *)key;

/** 
 String version comparison

 Compare two strings, which represent versions, that are integers separated by dots (.)
 
 @param firstVersion the version to compare
 @param secondVersion the version being compared to
 */
+ (NSComparisonResult)compareVersion:(NSString *)firstVersion toVersion:(NSString *)secondVersion;

@end

NS_ASSUME_NONNULL_END
