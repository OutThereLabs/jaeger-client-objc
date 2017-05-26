//
//  jaeger-client-objcTests.m
//  jaeger-client-objcTests
//
//  Created by pat2man on 05/23/2017.
//  Copyright (c) 2017 pat2man. All rights reserved.
//

@import XCTest;
@import opentracing;
#import "Tracer.h"

@interface Tests : XCTestCase

@property (strong, nonatomic, nonnull) Tracer *tracer;

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    NSURL *baseURL = [NSURL URLWithString:@"thrift://localhost:6832"];
    self.tracer = [[Tracer alloc] initWithBaseURL:baseURL];

}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSpanSending {
    NSDictionary *tags = @{@"foo": @"bar", @"test.type": @"xctest"};
    NSDate *oneMinuteAgo = [NSDate dateWithTimeIntervalSinceNow:-60];
    id<OTSpan> testSpan = [[OTGlobal sharedTracer] startSpan:@"Parent" childOf:nil tags:tags startTime:oneMinuteAgo];

    for (int i = 0; i < 10; i++) {
        NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:-60 + (6 * i)];
        NSDate *finishDate = [NSDate dateWithTimeInterval:6 sinceDate:startDate];
        NSString *spanName = [NSString stringWithFormat:@"Child #%@", @(i)];
        id<OTSpan> childSpan = [[OTGlobal sharedTracer] startSpan:spanName childOf:testSpan.context tags:tags startTime:startDate];
        [childSpan logEvent:@"Test Event"];
        [childSpan finishWithTime:finishDate];
    }

    NSDate *finishTime = [NSDate date];

    [testSpan finishWithTime:finishTime];

    while([[NSDate date] timeIntervalSinceDate:finishTime] < 5) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

@end

