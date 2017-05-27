//
//  JGRSpanContext.m
//  Pods
//
//  Created by Patrick Tescher on 5/23/17.
//
//

#import "SpanContext.h"

@interface SpanContext ()

@property (nonatomic) SInt64 traceID;
@property (nonatomic) SInt64 spanID;
@property (nonatomic) SInt64 parentSpanID;
@property (nonatomic) SInt32 flags;

@end

@implementation SpanContext

- (instancetype)initWithParentSpanContext:(SpanContext *)parentSpanContext {
    self = [self init];
    if (self) {
        self.traceID = parentSpanContext.traceID;
        self.parentSpanID = parentSpanContext.spanID;
        [self generateIDs];
    }
    return self;
}

+ (instancetype)spanWithTraceIDString:(NSString *)traceIDString {
    NSArray *components = [traceIDString componentsSeparatedByString:@":"];

    if (components.count != 4) {
        return nil;
    }

    unsigned long long traceID;
    if ([components[0] isEqualToString:@"0"]) {
        traceID = 0;
    } else {
        NSScanner *traceIDScanner = [NSScanner scannerWithString:components[0]];
        [traceIDScanner scanHexLongLong:&traceID];
    }

    unsigned long long spanID;
    if ([components[1] isEqualToString:@"0"]) {
        spanID = 0;
    } else {
        NSScanner *spanIDScanner = [NSScanner scannerWithString:components[1]];
        [spanIDScanner scanHexLongLong:&spanID];
    }


    unsigned long long parentSpanID;
    if ([components[2] isEqualToString:@"0"]) {
        parentSpanID = 0;
    } else {
        NSScanner *parentSpanIDScanner = [NSScanner scannerWithString:components[2]];
        [parentSpanIDScanner scanHexLongLong:&parentSpanID];
    }


    unsigned flags;
    if ([components[3] isEqualToString:@"0"]) {
        flags = 0;
    } else {
        NSScanner *flagsScanner = [NSScanner scannerWithString:components[3]];
        [flagsScanner scanHexInt:&flags];
    }

    SpanContext *spanContext = [[self alloc] initWithTraceID:traceID spanID:spanID parentSpanID:parentSpanID flags:flags];
    NSAssert([spanContext.traceIDString isEqualToString:traceIDString], @"Trace ID string should match");
    return spanContext;
}

- (instancetype)initWithTraceID:(SInt64)traceID spanID:(SInt64)spanID parentSpanID:(SInt64)parentSpanID flags:(SInt32)flags {
    self = [self init];

    if (self) {
        self.traceID = traceID;
        self.spanID = spanID;
        self.parentSpanID = parentSpanID;
        self.flags = flags;
    }

    return self;
}

- (void)generateIDs {
    SInt64 randomNumber = (SInt64)arc4random();
    self.spanID = randomNumber;

    if (self.traceID <= 0) {
        self.traceID = self.spanID;
    }
}

- (void)forEachBaggageItem:(BOOL (^)(NSString * _Nonnull, NSString * _Nonnull))callback {

}

- (NSString *)traceIDString {
    return [NSString stringWithFormat:@"%llx:%llx:%llx:%x", self.traceID, self.spanID, self.parentSpanID, self.flags];
}

@end
