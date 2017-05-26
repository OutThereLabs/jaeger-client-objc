#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "Agent.h"
#import "Jaeger.h"
#import "NSMutableURLRequest+APMTracing.h"
#import "Recorder.h"
#import "Sender.h"
#import "SpanContext.h"
#import "SpanWrapper.h"
#import "TBase.h"
#import "TBinaryProtocol.h"
#import "TCompactProtocol.h"
#import "TMultiplexedProtocol.h"
#import "TProtocol.h"
#import "TProtocolDecorator.h"
#import "TProtocolError.h"
#import "TProtocolFactory.h"
#import "TProtocolUtil.h"
#import "TApplicationError.h"
#import "TBaseClient.h"
#import "TError.h"
#import "Thrift.h"
#import "TProcessor.h"
#import "TProcessorFactory.h"
#import "TAsyncTransport.h"
#import "TFramedTransport.h"
#import "THTTPSessionTransport.h"
#import "THTTPTransport.h"
#import "TMemoryBuffer.h"
#import "TNSFileHandleTransport.h"
#import "TNSStreamTransport.h"
#import "TSocketTransport.h"
#import "TSSLSocketTransport.h"
#import "TSSLSocketTransportError.h"
#import "TTransport.h"
#import "TTransportError.h"
#import "TSharedProcessorFactory.h"
#import "Tracer.h"
#import "URLSessionTaskTracker.h"

FOUNDATION_EXPORT double JaegerVersionNumber;
FOUNDATION_EXPORT const unsigned char JaegerVersionString[];

