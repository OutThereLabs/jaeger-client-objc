//
//  JGRSpan.m
//  Pods
//
//  Created by Patrick Tescher on 5/23/17.
//
//

#import "SpanWrapper.h"
#import "Tracer.h"
#import "SpanContext.h"
#import "Recorder.h"
#import "Jaeger.h"

@interface SpanWrapper ()

@property (strong, atomic, nullable) NSString *operationName;
@property (strong, atomic, nonnull) Tracer *tracer;
@property (strong, atomic, nonnull) SpanContext *context;
@property (strong, atomic, nonnull) NSDate *startTime;
@property (strong, nonatomic, nullable) NSDate* finishedAt;

@property (strong, atomic, nonnull) NSMutableArray<SpanRef*> *references;
@property (strong, atomic, nonnull) NSMutableArray<Tag*> *tags;
@property (strong, atomic, nonnull) NSMutableArray<Log*> *logs;

@end

@implementation SpanWrapper

- (instancetype)initWithTracer:(Tracer *)tracer operationName:(NSString*)operationName startTime:(NSDate*)startTime parentSpanContext:(SpanContext*)parentSpanContext {
    self = [super init];
    if (self) {
        self.operationName = operationName;
        self.tracer = tracer;
        self.context = [[SpanContext alloc] initWithParentSpanContext:parentSpanContext];
        self.startTime = startTime;
        self.references = [NSMutableArray new];
        self.tags = [NSMutableArray new];
        self.logs = [NSMutableArray new];
    }

    return self;
}

- (void)log:(NSDictionary<NSString *,NSObject *> *)fields timestamp:(NSDate *)timestamp {
    NSMutableArray *tags = [NSMutableArray new];
    for (NSString *key in fields.allKeys) {
        Tag *tag = [[Tag alloc] initWithKey:key vType:TagTypeSTRING vStr:fields[key] vDouble:0 vBool:NO vLong:0 vBinary:[NSData data]];
        [tags addObject:tag];
    }

    NSTimeInterval timeInterval = [timestamp timeIntervalSince1970];
    Log *log = [[Log alloc] initWithTimestamp:timeInterval * 1000000 fields:tags];
    [self.logs addObject:log];
}

- (void)log:(NSString *)eventName timestamp:(NSDate *)timestamp payload:(NSObject *)payload {
    if (timestamp != nil) {
        [self log:@{@"event": eventName} timestamp:timestamp];
    }
}

- (void)setTag:(NSString *)key value:(NSString *)value {
    Tag *tag = [[Tag alloc] initWithKey:key vType:TagTypeSTRING vStr:value vDouble:0 vBool:NO vLong:0 vBinary:[NSData data]];
    [self.tags addObject:tag];
}

- (void)setTag:(NSString *)key boolValue:(BOOL)value {
    Tag *tag = [[Tag alloc] initWithKey:key vType:TagTypeBOOL vStr:@"" vDouble:0 vBool:value vLong:0 vBinary:[NSData data]];
    [self.tags addObject:tag];
}

- (void)setTag:(NSString *)key numberValue:(NSNumber *)value {
    Tag *tag = [[Tag alloc] initWithKey:key vType:TagTypeDOUBLE vStr:@"" vDouble:value.doubleValue vBool:NO vLong:0 vBinary:[NSData data]];
    [self.tags addObject:tag];
}

- (NSString *)getBaggageItem:(NSString *)key {
    return nil;
}

- (id<OTSpan>)setBaggageItem:(NSString *)key value:(NSString *)value {
    return nil;
}

- (void)finishWithTime:(NSDate *)finishTime {
    self.finishedAt = finishTime;
    [self.tracer.recorder record:self];
}

// MARK: - Span Properties

- (SInt64)startTimestamp {
    return [self.startTime timeIntervalSince1970] * 1000000;
}

- (SInt64)duration {
    NSTimeInterval duration = [self.finishedAt timeIntervalSinceDate:self.startTime];
    return duration * 1000000;
}

// MARK: - Convenience

- (void)log:(NSDictionary<NSString *,NSObject *> *)fields {
    [self log:fields timestamp:[NSDate date]];
}

- (void)logEvent:(NSString *)eventName {
    [self logEvent:eventName payload:nil];
}

- (void)logEvent:(NSString *)eventName payload:(NSObject *)payload {
    [self log:eventName timestamp:[NSDate date] payload:payload];
}

- (void)finish {
    [self finishWithTime:[NSDate date]];
}

@end
