//
//  JGRTracer.m
//  Pods
//
//  Created by Patrick Tescher on 5/23/17.
//
//

#import "Tracer.h"
#import "SpanWrapper.h"
#import "SpanContext.h"
#import "Jaeger.h"
#import "Recorder.h"
#import "Sender.h"

@interface Tracer ()

@property (strong, nonatomic, nonnull) Recorder *recorder;

@end

@implementation Tracer

- (instancetype)initWithBaseURL:(NSURL *)baseURL {
    self = [super init];
    if (self) {
        NSError *error = nil;
        self.recorder = [[Recorder alloc] initWithBaseURL:baseURL error:&error];
        if (error != nil) {
            NSLog(@"Error setting up tracer: %@", error);
        } else {
            [OTGlobal initSharedTracer:self];
        }
    }

    return self;
}

- (id<OTSpan>)startSpan:(NSString *)operationName {
    return [self startSpan:operationName tags:nil];
}

- (id<OTSpan>)startSpan:(NSString *)operationName childOf:(id<OTSpanContext>)parent {
    return [self startSpan:operationName childOf:parent tags:@{}];
}

- (id<OTSpan>)startSpan:(NSString *)operationName tags:(NSDictionary *)tags {
    return [self startSpan:operationName references:@[] tags:tags startTime:[NSDate new]];
}

- (id<OTSpan>)startSpan:(NSString *)operationName childOf:(id<OTSpanContext>)parent tags:(NSDictionary *)tags {
    return [self startSpan:operationName childOf:parent tags:tags startTime:[NSDate date]];
}

- (id<OTSpan>)startSpan:(NSString *)operationName childOf:(id<OTSpanContext>)parent tags:(NSDictionary *)tags startTime:(NSDate *)startTime {
    OTReference *reference = [OTReference childOf:parent];
    return [self startSpan:operationName references:@[reference] tags:tags startTime:startTime];
}

- (id<OTSpan>)startSpan:(NSString *)operationName references:(NSArray *)references tags:(NSDictionary *)tags startTime:(NSDate *)startTime {
    SpanContext *parentSpanContext = nil;

    for (OTReference *reference in references) {
        if ([reference.type isEqualToString:OTReferenceChildOf] && [(NSObject*)reference.referencedContext isKindOfClass:[SpanContext class]]) {
            NSAssert(parentSpanContext == nil, @"Should only have one parent span context reference");
            parentSpanContext = (SpanContext*)reference.referencedContext;
        }
    }

    SpanWrapper *spanWrapper = [[SpanWrapper alloc] initWithTracer:self operationName:operationName startTime:startTime parentSpanContext:parentSpanContext];
    for (NSString *key in tags.allKeys) {
        [spanWrapper setTag:key value:tags[key]];
    }
    return spanWrapper;
}

- (BOOL)inject:(id<OTSpanContext>)spanContext format:(NSString *)format carrier:(id)carrier {
    return [self inject:spanContext format:format carrier:carrier error: nil];
}

- (BOOL)inject:(id<OTSpanContext>)spanContext format:(NSString *)format carrier:(id)carrier error:(NSError * _Nullable __autoreleasing *)outError {
    if ([(NSObject*)spanContext isKindOfClass: [SpanContext class]] && ([format isEqualToString:OTFormatHTTPHeaders] || [format isEqualToString:OTFormatTextMap]) && [carrier isKindOfClass:[NSMutableDictionary class]]) {
        NSMutableDictionary *headers = (NSMutableDictionary*)carrier;
        SpanContext *injectedSpanContext = (SpanContext*)spanContext;
        headers[@"uber-trace-id"] = injectedSpanContext.traceIDString;
        return YES;
    }

    return NO;
}

- (id<OTSpanContext>)extractWithFormat:(NSString *)format carrier:(id)carrier {
    return [self extractWithFormat:format carrier: carrier error: nil];
}

- (id<OTSpanContext>)extractWithFormat:(NSString *)format carrier:(id)carrier error:(NSError * _Nullable __autoreleasing *)outError {
    if (!([format isEqualToString:OTFormatHTTPHeaders] || [format isEqualToString:OTFormatTextMap])  || ![carrier isKindOfClass:[NSDictionary class]]) {
        //TODO: Error
        return nil;
    }

    NSString *uberTraceID = ((NSDictionary*)carrier)[@"uber-trace-id"];
    SpanContext *context = [SpanContext spanWithTraceIDString:uberTraceID];
    return context;
}

- (BOOL)flush:(NSError **)error {
    return [self.recorder.sender flush:error];
}

- (void)asyncFlush:(void (^)(NSError * _Nullable))doneCallback {
    [self.recorder.sender asyncFlush:doneCallback];
}

@end
