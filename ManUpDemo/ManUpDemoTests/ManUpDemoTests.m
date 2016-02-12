//
//  ManUpDemoTests.m
//  ManUpDemoTests
//
//  Created by Ricardo Santos on 12/02/2016.
//  Copyright © 2016 NextFaze. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ManUp.h"

@interface ManUpDemoTests : XCTestCase

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

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
