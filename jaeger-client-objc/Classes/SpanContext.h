//
//  JGRSpanContext.h
//  Pods
//
//  Created by Patrick Tescher on 5/23/17.
//
//

@import opentracing;

@interface SpanContext : NSObject <OTSpanContext>

@property (readonly) SInt64 traceID;
@property (readonly) SInt64 spanID;
@property (readonly) SInt64 parentSpanID;
@property (readonly) SInt32 flags;
@property (readonly, nonnull) NSString *traceIDString;

- (nonnull instancetype)initWithParentSpanContext:(nullable SpanContext*)parentSpanContext;
+ (nullable instancetype)spanWithTraceIDString:(nonnull NSString*)traceIDString;

@end
