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

@property (strong, atomic, nonnull) NSArray<SpanRef*> *references;
@property (strong, atomic, nonnull) NSMutableArray<Tag*> *tags;
@property (strong, atomic, nonnull) NSMutableArray<Log*> *logs;

@end

@implementation SpanWrapper

+ (nullable SpanContext*)parentSpanContextFromReferences:(NSArray<OTReference*>*)references {
    SpanContext *parentSpanContext = nil;

    for (OTReference *reference in references) {
        if ([reference.type isEqualToString:OTReferenceChildOf] && [(NSObject*)reference.referencedContext isKindOfClass:[SpanContext class]]) {
            NSAssert(parentSpanContext == nil, @"Should only have one parent span context reference");
            parentSpanContext = (SpanContext*)reference.referencedContext;
        }
    }

    return parentSpanContext;
}

+ (nonnull NSArray<SpanRef*>*)spanRefsFromOTReferences:(NSArray<OTReference*>*)otReferences {
    NSMutableArray *spanRefs = [[NSMutableArray alloc] initWithCapacity:otReferences.count];

    for (OTReference *otReference in otReferences) {
        if ([(NSObject*)otReference.referencedContext isKindOfClass:[SpanContext class]]) {
            SpanRefType refType;

            if ([otReference.type isEqualToString:OTReferenceChildOf]) {
                refType = SpanRefTypeCHILD_OF;
            } else if ([otReference.type isEqualToString:OTReferenceFollowsFrom]) {
                refType = SpanRefTypeFOLLOWS_FROM;
            } else {
                break;
            }

            SpanContext *referencedContext = (SpanContext*)otReference.referencedContext;
            SpanRef *spanRef = [[SpanRef alloc] initWithRefType:refType traceIdLow:referencedContext.traceID traceIdHigh:0 spanId:referencedContext.spanID];
            [spanRefs addObject:spanRef];
        }
    }

    return [spanRefs copy];
}

- (instancetype)initWithTracer:(Tracer *)tracer operationName:(NSString *)operationName startTime:(NSDate *)startTime references:(NSArray<OTReference *> *)references {
    self = [super init];
    if (self) {
        self.operationName = operationName;
        self.tracer = tracer;
        self.context = [[SpanContext alloc] initWithParentSpanContext:[SpanWrapper parentSpanContextFromReferences:references]];
        self.startTime = startTime;
        self.references = [SpanWrapper spanRefsFromOTReferences:references];
        self.tags = [NSMutableArray new];
        self.logs = [NSMutableArray new];
    }

    return self;
}

- (void)log:(NSDictionary<NSString *,NSObject *> *)fields timestamp:(NSDate *)timestamp {
    NSMutableArray *tags = [NSMutableArray new];
    for (NSString *key in fields.allKeys) {
        if ([fields[key] isKindOfClass:[NSString class]]) {
            Tag *tag = [[Tag alloc] initWithKey:key vType:TagTypeSTRING vStr:(NSString*)fields[key] vDouble:0 vBool:NO vLong:0 vBinary:[NSData data]];
            [tags addObject:tag];
        } else if ([fields[key] isKindOfClass:[NSNumber class]]) {
            NSNumber *number = (NSNumber*)fields[key];
            Tag *tag = [[Tag alloc] initWithKey:key vType:TagTypeDOUBLE vStr:@"" vDouble:number.doubleValue vBool:NO vLong:0 vBinary:[NSData data]];
            [tags addObject:tag];
        } else {
            NSString *description = ((NSObject*)fields[key]).description;
            Tag *tag = [[Tag alloc] initWithKey:key vType:TagTypeSTRING vStr:description vDouble:0 vBool:NO vLong:0 vBinary:[NSData data]];
            [tags addObject:tag];
        }
    }

    NSTimeInterval timeInterval = [timestamp timeIntervalSince1970];
    Log *log = [[Log alloc] initWithTimestamp:timeInterval * 1000000 fields:tags];
    [self.logs addObject:log];
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

- (void)log:(NSString *)eventName timestamp:(NSDate *)timestamp payload:(NSObject *)payload {
    if (timestamp != nil) {
        [self log:@{@"event": eventName} timestamp:timestamp];
    }
}

- (void)finish {
    [self finishWithTime:[NSDate date]];
}

@end
