//
//  Sender.h
//  Pods
//
//  Created by Patrick Tescher on 5/23/17.
//
//

#import <Foundation/Foundation.h>

typedef void (^SenderCompletionBlock)(NSError*_Nullable);

@class Process, Span, Tag;
@interface Sender : NSObject

@property (nonatomic) int maxPendingSpans;
@property (strong, nonatomic, nonnull) NSArray<Tag*> *tags;

- (nonnull instancetype)initWithHost:(nonnull NSString *)host port:(uint16_t)port error:(NSError * _Nullable * _Nullable)error;
- (void)appendSpan:(nonnull Span *)span;
- (BOOL)flush:(NSError * _Nullable * _Nullable)error;
- (void)asyncFlush:(SenderCompletionBlock _Nullable)completionBlock;

@end
