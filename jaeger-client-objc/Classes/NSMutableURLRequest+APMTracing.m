//
//  NSMutableURLRequest+APMTracing.m
//  HawkularAPMTracer
//
//  Created by Patrick Tescher on 3/14/17.
//  Copyright © 2017 pat2man. All rights reserved.
//

#import "NSMutableURLRequest+APMTracing.h"
#import <opentracing/OTGlobal.h>
#import <opentracing/OTTracer.h>

@implementation NSMutableURLRequest (APMTracing)

- (id<OTSpan>)startSpanWithParentContext:(id<OTSpanContext>)parent {
    NSMutableDictionary *tags = [NSMutableDictionary new];
    tags[@"http.url"] = self.URL.absoluteString;
    tags[@"http.path"] = self.URL.path;
    tags[@"http.method"] = self.HTTPMethod;

    NSMutableArray *templateComponents = [NSMutableArray arrayWithCapacity:self.URL.pathComponents.count];
    for (NSString *pathComponent in self.URL.pathComponents) {
        NSMutableArray *templateSubComponents = [NSMutableArray arrayWithCapacity:self.URL.pathComponents.count];
        for (NSString *pathSubComponent in [pathComponent componentsSeparatedByString:@"."]) {
            if ([pathSubComponent isEqualToString:@"/"]) {
                [templateSubComponents addObject:@""];
            } else if ([[NSUUID alloc] initWithUUIDString:pathSubComponent] == nil) {
                [templateSubComponents addObject:pathSubComponent];
            } else {
                [templateSubComponents addObject:@":id"];
            }
        }
        [templateComponents addObject:[templateSubComponents componentsJoinedByString:@"."]];
    }
    NSString *templatePath = [templateComponents componentsJoinedByString:@"/"];

    NSString *spanName = [NSString stringWithFormat:@"%@ %@ %@", self.URL.scheme.uppercaseString ?: @"OTHER", self.HTTPMethod.uppercaseString ?: @"OTHER", templatePath];
    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:spanName childOf:parent tags:[tags copy]];

    NSMutableDictionary *headers = [NSMutableDictionary new];
    [[OTGlobal sharedTracer] inject:[span context] format:OTFormatHTTPHeaders carrier:headers];

    for (NSString *key in headers.allKeys) {
        [self setValue:headers[key] forHTTPHeaderField:key];
    }

    return span;
}

@end
