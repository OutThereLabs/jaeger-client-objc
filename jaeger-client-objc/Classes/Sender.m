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
@property (strong, nonatomic, nonnull) AgentClient *client;
@property (strong, nonatomic, nonnull) TMemoryBuffer *buffer;
@property (strong, nonatomic, nonnull) GCDAsyncUdpSocket *socket;
@property (weak, nonatomic, nullable) NSTimer *flushTimer;
@property (readonly) BOOL shouldFlush;

@end

@implementation Sender

- (BOOL)shouldFlush {
    return self.pendingSpans.count >= self.maxPendingSpans;
}

- (instancetype)initWithHost:(NSString *)host port:(uint16_t)port error:(NSError **)error {
    self = [super init];
    if (self) {
        self.maxPendingSpans = 10;
        self.host = host;
        self.port = port;

        self.socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        self.pendingSpans = [NSMutableArray new];
        self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(flushTimerHit:) userInfo:nil repeats:YES];

        [self resetBuffer];
    }
    return self;
}

- (void)appendSpan:(Span *)span {
    [self.pendingSpans addObject:span];

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

- (void)flushTimerHit:(NSTimer*)timer {
    NSError *error;
    [self flush:&error];

    if (error) {
        NSLog(@"Error flushing from timer: %@", error);
    }
}

- (void)flushSpans:(NSError **)error {
    if (self.pendingSpans.count < 1) {
        return;
    }

    NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
    Process *process = [[Process alloc] initWithServiceName:bundleInfo[@"CFBundleName"] tags:self.tags];

    NSArray<Span*> *spans = [NSArray arrayWithArray:self.pendingSpans];
    [self.pendingSpans removeAllObjects];

    Batch *batch = [[Batch alloc] initWithProcess:process spans:spans];
    if (![self.client emitBatch:batch error:error] || ![self flushBuffer:error]) {
        NSLog(@"Error flushing spans");
    }
}

- (void)resetBuffer {
    self.buffer = [TMemoryBuffer new];
    TCompactProtocol *protocol = [[TCompactProtocol alloc] initWithTransport:self.buffer];
    self.client = [[AgentClient alloc] initWithProtocol:protocol];
}

- (BOOL)flushBuffer:(NSError **)error {
    NSData *data = [[NSData alloc] initWithData:[self.buffer buffer]];

    [self resetBuffer];

    [self.socket sendData:data toHost:self.host port:self.port withTimeout:60 tag:0];
    [self.socket closeAfterSending];

    return YES;
}

// MARK: - GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {

}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error {
    NSLog(@"Did not connect: %@", error);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {

}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError * _Nullable)error {
    NSLog(@"Did not send data duel to error: %@", error);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {

}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    if (error != nil) {
        NSLog(@"Socket closed: %@", error);
    }
}

@end
