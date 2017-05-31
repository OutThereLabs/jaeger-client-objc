//
//  Sender.m
//  Pods
//
//  Created by Patrick Tescher on 5/23/17.
//
//

#import "Sender.h"
#import "Jaeger.h"
#import "Agent.h"
#import "TMemoryBuffer.h"
#import "TCompactProtocol.h"

@import CocoaAsyncSocket;

@interface Sender () <GCDAsyncUdpSocketDelegate>

@property (strong, nonatomic, nonnull) NSString *host;
@property (nonatomic) uint16_t port;
@property (strong, nonatomic, nonnull) NSMutableArray<Span*> *pendingSpans;
@property (strong, nonatomic, nonnull) NSMutableDictionary<NSNumber*, SenderCompletionBlock> *pendingCompletionBlocks;
@property (strong, nonatomic, nonnull) AgentClient *client;
@property (strong, nonatomic, nonnull) TMemoryBuffer *buffer;
@property (strong, nonatomic, nonnull) GCDAsyncUdpSocket *socket;
@property (weak, nonatomic, nullable) NSTimer *flushTimer;
@property (readonly) BOOL shouldFlush;

@end

@implementation Sender

- (BOOL)shouldFlush {
    @synchronized (self) {
        return self.pendingSpans.count >= self.maxPendingSpans;
    }
}

- (instancetype)initWithHost:(NSString *)host port:(uint16_t)port error:(NSError **)error {
    self = [super init];
    if (self) {
        self.maxPendingSpans = 100;
        self.host = host;
        self.port = port;

        self.socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        self.pendingSpans = [NSMutableArray new];
        self.pendingCompletionBlocks = [NSMutableDictionary new];
        self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(flushTimerHit:) userInfo:nil repeats:YES];

        [self resetBuffer];
    }
    return self;
}

- (void)appendSpan:(Span *)span {
    @synchronized(self) {
        [self.pendingSpans addObject:span];
    }

    if (self.shouldFlush) {
        NSError *error;
        [self flush:&error];

        if (error) {
            NSLog(@"Error flushing after appending span: %@", error);
        }
    }
}

- (BOOL)flush:(NSError**)error {
    @try {
        [self flushSpans:error];
        return true;
    } @catch (NSException *exception) {
        NSLog(@"Exception: %@", exception);
        return false;
    }
}


- (void)asyncFlush:(SenderCompletionBlock)completionBlock {
    @synchronized(self) {
        if (self.pendingSpans.count < 1) {
            completionBlock(nil);
        }

        NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
        Process *process = [[Process alloc] initWithServiceName:bundleInfo[@"CFBundleName"] tags:self.tags];

        Batch *batch = [[Batch alloc] initWithProcess:process spans:self.pendingSpans];

        self.pendingSpans = [NSMutableArray new];

        NSError *error;
        if (![self.client emitBatch:batch error:&error]) {
            NSLog(@"Error flushing spans");
            completionBlock(error);
            return;
        }

        if (completionBlock != nil) {
            long tag = 0;
            while ([self.pendingCompletionBlocks.allKeys containsObject:@(tag)] || tag == 0) {
                tag = arc4random();
            }
            self.pendingCompletionBlocks[@(tag)] = completionBlock;

            [self flushBufferWithTag:tag];
        } else {
            [self flushBuffer:nil];
        }
    }
}

- (void)flushTimerHit:(NSTimer*)timer {
    NSError *error;
    [self flush:&error];

    if (error) {
        NSLog(@"Error flushing from timer: %@", error);
    }
}

- (void)flushSpans:(NSError **)error {
    @synchronized(self) {
        if (self.pendingSpans.count < 1) {
            return;
        }

        NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
        Process *process = [[Process alloc] initWithServiceName:bundleInfo[@"CFBundleName"] tags:self.tags];

        Batch *batch = [[Batch alloc] initWithProcess:process spans:self.pendingSpans];
        if (![self.client emitBatch:batch error:error] || ![self flushBuffer:error]) {
            NSLog(@"Error flushing spans");
        }
        self.pendingSpans = [NSMutableArray new];
    }
}

- (void)resetBuffer {
    self.buffer = [TMemoryBuffer new];
    TCompactProtocol *protocol = [[TCompactProtocol alloc] initWithTransport:self.buffer];
    self.client = [[AgentClient alloc] initWithProtocol:protocol];
}

- (BOOL)flushBuffer:(NSError **)error {
    [self flushBufferWithTag:0];
    return YES;
}

- (void)flushBufferWithTag:(long)tag {
    NSData *data = [[NSData alloc] initWithData:[self.buffer buffer]];

    [self resetBuffer];

    [self.socket sendData:data toHost:self.host port:self.port withTimeout:60 tag:tag];
    [self.socket closeAfterSending];
}

// MARK: - GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {

}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error {
    NSLog(@"Did not connect: %@", error);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
    @synchronized (self) {
        SenderCompletionBlock block = [self.pendingCompletionBlocks objectForKey:@(tag)];
        if (block != nil) {
            [self.pendingCompletionBlocks removeObjectForKey:@(tag)];
            block(nil);
        } else if (block != 0) {
            NSLog(@"Could not line up completion block for tag %@", @(tag));
        }
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError * _Nullable)error {
    @synchronized (self) {
        SenderCompletionBlock block = [self.pendingCompletionBlocks objectForKey:@(tag)];
        if (block != nil) {
            [self.pendingCompletionBlocks removeObjectForKey:@(tag)];
            block(error);
        } else if (block != 0) {
            NSLog(@"Could not line up completion block for tag %@", @(tag));
        }
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {

}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    if (error != nil) {
        NSLog(@"Socket closed: %@", error);
    }
}

@end
