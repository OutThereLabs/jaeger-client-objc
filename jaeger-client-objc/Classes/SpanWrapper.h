//
//  JGRSpan.h
//  Pods
//
//  Created by Patrick Tescher on 5/23/17.
//
//

@import opentracing;

@class SpanContext, SpanRef, Tag, Log, Tracer;
@interface SpanWrapper : NSObject <OTSpan>

- (nonnull instancetype)initWithTracer:(nonnull Tracer *)tracer operationName:(nonnull NSString*)operationName startTime:(nonnull NSDate*)startTime parentSpanContext:(nullable SpanContext*)parentSpanContext;

// MARK: - Jaeger Span Properties

@property (readonly, nonnull) SpanContext *context;
@property (readonly, nonnull) NSDate *startTime;
@property (readonly, nullable) NSString *operationName;
@property (readonly, nonnull) NSArray<SpanRef*> *references;
@property (readonly) SInt64 startTimestamp;
@property (readonly) SInt64 duration;
@property (readonly, nonnull) NSMutableArray<Tag*> *tags;
@property (readonly, nonnull) NSMutableArray<Log*> *logs;

@end
