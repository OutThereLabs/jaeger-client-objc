//
//  JGRRecorder.h
//  Pods
//
//  Created by Patrick Tescher on 5/23/17.
//
//

#import <Foundation/Foundation.h>

@class SpanWrapper, Sender;
@interface Recorder : NSObject

@property (readonly, nonnull) NSURL *baseURL;
@property (readonly, nonnull) Sender *sender;

- (nonnull instancetype)initWithBaseURL:(nonnull NSURL *)baseURL error:(NSError * _Nullable * _Nullable)error;

- (void)record:(SpanWrapper*_Nonnull)spanWrapper;

@end
