//
//  ManUp.m
//  ManUpDemo
//
//  Created by Jeremy Day on 23/10/12.
//  Copyright (c) 2012 Burleigh Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

/* User bundle key names */
static NSString *const kManUpMaintenanceMode        = @"ManUpMaintenanceMode";
static NSString *const kManUpMaintenanceModeTitle   = @"ManUpMaintenanceTitle";
static NSString *const kManUpMaintenanceModeMessage = @"ManUpMaintenanceMessage";
static NSString *const kManUpSettings               = @"ManUpSettings";
static NSString *const kManUpServerConfigURL        = @"ManUpServerConfigURL";
static NSString *const kManUpLastUpdated            = @"ManUpLastUpdated";

/* Server side key names */
// required: the current version of the application
static NSString *const kManUpAppVersionCurrent      = @"manUpAppVersionCurrent";
// required: the min version of the application
static NSString *const kManUpAppVersionMin          = @"manUpAppVersionMin";
// optional: if not present there's no pathway to upgrade but the app is blocked (provided user_version < min)
static NSString *const kManUpAppUpdateURL          = @"manUpAppUpdateURL";

@protocol ManUpDelegate <NSObject>
@optional
- (void)manUpConfigUpdateStarting;
- (void)manUpConfigUpdateFailed:(NSError *)error;
- (void)manUpConfigUpdated:(NSDictionary *)newSettings;
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

// URL to server config data
@property (nonatomic, readonly) NSURL *serverConfigURL;

// Last time configuration was successfully updated from the server
@property (nonatomic, readonly) NSDate *lastUpdated;

// Fetch a stored setting
+ (id)settingForKey:(NSString *)key;

// String version comparison
+ (NSComparisonResult)compareVersion:(NSString *)firstVersion toVersion:(NSString *)secondVersion;

@end
