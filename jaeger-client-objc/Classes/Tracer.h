//
//  JGRTracer.h
//  Pods
//
//  Created by Patrick Tescher on 5/23/17.
//
//

@import opentracing;

@class Recorder;
@interface Tracer : NSObject <OTTracer>

@property (readonly, nonnull) Recorder *recorder;

- (nonnull instancetype)initWithBaseURL:(nonnull NSURL*)baseURL;
- (BOOL)flush:(NSError * _Nullable * _Nullable)error __deprecated;
- (void)asyncFlush:(nullable void (^)(NSError *_Nullable error))doneCallback;

@end
