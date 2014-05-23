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
static NSString *const kManUpAppVersionCurrent      = @"ManUpAppVersionCurrent";
// required: the min version of the application
static NSString *const kManUpAppVersionMin          = @"ManUpAppVersionMin";
// optional: if not present there's no pathway to upgrade but the app is blocked (provided user_version < min)
static NSString *const kManUpAppUpdateLink          = @"ManUpAppUpdateLink";

@protocol ManUpDelegate <NSObject>
@optional
- (void)manUpConfigUpdateStarting;
- (void)manUpConfigUpdateFailed:(NSError*)error;
- (void)manUpConfigUpdated:(NSDictionary*)newSettings;
@end

@interface ManUp : NSObject <NSURLConnectionDelegate, UIAlertViewDelegate>
{
    BOOL _updateInProgress;
    BOOL _callDidLaunchWhenFinished;
    NSMutableData *_data; // used by NSURLConnectionDelegate
    NSURL* _lastServerConfigURL;
    UIView *_bgView;
}

+ (id)manUpWithDefaultDictionary:(NSDictionary *)defaultSettingsDict
                 serverConfigURL:(NSURL *)serverConfigURL
                        delegate:(id<ManUpDelegate>)delegate;

+ (id)manUpWithDefaultJSONFile:(NSString *)defaultSettingsPath
               serverConfigURL:(NSURL *)serverConfigURL
                      delegate:(id<ManUpDelegate>)delegate;

+ (id)manUpWithDefaultDictionary:(NSDictionary *)defaultSettingsDict
                 serverConfigURL:(NSURL *)serverConfigURL
                        delegate:(id<ManUpDelegate>)delegate
   minimumIntervalBetweenUpdates:(NSTimeInterval)minimumIntervalBetweenUpdates;

+ (id)manUpWithDefaultJSONFile:(NSString *)defaultSettingsPath
               serverConfigURL:(NSURL *)serverConfigURL
                      delegate:(id<ManUpDelegate>)delegate
 minimumIntervalBetweenUpdates:(NSTimeInterval)minimumIntervalBetweenUpdates;

// Man Up Delegate, notifies the delegate on state changes
@property(nonatomic,assign) id<ManUpDelegate> delegate;

// URL to server config data
@property(nonatomic,strong) NSURL *lastServerConfigURL;

// The view that covers the app, shown behind the alert view
@property(nonatomic,strong) UIView *coverView;

// Last time configuration was successfully updated from the server
@property(nonatomic,readonly) NSDate *lastUpdated;

// Default minimum interval is 10mins;
@property(nonatomic,assign) NSTimeInterval minimumIntervalBetweenUpdates;

// Fetch a stored settings
+ (id)settingForKey:(NSString *)key;

@end
