//
//  ManUp.m
//  ManUp
//
//  Created by Jeremy Day on 23/10/12.
//  Copyright (c) 2012 Burleigh Labs. All rights reserved.
//

#import "ManUp.h"

NS_ASSUME_NONNULL_BEGIN

/**
 NSUserDefaults keys
 Used to save settings used by ManUp locally to the device
 */
static NSString *const kManUpSettings                   = @"ManUpSettings";
static NSString *const kManUpLastUpdated                = @"ManUpLastUpdated";

typedef NS_ENUM(NSUInteger, ManUpAlertType) {
    ManUpAlertTypeNone,
    ManUpAlertTypeOptionalUpdate,
    ManUpAlertTypeMandatoryUpdate,
    ManUpAlertTypeMaintenanceMode
};

@interface ManUp ()

@property (nonatomic, strong, nullable) UIAlertController *alertController;
@property (nonatomic, assign) ManUpAlertType currentlyShownAlertType;
@property (nonatomic, assign) BOOL optionalUpdateShown;
@property (nonatomic, assign) BOOL updateInProgress;

@end

@implementation ManUp

#pragma mark - Creation

- (instancetype)initWithConfigURL:(nullable NSURL *)url delegate:(nullable NSObject<ManUpDelegate> *)delegate {
    if (self = [self init]) {
        self.configURL = url;
        self.delegate = delegate;
    }
    return self;
}

- (instancetype)init {
	if (self = [super init]) {
		self.updateInProgress = NO;
        self.optionalUpdateShown = NO;
        self.currentlyShownAlertType = ManUpAlertTypeNone;
	}
	return self;
}

#pragma mark - Public

- (void)validate {
    [self updateFromServer];
}

#pragma mark - 

- (NSDictionary *)replaceNullsWithEmptyStringInDictionary:(NSDictionary *)dict {
    NSMutableDictionary *newDict = [[NSMutableDictionary alloc] init];
    for (NSString *key in dict) {
        id value = [dict objectForKey:key];
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

    if ([self.delegate respondsToSelector:@selector(manUpConfigUpdated:)]) {
        [self.delegate manUpConfigUpdated:settings];
    }
}

- (void)setManUpSettingsIfNone:(NSDictionary*)settings {
    NSDictionary *persistedSettings = [self getPersistedSettings];
    if (persistedSettings == nil) {
        [self setManUpSettings:settings];
    }
}

- (void)setLastUpdated:(nullable NSDate *)date {
    [[NSUserDefaults standardUserDefaults] setObject:date forKey:kManUpLastUpdated];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (nullable NSDate *)lastUpdated {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kManUpLastUpdated];
}

- (nullable NSDictionary *)getPersistedSettings {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kManUpSettings];
}

- (BOOL)hasPersistedSettings {
    return [self getPersistedSettings] != nil;
}

- (id)settingForKey:(NSString *)key {
    NSDictionary *settings = [[NSUserDefaults standardUserDefaults] valueForKey:kManUpSettings];
    NSString *resolvedKey = self.customConfigKeyMapping[key] ?: key;
    id object = settings[resolvedKey];
    if (object == nil) {
        // value not found at the root level, also check inside the `ios` object
        NSString *iOSKey = self.customConfigKeyMapping[kManUpConfigiOSContainer] ?: kManUpConfigiOSContainer;
        NSDictionary *iOSSettings = settings[iOSKey];
        object = iOSSettings[resolvedKey];
    }
    return object;
}

- (void)log:(NSString *)string, ... NS_FORMAT_FUNCTION(1,2) {
    if (self.enableConsoleLogging) {
        va_list args;
        va_start(args, string);
        NSLog([[NSString alloc] initWithFormat:string arguments:args], nil);
        va_end(args);
    }
}

#pragma mark -

- (void)updateFromServer {
    if (!self.configURL) {
        [self log:@"ERROR: No server config URL specified."];
        if ([self.delegate respondsToSelector:@selector(manUpConfigUpdateFailed:)]) {
            NSError *error = [NSError errorWithDomain:@"com.nextfaze.ManUp" code:1 userInfo:nil];
            [self.delegate manUpConfigUpdateFailed:error];
        }
        return;
    }
    
    if (self.updateInProgress) {
        [self log:@"ManUp: An update is currently in progress."];
        return;
    }
    
    self.updateInProgress = YES;
    if ([self.delegate respondsToSelector:@selector(manUpConfigUpdateStarting)]) {
        [self.delegate manUpConfigUpdateStarting];
    }
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:self.configURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                self.updateInProgress = NO;
                                                
                                                NSInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];
                                                if (statusCode >= 400) {
                                                    if (!error) {
                                                        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
                                                        NSString *message = [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
                                                        if (message) {
                                                            userInfo[NSLocalizedDescriptionKey] = message;
                                                        }
                                                        error = [NSError errorWithDomain:NSURLErrorDomain code:statusCode userInfo:userInfo];
                                                    }
                                                }
                                                
                                                if (error) {
                                                    if ([self.delegate respondsToSelector:@selector(manUpConfigUpdateFailed:)]) {
                                                        [self.delegate manUpConfigUpdateFailed:error];
                                                    }
                                                    [self runManUpChecks];
                                                    return;
                                                }
                                                
                                                NSError *parsingError;
                                                id jsonObject = [NSJSONSerialization JSONObjectWithData:data
                                                                                                options:kNilOptions
                                                                                                  error:&parsingError];
                                                
                                                if (parsingError) {
                                                    [self log:@"ERROR: %@", parsingError];
                                                    [self log:@"\%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
                                                    if ([self.delegate respondsToSelector:@selector(manUpConfigUpdateFailed:)]) {
                                                        [self.delegate manUpConfigUpdateFailed:error];
                                                    }
                                                    [self runManUpChecks];
                                                    return;
                                                }
                                                
                                                NSDictionary *nonNullSettings = [self replaceNullsWithEmptyStringInDictionary:jsonObject];
                                                [self setManUpSettings:nonNullSettings];
                                                [self runManUpChecks];
                                                return;
                                            }];
    [task resume];
}

#pragma mark -

- (BOOL)shouldShowAlert {
    if ([self.delegate respondsToSelector:@selector(manUpShouldShowAlert)]) {
        return [self.delegate manUpShouldShowAlert];
    }
    return YES;
}

- (void)showAlertOfType:(ManUpAlertType)alertType withTitle:(NSString *)title message:(NSString *)message actions:(NSArray *)actions {
    if ([self shouldShowAlert] == NO) {
        return;
    }
    
    void (^showAlert)(void) = ^void() {
        self.alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        
        for (UIAlertAction *action in actions) {
            [self.alertController addAction:action];
        }
        
        UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topController.presentedViewController) {
            topController = topController.presentedViewController;
        }
        [topController presentViewController:self.alertController animated:YES completion:nil];
        
        self.currentlyShownAlertType = alertType;
    };
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.currentlyShownAlertType == alertType) {
            return;
            
        } else if (self.currentlyShownAlertType == ManUpAlertTypeNone) {
            showAlert();
            
        } else {
            [self dismissAlertWithCompletion:showAlert];
        }
    });
}

- (void)dismissAlertWithCompletion:(void (^ __nullable)(void))completion {
    [self.alertController dismissViewControllerAnimated:YES completion:completion];
    self.alertController = nil;
    self.currentlyShownAlertType = ManUpAlertTypeNone;
}

#pragma mark -

- (void)runManUpChecks {
    NSString *updateURL = [self settingForKey:kManUpConfigAppUpdateURL];
    NSString *currentVersion = [self settingForKey:kManUpConfigAppVersionCurrent];
    NSString *minVersion = [self settingForKey:kManUpConfigAppVersionMin];
    NSString *installedVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSComparisonResult minVersionComparisonResult = [ManUp compareVersion:installedVersion toVersion:minVersion];
    NSComparisonResult currentVersionComparisonResult = [ManUp compareVersion:installedVersion toVersion:currentVersion];
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    BOOL enabled = [self settingForKey:kManUpConfigAppIsEnabled] ? [[self settingForKey:kManUpConfigAppIsEnabled] boolValue] : YES;

    if (![currentVersion isKindOfClass:[NSString class]]) {
        [self log:@"ManUp: Error, expecting string for current app store version"];
        return;
    }
    
    if (![minVersion isKindOfClass:[NSString class]]) {
        [self log:@"ManUp: Error, expecting string for minimum app store version"];
        return;
    }
    
    [self log:@"Current version  : %@", currentVersion];
    [self log:@"Min version      : %@", minVersion];
    [self log:@"Installed version: %@", installedVersion];
    [self log:@"Enabled          : %@", enabled ? @"true" : @"false"];
    
    if (!enabled) {
        [self showAlertOfType:ManUpAlertTypeMaintenanceMode
                    withTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ Unavailable", @"{app name} Unavailable"), appName]
                      message:[NSString stringWithFormat:NSLocalizedString(@"%@ is currently unavailable. Please check back later.", @"{app name} is currently unavailable..."), appName]
                      actions:@[]];
        
        if ([self.delegate respondsToSelector:@selector(manUpMaintenanceMode)]) {
            [self.delegate manUpMaintenanceMode];
        }
        return;
    }
    
    NSString *deploymentTarget = [self settingForKey:kManUpConfigAppDeploymentTarget];
    if (deploymentTarget) {
        NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
        
        NSComparisonResult osVersionComparisonResult = [ManUp compareVersion:systemVersion toVersion:deploymentTarget];
        if (osVersionComparisonResult == NSOrderedAscending) {
            [self log:@"ManUp: Update available, but system version %@ is less than the update deployment target %@", systemVersion, deploymentTarget];
            return;
        }
    }
    
    if (minVersion && minVersionComparisonResult == NSOrderedAscending) {
        [self log:@"ManUp: Mandatory update required."];
        
        if (updateURL.length > 0) {
            [self log:@"ManUp: Blocking access and displaying update alert."];
            
            UIAlertAction *updateAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Update", nil)
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                                     [self openUpdateURL];
                                                                     self.alertController = nil;
                                                                 }];
            
            [self showAlertOfType:ManUpAlertTypeMandatoryUpdate
                        withTitle:NSLocalizedString(@"Update Required", nil)
                          message:NSLocalizedString(@"An update is required. To continue, please update the application.", nil)
                          actions:@[updateAction]];
            
            if ([self.delegate respondsToSelector:@selector(manUpUpdateRequired)]) {
                [self.delegate manUpUpdateRequired];
            }
        }
        
    } else if (currentVersion && currentVersionComparisonResult == NSOrderedAscending && !self.optionalUpdateShown) {
        [self log:@"ManUp: User doesn't have latest version."];
        
        if (updateURL.length > 0) {
            UIAlertAction *updateAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Update", nil)
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                                     [self openUpdateURL];
                                                                     self.alertController = nil;
                                                                 }];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"No Thanks", nil)
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                                     self.alertController = nil;
                                                                 }];
            
            [self showAlertOfType:ManUpAlertTypeOptionalUpdate
                        withTitle:NSLocalizedString(@"Update Available", nil)
                          message:NSLocalizedString(@"An update is available. Would you like to update to the latest version?", nil)
                          actions:@[updateAction, cancelAction]];

            if ([self shouldShowAlert]) {
                self.optionalUpdateShown = YES;
            }
            
            if ([self.delegate respondsToSelector:@selector(manUpUpdateAvailable)]) {
                [self.delegate manUpUpdateAvailable];
            }
        }
        
    } else if (self.currentlyShownAlertType != ManUpAlertTypeNone) {
        [self dismissAlertWithCompletion:nil];
    }
}

- (void)openUpdateURL {
    NSString *updateURLString = [self settingForKey:kManUpConfigAppUpdateURL];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:updateURLString]];
}

/**
 Compare two version strings
 */
+ (NSComparisonResult)compareVersion:(NSString *)firstVersion toVersion:(NSString *)secondVersion {
    if ([firstVersion isEqualToString:secondVersion]) {
        return NSOrderedSame;
    }
    
    NSArray *firstVersionComponents = [firstVersion componentsSeparatedByString:@"."];
    NSArray *secondVersionComponents = [secondVersion componentsSeparatedByString:@"."];
    
    for (NSInteger index = 0; index < MAX([firstVersionComponents count], [secondVersionComponents count]); index++) {
        NSInteger firstComponent = (index < [firstVersionComponents count]) ? [firstVersionComponents[index] integerValue] : 0;
        NSInteger secondComponent = (index < [secondVersionComponents count]) ? [secondVersionComponents[index] integerValue] : 0;
        
        if (firstComponent < secondComponent) {
            return NSOrderedAscending;
            
        } else if (firstComponent > secondComponent) {
            return NSOrderedDescending;
        }
    }
    
    return NSOrderedSame;
}

@end

NS_ASSUME_NONNULL_END
