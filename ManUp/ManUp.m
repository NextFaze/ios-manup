//
//  ManUp.m
//  ManUpDemo
//
//  Created by Jeremy Day on 23/10/12.
//  Copyright (c) 2012 Burleigh Labs. All rights reserved.
//

// TODO: convert to semantic versioning of marketing version (not build number) - see https://github.com/eure/AppVersionMonitor

#import "ManUp.h"

@interface ManUp ()

@property (nonatomic, strong) UIAlertController *alertController;

@property (nonatomic, assign) BOOL optionalUpdateShown;

@property (nonatomic, assign) BOOL updateInProgress;

@property (nonatomic, assign) BOOL callDidLaunchWhenFinished; // TODO: what is this for??

@property (nonatomic, strong) NSURL *lastServerConfigURL;

@end

@implementation ManUp

- (void)manUpWithDefaultDictionary:(NSDictionary *)defaultSettingsDict serverConfigURL:(NSURL *)serverConfigURL delegate:(NSObject<ManUpDelegate> *)delegate {
    self.delegate = delegate;
    self.lastServerConfigURL = serverConfigURL;
    
    // Only apply defaults if they do not exist already.
    if(![self hasPersistedSettings]) {
        NSDictionary* nonNullDefaultSettings = [self replaceNullsWithEmptyStringInDictionary:defaultSettingsDict];
        [self setManUpSettings:nonNullDefaultSettings];
    }
    
    [self refreshView];
    [self updateFromServer];
}

- (void)manUpWithDefaultJSONFile:(NSString *)defaultSettingsPath serverConfigURL:(NSURL *)serverConfigURL delegate:(NSObject<ManUpDelegate> *)delegate {
    self.delegate = delegate;
    self.lastServerConfigURL = serverConfigURL;
    
    // Only apply defaults if they do not exist already.
    if (![self hasPersistedSettings]) {
        NSData *jsonData = [NSData dataWithContentsOfFile:defaultSettingsPath];
        if (jsonData == nil) {
            // TODO: handle this error
            return;
        }

        NSError *error = nil;
        NSDictionary *defaultSettings = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        NSDictionary *nonNullDefaultSettings = [self replaceNullsWithEmptyStringInDictionary:defaultSettings];
        [self setManUpSettings:nonNullDefaultSettings];
    }
    
    [self refreshView];
    [self updateFromServer];
}

#pragma mark - Creation

+ (ManUp *)sharedInstance {
    static id sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });

    return sharedInstance;
}

- (id)init {
	if (self = [super init]) {
		self.updateInProgress = NO;
        self.callDidLaunchWhenFinished = NO;
        
        self.optionalUpdateShown = NO;
	}
	return self;
}

#pragma mark - 

- (NSDictionary *)replaceNullsWithEmptyStringInDictionary:(NSDictionary *)dict {
    NSMutableDictionary *newDict = [[NSMutableDictionary alloc] init];
    for (NSString *key in dict) {
        NSString *value = [dict objectForKey:key];
        if (value == nil || [value isKindOfClass:[NSNull class]]) {
            value = @"";
        }
        [newDict setValue:value forKey:key];
    }
    return newDict;
}

- (void)setManUpSettings:(NSDictionary *)settings {
    [[NSUserDefaults standardUserDefaults] setObject:settings forKey:kManUpSettings];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if ([_delegate respondsToSelector:@selector(manUpConfigUpdated:)]) {
        [_delegate manUpConfigUpdated:settings];
    }
}

- (void)setManUpSettingsIfNone:(NSDictionary*)settings {
    NSDictionary *persistedSettings = [self getPersistedSettings];
    if (persistedSettings == nil) {
        [self setManUpSettings:settings];
    }
}

- (void)setLastUpdated:(NSDate *)date {
    [[NSUserDefaults standardUserDefaults] setObject:date forKey:kManUpLastUpdated];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDate *)lastUpdated {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kManUpLastUpdated];
}

- (NSDictionary *)getPersistedSettings {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kManUpSettings];
}

- (BOOL)hasPersistedSettings {
    return [self getPersistedSettings] != nil;
}

- (void)updateFromServer {
    if (self.updateInProgress) {
        NSLog(@"ManUp: An update is currently in progress.");
        return;
    }
    
    self.updateInProgress = YES;
    if ([self.delegate respondsToSelector:@selector(manUpConfigUpdateStarting)]) {
        [self.delegate manUpConfigUpdateStarting];
    }
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:self.lastServerConfigURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                self.updateInProgress = NO;
                                                
                                                if (error) {
                                                    if ([self.delegate respondsToSelector:@selector(manUpConfigUpdateFailed:)]) {
                                                        [self.delegate manUpConfigUpdateFailed:error];
                                                    }
                                                    [self refreshView];
                                                }
                                                
                                                NSError *parsingError;
                                                id jsonObject = [NSJSONSerialization JSONObjectWithData:data
                                                                                                options:kNilOptions
                                                                                                  error:&parsingError];
                                                
                                                if (parsingError) {
                                                    NSLog(@"ERROR: %@", parsingError);
                                                    NSLog(@"\%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                                    if ([self.delegate respondsToSelector:@selector(manUpConfigUpdateFailed:)]) {
                                                        [self.delegate manUpConfigUpdateFailed:error];
                                                    }
                                                    [self refreshView];
                                                }
                                                
                                                NSDictionary *nonNullSettings = [self replaceNullsWithEmptyStringInDictionary:jsonObject];
                                                [self setManUpSettings:nonNullSettings];
                                            }];
    [task resume];
}

#pragma mark -

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message actions:(NSArray *)actions {
    self.alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    for (UIAlertAction *action in actions) {
        [self.alertController addAction:action];
    }
    
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    [topController presentViewController:self.alertController animated:YES completion:nil];
}


/* On Lauch, we look at the most recently retrieved settings and if they are less than 1 hour old, use them
   to check if we need to display update or mandatory update dialogs. */
- (void)refreshView {
    NSDictionary *settings = [self getPersistedSettings];
    NSString *updateURL  = [settings objectForKey:kManUpAppUpdateLink];
    id currentVersion = [settings objectForKey:kManUpAppVersionCurrent];
    id minVersion = [settings objectForKey:kManUpAppVersionMin];
    id userVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    // If number version
    if ([currentVersion isKindOfClass:[NSNumber class]] && [minVersion isKindOfClass:[NSNumber class]]) {
        userVersion = @([[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] integerValue]);
        
    } else {
        // Just in case, they come through as strings, convert to numbers
        if ([currentVersion isKindOfClass:[NSString class]]) currentVersion = @([currentVersion integerValue]);
        if ([minVersion isKindOfClass:[NSString class]]) minVersion = @([minVersion integerValue]);
        if ([userVersion isKindOfClass:[NSString class]]) userVersion = @([userVersion integerValue]);
    }
    
    if (!self.alertController) {
        // Check if mandatory update is required.
        if (minVersion && [userVersion compare:minVersion] < 0) {
            NSLog(@"ManUp: Mandatory update required.");
            
            if (updateURL == nil || [updateURL isEqualToString:@""]) {
                NSLog(@"ManUp: No update URL provided, blocking app access");
                // TODO: what happens here?
                
            } else {
                NSLog(@"ManUp: Blocking access and displaying update alert.");
                
                UIAlertAction *updateAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Update", nil)
                                                                       style:UIAlertActionStyleDefault
                                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                                         [self openUpdateURL];
                                                                     }];
                
                [self showAlertWithTitle:NSLocalizedString(@"Update Required", nil)
                                 message:NSLocalizedString(@"An update is required. To continue, please update the application.", nil)
                                 actions:@[updateAction]];
            }
            
        } else if (currentVersion && [userVersion compare:currentVersion] < 0 && !self.optionalUpdateShown) {
            // Optional update (only show if an 2 hours later, don't want to keep pestering the user)
            NSLog(@"ManUp: User doesn't have latest version.");
            
            if (updateURL != nil && ![updateURL isEqualToString:@""]) {
                UIAlertAction *updateAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Update", nil)
                                                                       style:UIAlertActionStyleDefault
                                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                                         [self openUpdateURL];
                                                                     }];
                
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"No Thanks", nil)
                                                                       style:UIAlertActionStyleCancel
                                                                     handler:nil];
                
                [self showAlertWithTitle:NSLocalizedString(@"Update Available", nil)
                                 message:NSLocalizedString(@"An update is available. Would you like to update to the latest version?", nil)
                                 actions:@[updateAction, cancelAction]];

                self.optionalUpdateShown = YES;
            }
        }
    }
}

- (void)openUpdateURL {
    NSDictionary *settings = [self getPersistedSettings];
    NSString *updateURLString = [settings objectForKey:kManUpAppUpdateLink];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:updateURLString]];
}

+ (id)settingForKey:(NSString *)key {
    return [[[NSUserDefaults standardUserDefaults] valueForKey:kManUpSettings] valueForKey:key];
}

@end
