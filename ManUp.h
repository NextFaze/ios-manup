// TODO header


#import <Foundation/Foundation.h>

@protocol ManUpDelegate
@optional
-(void) manUpConfigUpdateStarting;
-(void) manUpConfigUpdateFailed:(NSError*)error;
-(void) manUpConfigUpdated:(NSDictionary*)newSettings;
@end

@interface ManUp : NSObject <NSURLConnectionDelegate>
{
    ManUp *_instance;
    BOOL _updateInProgress;
    BOOL _callDidLaunchWhenFinished;
    NSMutableData *_data; // used by NSURLConnectionDelegate
    id<ManUpDelegate> _delegate;
    NSURL* _lastServerConfigURL;
    
}

+(void) manUpWithDefaultDictionary:(NSDictionary*)defaultSettingsDict serverConfigURL:(NSURL*)serverConfigURL delegate:(id<ManUpDelegate>)delegate;
+(void) manUpWithDefaultJSONFile:(NSString*)defaultSettingsPath serverConfigURL:(NSURL*)serverConfigURL delegate:(id<ManUpDelegate>)delegate;

@property(nonatomic,strong) id<ManUpDelegate> delegate;
@property(nonatomic,strong) NSURL* lastServerConfigURL;

@end
