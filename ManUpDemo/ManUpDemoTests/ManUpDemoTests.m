//
//  ManUpDemoTests.m
//  ManUpDemoTests
//
//  Created by Ricardo Santos on 12/02/2016.
//  Copyright © 2016 NextFaze. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ManUp.h"

@interface ManUpDemoTests : XCTestCase <ManUpDelegate>

@property (nonatomic, strong) XCTestExpectation *expectation;
@property (nonatomic, assign) BOOL updated;

@end

@implementation ManUpDemoTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testManUpSettingForKey {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    id setting = [ManUp settingForKey:@"made-up-key"];
    XCTAssertNil(setting, @"There should be no setting for this made up key.");
}

- (void)testConfigUpdates {
    [[ManUp sharedInstance] manUpWithDefaultJSONFile:[[NSBundle mainBundle] pathForResource:@"TestVersionsEqual.json" ofType:@"json"]
                                     serverConfigURL:[NSURL URLWithString:@"https://github.com/NextFaze/ManUp/raw/develop/ManUpDemo/TestFiles/TestVersionsEqual.json"]
                                            delegate:self];
    
    self.expectation = [self expectationWithDescription:@"async test"];
    
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    
    XCTAssert(self.updated);
}

#pragma mark - ManUpDelegate

- (void)manUpConfigUpdateStarting {
    NSLog(@"TEST: update starting");
}

- (void)manUpConfigUpdateFailed:(NSError *)error {
    NSLog(@"TEST: update failed with error '%@'", error);
    [self.expectation fulfill];
}

- (void)manUpConfigUpdated:(NSDictionary *)newSettings {
    NSLog(@"TEST updated with settings:\n%@", newSettings);
    self.updated = YES;
    [self.expectation fulfill];
}

@end
