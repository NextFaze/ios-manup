//
//  ManUpDemoTests.m
//  ManUpDemoTests
//
//  Created by Ricardo Santos on 12/02/2016.
//  Copyright © 2016 NextFaze. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ManUp+Testing.h"

#define ServerConfigPath @"https://github.com/NextFaze/ManUp/raw/develop/ManUpDemo/TestFiles/"

@interface ManUpDemoTests : XCTestCase <ManUpDelegate>

@property (nonatomic, strong) XCTestExpectation *expectation;
@property (nonatomic, strong) ManUp *manUp;
@property (nonatomic, assign) BOOL updated;
@property (nonatomic, assign) BOOL failed;
@property (nonatomic, assign) BOOL updateAvailable;
@property (nonatomic, assign) BOOL updateRequired;
@property (nonatomic, assign) BOOL maintenanceMode;

@end

@implementation ManUpDemoTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.manUp = [[ManUp alloc] initWithConfigURL:nil delegate:self];
    self.manUp.enableConsoleLogging = YES;
}

- (void)tearDown {
    [super tearDown];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.updated = NO;
    self.failed = NO;
    self.updateAvailable = NO;
    self.updateRequired = NO;
}

- (void)testManUpSettingForKey {
    id setting = [self.manUp settingForKey:@"made-up-key"];
    XCTAssertNil(setting, @"There should be no setting for this made up key.");
}

- (void)testConfigInvalidURL {
    self.manUp.serverConfigURL = nil;
    [self.manUp validate];
    
    XCTAssert(self.failed == YES);
    XCTAssert(self.updated == NO);
}
    
- (void)testConfigVersionsEqual {
    self.manUp.serverConfigURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@TestVersionsEqual.json", ServerConfigPath]];
    [self.manUp validate];
    
    self.expectation = [self expectationWithDescription:@"ManUp with versions equal"];
    
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
    
    XCTAssert(self.failed == NO);
    XCTAssert(self.updated == YES);
}

- (void)testConfigLowerDeploymentTarget {
    NSString *operatingSystemVersion = [[UIDevice currentDevice] systemVersion];
    NSArray *versionComponents = [operatingSystemVersion componentsSeparatedByString:@"."];
    
    XCTAssert(versionComponents.count > 0, "Unable to determine OS version.");
    
    NSInteger operatingSystemMajorVersion = [versionComponents[0] integerValue];
    NSInteger lowerMajorVersion = operatingSystemMajorVersion - 1;
    NSString *testFilename = [NSString stringWithFormat:@"TestUpgradeAvailableDeploymentTarget%ld", (long)lowerMajorVersion];
    
    self.manUp.serverConfigURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.json", ServerConfigPath, testFilename]];
    [self.manUp validate];
    
    self.expectation = [self expectationWithDescription:@"ManUp update available as the update's deployment target is lower than the OS version"];
    
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
    
    XCTAssert(self.failed == NO);
    XCTAssert(self.updated == YES);
    XCTAssert(self.updateAvailable == YES);
    XCTAssert(self.updateRequired == NO);
}
    
- (void)testConfigSameDeploymentTarget {
    NSString *operatingSystemVersion = [[UIDevice currentDevice] systemVersion];
    NSArray *versionComponents = [operatingSystemVersion componentsSeparatedByString:@"."];
    
    XCTAssert(versionComponents.count > 0, "Unable to determine OS version.");
    
    NSInteger operatingSystemMajorVersion = [versionComponents[0] integerValue];
    NSString *testFilename = [NSString stringWithFormat:@"TestUpgradeAvailableDeploymentTarget%ld", (long)operatingSystemMajorVersion];
    
    self.manUp.serverConfigURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.json", ServerConfigPath, testFilename]];
    [self.manUp validate];
    
    self.expectation = [self expectationWithDescription:@"ManUp update available as the update's deployment target is the same (major) as the OS version"];
    
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
    
    XCTAssert(self.failed == NO);
    XCTAssert(self.updated == YES);
    XCTAssert(self.updateAvailable == YES);
    XCTAssert(self.updateRequired == NO);
}
    
- (void)testConfigHigherDeploymentTarget {
    NSString *operatingSystemVersion = [[UIDevice currentDevice] systemVersion];
    NSArray *versionComponents = [operatingSystemVersion componentsSeparatedByString:@"."];
    
    XCTAssert(versionComponents.count > 0, "Unable to determine OS version.");
    
    NSInteger operatingSystemMajorVersion = [versionComponents[0] integerValue];
    NSInteger higherMajorVersion = operatingSystemMajorVersion + 1;
    NSString *testFilename = [NSString stringWithFormat:@"TestUpgradeAvailableDeploymentTarget%ld", (long)higherMajorVersion];
    
    self.manUp.serverConfigURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.json", ServerConfigPath, testFilename]];
    [self.manUp validate];
    
    self.expectation = [self expectationWithDescription:@"ManUp update exists but is not available as the update's deployment target is higher than the OS version"];
    
    [self waitForExpectationsWithTimeout:60.0 handler:nil];

    XCTAssert(self.failed == NO);
    XCTAssert(self.updated == YES);
    XCTAssert(self.updateAvailable == NO);
    XCTAssert(self.updateRequired == NO);
}

- (void)testMaintenanceMode {
    self.manUp.serverConfigURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@TestMaintenanceMode.json", ServerConfigPath]];
    [self.manUp validate];
    
    self.expectation = [self expectationWithDescription:@"ManUp with maintenance mode is true"];
    
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
    
    XCTAssert(self.maintenanceMode == YES);
    XCTAssert(self.failed == NO);
    XCTAssert(self.updated == YES);
    XCTAssert(self.updateAvailable == NO);
    XCTAssert(self.updateRequired == NO);
}

#pragma mark - ManUpDelegate

- (void)manUpConfigUpdateStarting {
    NSLog(@"ManUpDelegate: update starting");
}

- (void)manUpConfigUpdateFailed:(NSError *)error {
    NSLog(@"ManUpDelegate: update failed with error '%@'", error);
    self.failed = YES;
    [self.expectation fulfill];
}

- (void)manUpConfigUpdated:(NSDictionary *)newSettings {
    NSLog(@"ManUpDelegate: updated with settings:\n%@", newSettings);
    self.updated = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // fulfill the expectation after a delay to allow the update available/required callbacks to complete first
        [self.expectation fulfill];
    });
}

- (BOOL)manUpShouldShowAlert {
    return NO;
}

- (void)manUpUpdateAvailable {
    NSLog(@"ManUpDelegate: update available");
    self.updateAvailable = YES;
}

- (void)manUpUpdateRequired {
    NSLog(@"ManUpDelegate: update required");
    self.updateRequired = YES;
}

- (void)manUpMaintenanceMode {
    NSLog(@"ManUpDelegate: maintenance mode");
    self.maintenanceMode = YES;
}

@end
