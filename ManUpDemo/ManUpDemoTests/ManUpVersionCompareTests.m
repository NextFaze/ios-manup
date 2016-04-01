//
//  ManUpVersionCompareTests.m
//  ManUpDemo
//
//  Created by Ricardo Santos on 1/04/2016.
//  Copyright © 2016 NextFaze. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ManUp.h"

@interface ManUpVersionCompareTests : XCTestCase

@end

@implementation ManUpVersionCompareTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMajorVersionIsLess {
    NSComparisonResult result = [ManUp compareVersion:@"1.0" toVersion:@"2.0"];
    XCTAssertEqual(result, NSOrderedAscending, @"Result should be less than");
}

- (void)testMajorMinorVersionIsLess {
    NSComparisonResult result = [ManUp compareVersion:@"1.1" toVersion:@"2.0"];
    XCTAssertEqual(result, NSOrderedAscending, @"Result should be less than");
}

- (void)testMajorVersionIsEqual {
    NSComparisonResult result = [ManUp compareVersion:@"1.0" toVersion:@"1.0"];
    XCTAssertEqual(result, NSOrderedSame, @"Result should be equal");
}

- (void)testMajorVersionIsGreater {
    NSComparisonResult result = [ManUp compareVersion:@"2.0" toVersion:@"1.0"];
    XCTAssertEqual(result, NSOrderedDescending, @"Result should be greater than");
}

- (void)testMinorVersionIsLess {
    NSComparisonResult result = [ManUp compareVersion:@"0.1.0" toVersion:@"0.2.0"];
    XCTAssertEqual(result, NSOrderedAscending, @"Result should be less than");
}

- (void)testMinorVersionIsLessThanMajor {
    NSComparisonResult result = [ManUp compareVersion:@"0.1.0" toVersion:@"1.0"];
    XCTAssertEqual(result, NSOrderedAscending, @"Result should be less than");
}

- (void)testMinorVersionIsEqual {
    NSComparisonResult result = [ManUp compareVersion:@"0.1.0" toVersion:@"0.1.0"];
    XCTAssertEqual(result, NSOrderedSame, @"Result should be equal");
}

- (void)testMinorVersionIsGreater {
    NSComparisonResult result = [ManUp compareVersion:@"0.2.0" toVersion:@"0.1.0"];
    XCTAssertEqual(result, NSOrderedDescending, @"Result should be greater than");
}

- (void)testPatchVersionIsLess {
    NSComparisonResult result = [ManUp compareVersion:@"0.0.1" toVersion:@"0.0.2"];
    XCTAssertEqual(result, NSOrderedAscending, @"Result should be less than");
}

- (void)testPatchVersionIsLessThanMajor {
    NSComparisonResult result = [ManUp compareVersion:@"0.0.1" toVersion:@"1.0"];
    XCTAssertEqual(result, NSOrderedAscending, @"Result should be less than");
}

- (void)testPatchVersionIsEqual {
    NSComparisonResult result = [ManUp compareVersion:@"0.0.1" toVersion:@"0.0.1"];
    XCTAssertEqual(result, NSOrderedSame, @"Result should be equal");
}

- (void)testPatchVersionIsGreater {
    NSComparisonResult result = [ManUp compareVersion:@"0.0.2" toVersion:@"0.0.1"];
    XCTAssertEqual(result, NSOrderedDescending, @"Result should be greater than");
}

- (void)testNumericalIsLessThan {
    NSComparisonResult result = [ManUp compareVersion:@"0.1" toVersion:@"0.10"];
    XCTAssertEqual(result, NSOrderedAscending, @"Result should be less than");
}

@end
