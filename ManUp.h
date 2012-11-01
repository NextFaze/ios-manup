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
-(void) manUpConfigUpdateStarting;
-(void) manUpConfigUpdateFailed:(NSError*)error;
-(void) manUpConfigUpdated:(NSDictionary*)newSettings;
@end

@interface ManUp : NSObject <NSURLConnectionDelegate, UIAlertViewDelegate>
{
    ManUp *_instance;
    BOOL _updateInProgress;
    BOOL _callDidLaunchWhenFinished;
    NSMutableData *_data; // used by NSURLConnectionDelegate
    id<ManUpDelegate> _delegate;
    NSURL* _lastServerConfigURL;
    UIViewController *_rootViewController;
    UIViewController *_modalViewController;
    UIView *_bgView;
}

+(void) manUpWithDefaultDictionary:(NSDictionary*)defaultSettingsDict serverConfigURL:(NSURL*)serverConfigURL delegate:(id<ManUpDelegate>)delegate rootViewController:(UIViewController*)rootViewController;
+(void) manUpWithDefaultJSONFile:(NSString*)defaultSettingsPath serverConfigURL:(NSURL*)serverConfigURL delegate:(id<ManUpDelegate>)delegate rootViewController:(UIViewController*)rootViewController;

@property(nonatomic,strong) id<ManUpDelegate> delegate;
@property(nonatomic,strong) NSURL* lastServerConfigURL;
@property(nonatomic,strong) UIViewController* rootViewController;
@property(nonatomic,strong) UIViewController* modalViewController;
@property(nonatomic,strong) UIView* bgView;

@end
