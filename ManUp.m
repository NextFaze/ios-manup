//
//  ManUp.m
//  ManUpDemo
//
//  Created by Jeremy Day on 23/10/12.
//  Copyright (c) 2012 Burleigh Labs. All rights reserved.
//

#import "ManUp.h"

/* Image locations */

// Load up an image with this name (and @2x / -568h@2x) and they will
// display when a mandatory update is required.
static NSString *const ManUpUpdateRequiredBgImgName = @"manup-required";
static NSString *const ManUpMaintenanceBgImgName = @"manup-maintenance";



# pragma mark -
# pragma mark UIImage helper
@interface UIImage (ManUp)

+ (UIImage *)imageConsidering586hNamed:(NSString *)imageName;

@end

@implementation UIImage (ManUp)

+ (UIImage *)imageConsidering586hNamed:(NSString *)imageName
{
    //NSLog(@"Loading image named => %@", imageName);
    NSMutableString *imageNameMutable = [imageName mutableCopy];
    NSRange retinaAtSymbol = [imageName rangeOfString:@"@"];
    if (retinaAtSymbol.location != NSNotFound) {
        [imageNameMutable insertString:@"-568h" atIndex:retinaAtSymbol.location];
    } else {
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        if ([UIScreen mainScreen].scale == 2.f && screenHeight == 568.0f) {
            NSRange dot = [imageName rangeOfString:@"."];
            if (dot.location != NSNotFound) {
                [imageNameMutable insertString:@"-568h@2x" atIndex:dot.location];
            } else {
                [imageNameMutable appendString:@"-568h@2x"];
            }
        }
    }
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:imageNameMutable ofType:@"png"];
    if (imagePath) {
        return [UIImage imageNamed:imageNameMutable];
    } else {
        return [UIImage imageNamed:imageName];
    }
    return nil;
}

@end

@interface ManUp ()
@property (nonatomic,strong) UIAlertController *alertView;
//@property (nonatomic,strong) NSDate *optionalUpdateShown;
@property (nonatomic,assign) BOOL optionalUpdateShown;

// private methods
+ (ManUp*)instance;

@end

@implementation ManUp

+ (id)manUpWithDefaultDictionary:(NSDictionary *)defaultSettingsDict
                 serverConfigURL:(NSURL *)serverConfigURL
                        delegate:(id<ManUpDelegate>)delegate
{
    return [ManUp manUpWithDefaultDictionary:defaultSettingsDict
                             serverConfigURL:serverConfigURL
                                    delegate:delegate
               minimumIntervalBetweenUpdates:10*60];
}


+ (id)manUpWithDefaultJSONFile:(NSString *)defaultSettingsPath
               serverConfigURL:(NSURL *)serverConfigURL
                      delegate:(id<ManUpDelegate>)delegate
{
    return [ManUp manUpWithDefaultJSONFile:defaultSettingsPath
                           serverConfigURL:serverConfigURL
                                  delegate:delegate
             minimumIntervalBetweenUpdates:10*60];
}


+ (id)manUpWithDefaultDictionary:(NSDictionary *)defaultSettingsDict
                 serverConfigURL:(NSURL *)serverConfigURL
                        delegate:(id<ManUpDelegate>)delegate
   minimumIntervalBetweenUpdates:(NSTimeInterval)minimumIntervalBetweenUpdates
{
    ManUp *instance = [ManUp instance];
    instance.delegate = delegate;
    instance.lastServerConfigURL = serverConfigURL;
    instance.minimumIntervalBetweenUpdates = minimumIntervalBetweenUpdates;
    
    // Only apply defaults if they do not exist already.
    if(![instance hasPersistedSettings]) {
        NSDictionary* nonNullDefaultSettings = [instance replaceNullsWithEmptyStringInDictionary:defaultSettingsDict];
        [instance setManUpSettings:nonNullDefaultSettings];
    }
    
    [instance refreshView];
    [instance updateFromServer];
    return instance;
}


+ (id)manUpWithDefaultJSONFile:(NSString *)defaultSettingsPath
               serverConfigURL:(NSURL *)serverConfigURL
                      delegate:(id<ManUpDelegate>)delegate
 minimumIntervalBetweenUpdates:(NSTimeInterval)minimumIntervalBetweenUpdates
{
    ManUp *instance = [ManUp instance];
    instance.delegate = delegate;
    instance.lastServerConfigURL = serverConfigURL;
    instance.minimumIntervalBetweenUpdates = minimumIntervalBetweenUpdates;
    
    // Only apply defaults if they do not exist already.
    if (![instance hasPersistedSettings]) {
        NSData* jsonData = [NSData dataWithContentsOfFile:defaultSettingsPath];
        if(jsonData == nil) {
            // handle this error
            return instance;
        }
        
        // If JSONKit detects a null value it returns NSNull which cannot be saved
        // in NSUserDefaults. For that reason we get copy and replace all occurrences of
        // NSNull with the empty string.
        NSError *error = nil;
        NSDictionary* defaultSettings = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        NSDictionary* nonNullDefaultSettings = [instance replaceNullsWithEmptyStringInDictionary:defaultSettings];
        [instance setManUpSettings:nonNullDefaultSettings];
    }
    
    [instance refreshView];
    [instance updateFromServer];
    return instance;
}

#pragma mark -
#pragma mark Instance and unexposed methods

+ (ManUp*)instance
{
    static ManUp *_instance = nil;
    if (_instance == nil) {
        _instance = [[ManUp alloc] init];
        _instance.minimumIntervalBetweenUpdates = 10*60; /*10mins*/
    }
    return _instance;
}

- (id)init
{
	if (self = [super init]) {
		_updateInProgress = NO;
        _callDidLaunchWhenFinished = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateFromServer)
                                                     name:UIApplicationDidBecomeActiveNotification object:nil];
        self.optionalUpdateShown = NO;
	}
	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSDictionary*)replaceNullsWithEmptyStringInDictionary:(NSDictionary*)dict
{
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

- (void)setManUpSettings:(NSDictionary*)settings
{
    [[NSUserDefaults standardUserDefaults] setObject:settings forKey:kManUpSettings];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if ([_delegate respondsToSelector:@selector(manUpConfigUpdated:)]) {
        [_delegate manUpConfigUpdated:settings];
    }
}

- (void)setManUpSettingsIfNone:(NSDictionary*)settings
{
    NSDictionary *persistedSettings = [self getPersistedSettings];
    if (persistedSettings == nil) {
        [self setManUpSettings:settings];
    }
}

- (void)setLastUpdated:(NSDate *)date
{
    [[NSUserDefaults standardUserDefaults] setObject:date forKey:kManUpLastUpdated];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDate *)lastUpdated
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kManUpLastUpdated];
}

- (NSDictionary *)getPersistedSettings
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kManUpSettings];
}

- (BOOL)hasPersistedSettings
{
    return [self getPersistedSettings] != nil;
}

- (void)updateFromServer
{
    if (_updateInProgress) {
        NSLog(@"ManUp: An update is currently in progress.");
        return;
    }
    
    if (self.lastUpdated != nil && (-[self.lastUpdated timeIntervalSinceNow])<self.minimumIntervalBetweenUpdates) {
        NSLog(@"ManUp: Will not update. An update occurred recently.");
        NSLog(@"time interval since now: %f", (-[self.lastUpdated timeIntervalSinceNow]));
        
        if ([_delegate respondsToSelector:@selector(manUpConfigUpdated:)]) {
            [_delegate manUpConfigUpdated:[self getPersistedSettings]];
        }
        
        return;
    }
    
    _updateInProgress = YES;
    if ([_delegate respondsToSelector:@selector(manUpConfigUpdateStarting)]) {
        [_delegate manUpConfigUpdateStarting];
    }
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:_lastServerConfigURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [connection start];
}

- (void)showBackgroundView:(NSString *)imageNamed
{
    UIImage *backgroundImage = [UIImage imageConsidering586hNamed:imageNamed];
    
    // Check for Default first if not provided.
    if (backgroundImage == nil) {
        NSLog(@"ManUp: Did not include image named %@", ManUpUpdateRequiredBgImgName);
        backgroundImage = [UIImage imageConsidering586hNamed:@"Default"];
    }
    
    // Failing that, look at the plist.
    if (backgroundImage == nil) {
        NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
        NSString *launchImgName = [infoDict objectForKey:@"UILaunchImageFile"];
        if(launchImgName == nil) {
            if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
                launchImgName = [infoDict objectForKey:@"UILaunchImageFile~ipad"];
            }
        }
        if(launchImgName != nil) {
            backgroundImage = [UIImage imageConsidering586hNamed:launchImgName];
        }
    }
        
    // Create cover view if not already existing
    if (!self.coverView) {
        self.coverView  = [[UIImageView alloc] init];
        self.coverView.backgroundColor = [UIColor blackColor];
        self.coverView.userInteractionEnabled = YES;
    }
    
    // Just in case some one decided to inject their own view
    if ([self.coverView isKindOfClass:[UIImageView class]]) {
        [((UIImageView *) self.coverView) setImage:backgroundImage];
        
    }
    
    UIView *window = [[UIApplication sharedApplication].windows lastObject];
    self.coverView.contentMode = UIViewContentModeScaleAspectFill;
    self.coverView.frame = window.bounds;
    [window addSubview:self.coverView];

}

- (void)clearedAlert:(BOOL)updateOK
{
    if (updateOK) {
        
        [self.coverView removeFromSuperview];
        
        if ([self.delegate respondsToSelector:@selector(manUpAlertCleared)]) {
            [self.delegate manUpAlertCleared];
        }
    }
    
    self.alertView = nil;
}

- (void)showAlertViewWithTitle:(NSString*)title message:(NSString*)message cancelTitle:(NSString*)cancelTitle otherTitle:(NSString*)otherTitle
{
    
    self.alertView = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    NSString* defaultTitle = [cancelTitle length] > 0 ? cancelTitle : @"OK";
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:defaultTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        // Update
        NSDictionary *settings = [self getPersistedSettings];
        NSString *updateURLString = [settings objectForKey:kManUpAppUpdateLink];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:updateURLString]];
        
        // Alert closes and BG goes away: case of optional update.
        [self clearedAlert:![title isEqualToString:@"Update Required"]];
    }];
    
    [self.alertView addAction:defaultAction];
    
    if ([otherTitle length] > 0) {
        UIAlertAction *otherAction = [UIAlertAction actionWithTitle:otherTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
            [self clearedAlert:YES];
        }];
        
        [self.alertView addAction:otherAction];
    }
    
    // Get top view controller
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    [topController presentViewController:self.alertView animated:YES completion:nil];
}

/* On Lauch, we look at the most recently retrieved settings and if they are less than 1 hour old, use them
   to check if we need to display update or mandatory update dialogs. */
- (void)refreshView
{
    @try {
        NSDictionary *settings = [self getPersistedSettings];
        NSString *updateURL      = [settings objectForKey:kManUpAppUpdateLink];
        id currentVersion = [settings objectForKey:kManUpAppVersionCurrent];
        id minVersion     = [settings objectForKey:kManUpAppVersionMin];
        BOOL maintenanceMode     = [[settings objectForKey:kManUpMaintenanceMode] boolValue];
        id userVersion    = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        
        // If number version
        if ([currentVersion isKindOfClass:[NSNumber class]] && [minVersion isKindOfClass:[NSNumber class]]) {
            userVersion = @([[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] integerValue]);
            
        } else {
            // Just in case, they come through as strings, convert to numbers
            if ([currentVersion isKindOfClass:[NSString class]]) currentVersion = @([currentVersion integerValue]);
            if ([minVersion isKindOfClass:[NSString class]]) minVersion = @([minVersion integerValue]);
            if ([userVersion isKindOfClass:[NSString class]]) userVersion = @([userVersion integerValue]);
            
        }
        
        // Hide any existing, refresh
        [self.coverView removeFromSuperview];
        
        if (!self.alertView) {
            // Check if mandatory update is required.
            if(minVersion && [userVersion compare:minVersion] < 0) {
                NSLog(@"ManUp: Mandatory update required.");
                
                if(updateURL == nil || [updateURL isEqualToString:@""]) {
                    NSLog(@"ManUp: No update URL provided, blocking app access");
                    [self showBackgroundView:ManUpUpdateRequiredBgImgName];
                } else {
                    NSLog(@"ManUp: Blocking access and displaying update alert.");
                    [self showBackgroundView:ManUpUpdateRequiredBgImgName];
                    
                    [self showAlertViewWithTitle:NSLocalizedString(@"Update Required", nil)
                                         message:NSLocalizedString(@"An update is required. To continue, please update the application.", nil)
                                     cancelTitle:NSLocalizedString(@"Update", nil)
                                      otherTitle:nil];
                }
            }
            // Maintenance Mode
            else if(maintenanceMode) {
                NSLog(@"ManUp: Maintenance Mode.");
                if(updateURL != nil && ![updateURL isEqualToString:@""]) {
                    [self showBackgroundView:ManUpMaintenanceBgImgName];
                    
                    NSString *maintenanceTitle = NSLocalizedString(@"Down for Maintenance", nil);
                    NSString *maintenanceMessage = NSLocalizedString(@"Please check back again later.", nil);
                    
                    if ([settings valueForKey:kManUpMaintenanceModeTitle]) {
                        maintenanceTitle = [settings valueForKey:kManUpMaintenanceModeTitle];
                    }
                    if ([settings valueForKey:kManUpMaintenanceModeMessage]) {
                        maintenanceMessage = [settings valueForKey:kManUpMaintenanceModeMessage];
                    }
                    
                    [self showAlertViewWithTitle:maintenanceTitle
                                         message:maintenanceMessage
                                     cancelTitle:nil
                                      otherTitle:nil];
                }
            }
            // Optional update (only show if an 2 hours later, don't want to keep pestering the user)
            else if(currentVersion && [userVersion compare:currentVersion] < 0 && !self.optionalUpdateShown) {
                NSLog(@"ManUp: User doesn't have latest version.");
                if(updateURL != nil && ![updateURL isEqualToString:@""]) {
                    
                    [self showAlertViewWithTitle:NSLocalizedString(@"Update Available", nil)
                                         message:NSLocalizedString(@"An update is available. Would you like to update to the latest version?", nil)
                                     cancelTitle:NSLocalizedString(@"Update", nil)
                                      otherTitle:NSLocalizedString(@"No Thanks", nil)];
                    
                    self.optionalUpdateShown = YES;
                }
            }
        }
    }
    @catch (NSException *exception) {
        
    }
}

+ (id)settingForKey:(NSString *)key
{
    return [[[NSUserDefaults standardUserDefaults] valueForKey:kManUpSettings] valueForKey:key];
}

#pragma mark -
#pragma mark NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(manUpConfigUpdateFailed:)]) {
        [self.delegate manUpConfigUpdateFailed:error];
    }
    [self refreshView];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    @synchronized(self) {

        if ([response respondsToSelector:@selector(statusCode)]) {
            NSInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];
            if (statusCode >= 400) {
                [connection cancel];
                NSDictionary *errorInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:
                                                                              NSLocalizedString(@"Server returned status code %d",@""),
                                                                              statusCode]
                                                                      forKey:NSLocalizedDescriptionKey];
                NSError *statusError = [NSError errorWithDomain:NSLocalizedString(@"ERROR", nil)
                                                           code:statusCode
                                                       userInfo:errorInfo];
                [self connection:connection didFailWithError:statusError];
                _updateInProgress = NO;
                
                [self refreshView];
                
            } else {
                _data = [[NSMutableData alloc]init];
            }
        }
    }
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    @synchronized(self) {
        [_data appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    @synchronized(self) {
        if (_data != nil && _data.length > 0) {
            [self setLastUpdated:[NSDate date]];
            // If JSONKit detects a null value it returns NSNull which cannot be saved
            // in NSUserDefaults. For that reason we get copy and replace all occurrences of
            // NSNull with the empty string.
            
            NSError *error = nil;
            NSDictionary* settings = [NSJSONSerialization JSONObjectWithData:_data options:0 error:&error];

            NSDictionary* nonNullSettings = [self replaceNullsWithEmptyStringInDictionary:settings];
            
            if (error) {
                if ([self.delegate respondsToSelector:@selector(manUpConfigUpdateFailed:)]) {
                    [self.delegate manUpConfigUpdateFailed:error];
                }
            }
            
            [self setManUpSettings:nonNullSettings];
        }
        _updateInProgress = NO;
        [self refreshView];
    }
}

@end
