//
//  JGRRecorder.m
//  Pods
//
//  Created by Patrick Tescher on 5/23/17.
//
//

#import "Recorder.h"
#import "Jaeger.h"
#import "SpanWrapper.h"
#import "Sender.h"
#import "SpanContext.h"

@interface Recorder ()

@property (strong, nonatomic, nonnull) Sender *sender;

@end

@implementation Recorder

- (instancetype)initWithBaseURL:(NSURL *)baseURL error:(NSError **)error {
    self = [super init];
    if (self) {
        int port = (baseURL.port ?: @(6832)).intValue;
        self.sender = [[Sender alloc] initWithHost:baseURL.host port:port error:error];
    }
    return self;
}
- (void)record:(SpanWrapper *)spanWrapper {
    Span *span = [[Span alloc] initWithTraceIdLow:spanWrapper.context.traceID
                                      traceIdHigh:0
                                           spanId:spanWrapper.context.spanID
                                     parentSpanId:spanWrapper.context.parentSpanID
                                    operationName:spanWrapper.operationName
                                       references:spanWrapper.references
                                            flags:spanWrapper.context.flags
                                        startTime:spanWrapper.startTimestamp
                                         duration:spanWrapper.duration
                                             tags:spanWrapper.tags
                                             logs:spanWrapper.logs];

    if (spanWrapper.context.flags > 0) {
        [self.sender appendSpan:span];
    }
}

@end
