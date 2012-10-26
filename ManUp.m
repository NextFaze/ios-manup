// TODO header

#import "ManUp.h"
#import "JSONKit.h"

static NSString *const kManUpSettings               = @"kManUpSettings";
static NSString *const kManUpServerConfigURL        = @"kManUpServerConfigURL";
static NSString *const kManUpLastUpdated            = @"kManUpLastUpdated";


// required: the current version of the application
static NSString *const kManUpAppVersionCurrent      = @"kManUpAppVersionCurrent";
// required: the min version of the application
static NSString *const kManUpAppVersionMin          = @"kManUpAppVersionMin";
// optional: if not present, splash screen displayed behind dialog.
static NSString *const kManUpAppVersionImage        = @"kManUpAppVersionImage";
// optional: if not present there's no pathway to upgrade but the app is blocked (provided user_version < min)
static NSString *const kManUpAppUpdateLink          = @"kManUpAppUpdateLink";

@interface ManUp()

// private methods
+(ManUp*)instance;

@end

@implementation ManUp

+(void) manUpWithDefaultDictionary:(NSDictionary*)defaultSettingsDict
                 serverConfigURL:(NSURL*)serverConfigURL
                        delegate:(id<ManUpDelegate>)delegate {
    ManUp* instance = [ManUp instance];
    instance.delegate = delegate;

    [instance setManUpSettingsIfNone:defaultSettingsDict];
}

+(void) manUpWithDefaultJSONFile:(NSString*)defaultSettingsPath
                 serverConfigURL:(NSURL*)serverConfigURL
                        delegate:(id<ManUpDelegate>)delegate {
    ManUp* instance = [ManUp instance];
    instance.delegate = delegate;
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
    [_delegate manUpConfigUpdated:settings];
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
    [_delegate manUpConfigUpdateStarting];
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:_lastServerConfigURL cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:15];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [connection start];
}

-(void) showBackgroundView:(NSString*)backgroundURLString {
    NSLog(@"Show background view");
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
    NSString *updateURLString       = [settings objectForKey:kManUpAppUpdateLink];
    NSString *backgroundURLString   = [settings objectForKey:kManUpAppVersionImage];
    NSString *currentVersiuon       = [settings objectForKey:kManUpAppVersionCurrent];
    NSString *minVersion            = [settings objectForKey:kManUpAppVersionMin];
    NSString *userVersion           = [[[NSBundle mainBundle] infoDictionary]
                                       objectForKey:@"CFBundleVersion"];
    
    // Check if mandatory update is required.
    if(userVersion < minVersion ) {
        NSLog(@"ManUp: Mandatory update required.");
        
        if(updateURLString != nil && ![updateURLString isEqualToString:@""]) {
            NSLog(@"ManUp: No update URL provided, blocking app access");
            [self showBackgroundView:backgroundURLString];
        }
    }
    
    
    // if kManUpAppUpdateLink is not provided, then only mandatory updates will
    // do anything. Specifically, they will block inevitably. This is for
    // end-of-life apps.
    
    
}

#pragma mark -
#pragma mark NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    @synchronized(self) {

        [_delegate manUpConfigUpdateFailed:error];
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
