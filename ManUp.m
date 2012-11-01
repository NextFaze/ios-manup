// TODO header

#import "ManUp.h"
#import "JSONKit.h"

/* Image locations */

// Load up an image with this name (and @2x / -568h@2x) and they will
// display when a mandatory update is required.
static NSString *const ManUpUpdateRequiredBgImgName = @"manup-required";

/* User bundle key names */
static NSString *const kManUpSettings               = @"kManUpSettings";
static NSString *const kManUpServerConfigURL        = @"kManUpServerConfigURL";
static NSString *const kManUpLastUpdated            = @"kManUpLastUpdated";

/* Server side key names */
// required: the current version of the application
static NSString *const kManUpAppVersionCurrent      = @"kManUpAppVersionCurrent";
// required: the min version of the application
static NSString *const kManUpAppVersionMin          = @"kManUpAppVersionMin";
// optional: if not present there's no pathway to upgrade but the app is blocked (provided user_version < min)
static NSString *const kManUpAppUpdateLink          = @"kManUpAppUpdateLink";

# pragma mark -
# pragma mark UIImage helper
@interface UIImage (ManUp)

+ (UIImage *)imageConsidering586hNamed:(NSString *)imageName;

@end

@implementation UIImage (ManUp)

+ (UIImage *)imageConsidering586hNamed:(NSString *)imageName {
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

@interface ManUp()

// private methods
+(ManUp*)instance;

@end

@implementation ManUp

+(void) manUpWithDefaultDictionary:(NSDictionary*)defaultSettingsDict
                 serverConfigURL:(NSURL*)serverConfigURL
                        delegate:(id<ManUpDelegate>)delegate
                rootViewController:(UIViewController*)rootViewController {

    ManUp* instance = [ManUp instance];
    instance.delegate = delegate;
    instance.rootViewController = rootViewController;
    [instance setManUpSettingsIfNone:defaultSettingsDict];
}

+(void) manUpWithDefaultJSONFile:(NSString*)defaultSettingsPath
                 serverConfigURL:(NSURL*)serverConfigURL
                        delegate:(id<ManUpDelegate>)delegate
              rootViewController:(UIViewController*)rootViewController {

    ManUp* instance = [ManUp instance];
    instance.delegate = delegate;
    instance.rootViewController = rootViewController;
    instance.lastServerConfigURL = serverConfigURL;
    
    
    // Only apply defaults if they do not exist already.
    if(![instance hasPersistedSettings]) {
        NSData* jsonData = [NSData dataWithContentsOfFile:defaultSettingsPath];
        if(jsonData == nil) {
            // handle this error
            return;
        }
        JSONDecoder* decoder = [[JSONDecoder alloc]
                                initWithParseOptions:JKParseOptionNone];
        
        // If JSONKit detects a null value it returns NSNull which cannot be saved
        // in NSUserDefaults. For that reason we get copy and replace all occurrences of
        // NSNull with the empty string.
        NSDictionary* defaultSettings = [decoder objectWithData:jsonData];
        NSDictionary* nonNullDefaultSettings = [instance replaceNullsWithEmptyStringInDictionary:defaultSettings];
        [instance setManUpSettings:nonNullDefaultSettings];
    }
    
    [instance updateFromServer];
}

#pragma mark -
#pragma mark Instance and unexposed methods

+(ManUp*)instance {
    static ManUp *_instance = nil;
    if (_instance == nil)
    {
        _instance = [[ManUp alloc] init];

    }
    return _instance;
}

-(BOOL) dateIsLessThanOneHourOld:(NSDate*)date {
    return [date timeIntervalSinceNow] > 4; /*-60*60*/
}

- (id)init {
	if(self = [super init]) {
		_updateInProgress = NO;
        _callDidLaunchWhenFinished = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateFromServer)
                                                     name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didLaunch)
                                                     name:UIApplicationDidFinishLaunchingNotification object:nil];
        
	}
	return self;
}

- (NSDictionary*)replaceNullsWithEmptyStringInDictionary:(NSDictionary*)dict {
    NSMutableDictionary *newDict = [[NSMutableDictionary alloc] init];
    for(NSString *key in dict) {
        NSString *value = [dict objectForKey:key];
        if(value == nil || [value isKindOfClass:[NSNull class]]) {
            value = @"";
        }
        [newDict setValue:value forKey:key];
    }
    return newDict;
}

-(void) setManUpSettings:(NSDictionary*)settings {
    [[NSUserDefaults standardUserDefaults] setObject:settings forKey:kManUpSettings];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self setLastUpdated];
    if(_delegate != nil) {
        [_delegate manUpConfigUpdated:settings];
    }
}

-(void) setManUpSettingsIfNone:(NSDictionary*)settings {
    NSDictionary *persistedSettings = [self getPersistedSettings];
    if(persistedSettings == nil) {
        [self setManUpSettings:settings];
    }
}

- (void) setLastUpdated {
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kManUpLastUpdated];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSDate*) getLastUpdated {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kManUpLastUpdated];
}

-(NSDictionary*)getPersistedSettings {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kManUpSettings];
}

-(BOOL) hasPersistedSettings {
    return [self getPersistedSettings] != nil;
}

-(void) updateFromServer {
    if(_updateInProgress) {
        NSLog(@"ManUp: An update is currently in progress.");
        return;
    }
    
    NSDate *lastUpdated = [self getLastUpdated];
    
    if(lastUpdated != nil && [self dateIsLessThanOneHourOld:lastUpdated]) {
        NSLog(@"ManUp: Will not update. An update occurred recently.");
        NSLog(@"time interval since now: %f", [lastUpdated timeIntervalSinceNow]);
        return;
    }
    
    _updateInProgress = YES;
    if(_delegate != nil) {
        [_delegate manUpConfigUpdateStarting];
    }
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:_lastServerConfigURL cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:15];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [connection start];
}

-(void) showBackgroundView {
    NSLog(@"Show background view");
    
    UIImage *backgroundImage = [UIImage imageConsidering586hNamed:ManUpUpdateRequiredBgImgName];
    
    // Check for Default first if not provided.
    if(backgroundImage == nil) {
        NSLog(@"ManUp: Did not include image named %@", ManUpUpdateRequiredBgImgName);
        backgroundImage = [UIImage imageConsidering586hNamed:@"Default"];
    }
    
    // Failing that, look at the plist.
    if(backgroundImage == nil) {
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
        
    // Okay, I give up. Black background.
    if(backgroundImage == nil) {
        self.bgView = [[UIView alloc] initWithFrame:self.rootViewController.view.frame];
        self.bgView.backgroundColor = [UIColor blackColor];
    } else {
        self.bgView  = [[UIImageView alloc] initWithImage:backgroundImage];
    }
    self.modalViewController = [[UIViewController alloc] init];
    [self.modalViewController.view addSubview:self.bgView];
    [self.rootViewController presentModalViewController:self.modalViewController animated:NO];

}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(buttonIndex == 0) {
        // Update
        NSDictionary *settings = [self getPersistedSettings];
        NSString *updateURLString = [settings objectForKey:kManUpAppUpdateLink];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:updateURLString]];
    
        if(![alertView.title isEqualToString:@"Update Required"]) {
            // Alert closes and BG goes away: case of optional update.
            [self.modalViewController dismissModalViewControllerAnimated:NO];
        }
    } else {
        // Close
        [self.modalViewController dismissModalViewControllerAnimated:NO];
    }
}

/* On Lauch, we look at the most recently retrieved settings and if they are less than 1 hour old, use them
   to check if we need to display update or mandatory update dialogs. */
-(void) didLaunch {
    @synchronized(self) {

        _callDidLaunchWhenFinished = NO;
        // since we are updating right now, let's wait a little bit longer.
        if(_updateInProgress) {
            _callDidLaunchWhenFinished = YES;
            return;
        }
        NSLog(@"Did Launch");
    }
    
    NSDictionary *settings = [self getPersistedSettings];
    NSString *updateURLStr      = [settings objectForKey:kManUpAppUpdateLink];
    NSString *currentVersionStr = [settings objectForKey:kManUpAppVersionCurrent];
    NSString *minVersionStr     = [settings objectForKey:kManUpAppVersionMin];
    NSString *userVersionStr    = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    double currentVersion   = 0;
    double minVersion       = 0;
    double userVersion      = 0;
    
    if(currentVersionStr != nil && ![currentVersionStr isEqualToString:@""]) {
        currentVersion = [currentVersionStr doubleValue];
    }
    
    if(minVersionStr != nil && ![minVersionStr isEqualToString:@""]) {
        minVersion = -1;//[minVersionStr doubleValue];
    }
    
    if(userVersionStr != nil && ![userVersionStr isEqualToString:@""]) {
        userVersion = 0;//[userVersionStr doubleValue];
    }
    
    // Check if mandatory update is required.
    if(userVersion < minVersion ) {
        NSLog(@"ManUp: Mandatory update required.");
        
        if(updateURLStr == nil || [updateURLStr isEqualToString:@""]) {
            NSLog(@"ManUp: No update URL provided, blocking app access");
            [self showBackgroundView];
        } else {
            NSLog(@"ManUp: Blocking access and displaying update alert.");
            [self showBackgroundView];
            UIAlertView *alert = [[UIAlertView alloc]
                                  initWithTitle:@"Update Required"
                                  message: @"An update is required. To continue, please update the application."
                                  delegate: self
                                  cancelButtonTitle:@"Upgrade"
                                  otherButtonTitles:nil];
            [alert show];
        }
    }
    // Optional update
    else if(userVersion < currentVersion) {
        NSLog(@"ManUp: User doesn't have latest version.");
        if(updateURLStr != nil && ![updateURLStr isEqualToString:@""]) {
            UIAlertView *alert = [[UIAlertView alloc]
                                  initWithTitle:@"Update Required"
                                  message: @"An update is available. Would you like to update to the latest version?"
                                  delegate: self
                                  cancelButtonTitle:@"Upgrade"
                                  otherButtonTitles:@"No Thanks",nil];
            [alert show];
        }
    }
}

#pragma mark -
#pragma mark NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    @synchronized(self) {

        if(_delegate != nil) {
            [_delegate manUpConfigUpdateFailed:error];
        }
        _updateInProgress = NO;
        if(_callDidLaunchWhenFinished) {
            [self didLaunch];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    @synchronized(self) {

        if ([response respondsToSelector:@selector(statusCode)])
        {
            int statusCode = [((NSHTTPURLResponse *)response) statusCode];
            if (statusCode >= 400)
            {
                [connection cancel];
                NSDictionary *errorInfo
                = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:
                                                  NSLocalizedString(@"Server returned status code %d",@""),
                                                  statusCode]
                                          forKey:NSLocalizedDescriptionKey];
                NSError *statusError
                = [NSError errorWithDomain:@"ERROR"
                                  code:statusCode
                              userInfo:errorInfo];
                [self connection:connection didFailWithError:statusError];
                _updateInProgress = NO;
                if(_callDidLaunchWhenFinished) {
                    [self didLaunch];
                }
            } else {
                _data = [[NSMutableData alloc]init];
            }
        }
    }
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data {
    @synchronized(self) {
        
        [_data appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    @synchronized(self) {

        if(_data != nil && _data.length > 0) {
            JSONDecoder* decoder = [[JSONDecoder alloc]
                            initWithParseOptions:JKParseOptionNone];
            // If JSONKit detects a null value it returns NSNull which cannot be saved
            // in NSUserDefaults. For that reason we get copy and replace all occurrences of
            // NSNull with the empty string.
            NSDictionary* settings = [decoder objectWithData:_data];
            NSDictionary* nonNullSettings = [self replaceNullsWithEmptyStringInDictionary:settings];
            [self setManUpSettings:nonNullSettings];
        }
        _updateInProgress = NO;
        if(_callDidLaunchWhenFinished) {
            [self didLaunch];
        }
    }
}

@end
