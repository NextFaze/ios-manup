//
//  ManUp.m
//  ManUpDemo
//
//  Created by Jeremy Day on 23/10/12.
//  Copyright (c) 2012 Burleigh Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ManUpDelegate
@optional
- (void)manUpConfigUpdateStarting;
- (void)manUpConfigUpdateFailed:(NSError*)error;
- (void)manUpConfigUpdated:(NSDictionary*)newSettings;
@end

@interface ManUp : NSObject <NSURLConnectionDelegate, UIAlertViewDelegate>
{
    BOOL _updateInProgress;
    NSMutableData *_data; // used by NSURLConnectionDelegate
    NSObject<ManUpDelegate> *_delegate;
    NSURL* _lastServerConfigURL;
    UIView *_bgView;
}

+ (id)manUpWithDefaultDictionary:(NSDictionary *)defaultSettingsDict
                 serverConfigURL:(NSURL *)serverConfigURL
                        delegate:(NSObject<ManUpDelegate> *)delegate;

+ (id)manUpWithDefaultJSONFile:(NSString *)defaultSettingsPath
               serverConfigURL:(NSURL *)serverConfigURL
                      delegate:(NSObject<ManUpDelegate> *)delegate;

+ (id)manUpWithDefaultDictionary:(NSDictionary *)defaultSettingsDict
                 serverConfigURL:(NSURL *)serverConfigURL
                        delegate:(NSObject<ManUpDelegate> *)delegate
   minimumIntervalBetweenUpdates:(NSTimeInterval)minimumIntervalBetweenUpdates;

+ (id)manUpWithDefaultJSONFile:(NSString *)defaultSettingsPath
               serverConfigURL:(NSURL *)serverConfigURL
                      delegate:(NSObject<ManUpDelegate> *)delegate
 minimumIntervalBetweenUpdates:(NSTimeInterval)minimumIntervalBetweenUpdates;

// Man Up Delegate, notifies the delegate on state changes
@property(nonatomic,strong) id<ManUpDelegate> delegate;

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
