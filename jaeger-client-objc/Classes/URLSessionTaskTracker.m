//
//  URLSessionTaskTracker.m
//  HawkularAPMTracer
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 pat2man. All rights reserved.
//

#import "URLSessionTaskTracker.h"
#import <opentracing/OTGlobal.h>
#import <opentracing/OTTracer.h>
#import <opentracing/OTSpan.h>
#import <opentracing/OTReference.h>

@implementation URLSessionTaskTracker

+ (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
    NSParameterAssert(task.originalRequest);
    id<OTSpanContext> parentContext = [[OTGlobal sharedTracer] extractWithFormat:OTFormatHTTPHeaders carrier:task.originalRequest.allHTTPHeaderFields];

    if (parentContext == nil) {
        return;
    }

    OTReference *reference = [OTReference followsFrom:parentContext];
    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:@"Metrics" references:@[reference] tags:nil startTime:metrics.taskInterval.startDate];

    for (NSURLSessionTaskTransactionMetrics *metric in metrics.transactionMetrics) {
        [self trackMetrics:metric parentContext:span.context];
    }

    [span finishWithTime:metrics.taskInterval.endDate];
}

+ (nullable NSDate*)logEvent:(NSString*)eventName timestamp:(NSDate*)timestamp toSpan:(id<OTSpan>)span andAppendToArray:(NSMutableArray**)array {
    if (timestamp) {
        [span log:@{@"event": eventName} timestamp:timestamp];
        [*array addObject:timestamp];
    }

    return timestamp;
}

+ (void)trackMetrics:(NSURLSessionTaskTransactionMetrics*)metrics parentContext:(id<OTSpanContext>)parentContext {
    NSString *spanName = @"Transaction";

    switch (metrics.resourceFetchType) {
        case NSURLSessionTaskMetricsResourceFetchTypeUnknown:
            spanName = @"Unknown";
            break;
        case NSURLSessionTaskMetricsResourceFetchTypeLocalCache:
            spanName = @"Local Cache";
            break;
        case NSURLSessionTaskMetricsResourceFetchTypeServerPush:
            spanName = @"Server Push";
            break;
        case NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad:
            spanName = @"Network Load";
            break;
    }

    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:spanName childOf:parentContext tags:nil startTime:metrics.fetchStartDate];

    [span setTag:@"network.protocol.name" value:metrics.networkProtocolName];
    [span setTag:@"connection.refused" boolValue:metrics.reusedConnection];
    [span setTag:@"connection.proxy" boolValue:metrics.proxyConnection];

    NSMutableArray *possibleEndDates = [[NSMutableArray alloc] initWithCapacity:10];

    [self logEvent:@"Domain Lookup Start" timestamp:metrics.domainLookupStartDate toSpan:span andAppendToArray:&possibleEndDates];

    [self logEvent:@"Domain Lookup Start" timestamp:metrics.domainLookupStartDate toSpan:span andAppendToArray:&possibleEndDates];
    [self logEvent:@"Domain Lookup End" timestamp:metrics.domainLookupEndDate toSpan:span andAppendToArray:&possibleEndDates];

    [self logEvent:@"Connect Start" timestamp:metrics.connectStartDate toSpan:span andAppendToArray:&possibleEndDates];
    [self logEvent:@"Secure Connection Start" timestamp:metrics.secureConnectionStartDate toSpan:span andAppendToArray:&possibleEndDates];
    [self logEvent:@"Secure Connection End" timestamp:metrics.secureConnectionEndDate toSpan:span andAppendToArray:&possibleEndDates];
    [self logEvent:@"Connect End" timestamp:metrics.connectEndDate toSpan:span andAppendToArray:&possibleEndDates];

    [self logEvent:@"Request Start" timestamp:metrics.requestStartDate toSpan:span andAppendToArray:&possibleEndDates];
    [self logEvent:@"Request End" timestamp:metrics.requestEndDate toSpan:span andAppendToArray:&possibleEndDates];

    [self logEvent:@"Response Start" timestamp:metrics.responseStartDate toSpan:span andAppendToArray:&possibleEndDates];
    [self logEvent:@"Response End" timestamp:metrics.responseEndDate toSpan:span andAppendToArray:&possibleEndDates];

    NSDate *endDate = [possibleEndDates valueForKeyPath:@"@max.self"];

    [span finishWithTime:endDate ?: metrics.fetchStartDate];
}

@end
