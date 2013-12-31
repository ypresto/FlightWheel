//
//  FGFSConnection.m
//  FlightWheel
//
//  Created by ypresto on 13/10/21.
//  Copyright (c) 2013年 Yuya Tanaka. All rights reserved.
//

#import "FGFSPropertyTreeClient.h"

#import <CHCircularBufferQueue.h>

typedef enum ReceiveDataTypeTag : char {
    ReceiveDataTypeString = 'S',
    ReceiveDataTypeDouble = 'D',
    ReceiveDataTypeLong   = 'L',
    ReceiveDataTypeInt    = 'I',
    ReceiveDataTypeBool   = 'B',
} ReceiveDataType;

@implementation FGFSPropertyTreeClient {
    CHCircularBufferQueue *queue;
    BOOL isReady;
}

static const NSTimeInterval kSocketTimeout = 3.0;
static const NSUInteger kSocketMaxLength = 102400u;
static const NSUInteger kQueueCapacity = 4096u;

- (void)bindToHost:(NSString *)host onPort:(uint16_t)port {
    [self unbind];

    _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    [_socket connectToHost:host onPort:port withTimeout:kSocketTimeout error:&error];

    if (error) {
        assert(false);
    }
}

- (void)unbind {
    [_socket disconnect];
    _socket = nil;
    queue = nil;
    isReady = NO;
}

- (void)requestStringValueForKey:(NSString *)key {
    [self requestValueForKey:key receiveDataType:ReceiveDataTypeString];
}

- (void)requestDoubleValueForKey:(NSString *)key {
    [self requestValueForKey:key receiveDataType:ReceiveDataTypeDouble];
}

- (void)requestLongValueForKey:(NSString *)key {
    [self requestValueForKey:key receiveDataType:ReceiveDataTypeLong];
}

- (void)requestIntValueForKey:(NSString *)key {
    [self requestValueForKey:key receiveDataType:ReceiveDataTypeInt];
}

- (void)requestBoolValueForKey:(NSString *)key {
    [self requestValueForKey:key receiveDataType:ReceiveDataTypeBool];
}

- (void)requestValueForKey:(NSString *)key receiveDataType:(ReceiveDataType)receiveDataType {
    if (!isReady) return;

    NSData *data = [[NSString stringWithFormat:@"get %@\r\n", key] dataUsingEncoding:NSUTF8StringEncoding];
    [_socket writeData:data withTimeout:3 tag:0];

    [queue addObject:key];
    [_socket readDataToData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:kSocketTimeout maxLength:kSocketMaxLength tag:receiveDataType];
}

- (void)writeStringValue:(NSString *)stringValue forKey:(NSString *)key {
    if (!isReady) return;

    // typedef simgear::PropertyObject<std::string> SGPropObjString;
    NSData *data = [[NSString stringWithFormat:@"set %@ %@\r\n", key, stringValue] dataUsingEncoding:NSUTF8StringEncoding];
    [_socket writeData:data withTimeout:kSocketTimeout tag:0];
}

- (void)writeDoubleValue:(double)doubleValue forKey:(NSString *)key {
    // typedef simgear::PropertyObject<double> SGPropObjDouble;
    [self writeStringValue:[NSString stringWithFormat:@"%f", doubleValue] forKey:key];
}

- (void)writeLongValue:(long)longValue forKey:(NSString *)key {
    // typedef simgear::PropertyObject<long> SGPropObjInt;
    [self writeStringValue:[NSString stringWithFormat:@"%ld", longValue] forKey:key];
}

- (void)writeIntValue:(int)intValue forKey:(NSString *)key {
    // typedef simgear::PropertyObject<long> SGPropObjInt;
    [self writeStringValue:[NSString stringWithFormat:@"%d", intValue] forKey:key];
}

- (void)writeBoolValue:(BOOL)boolValue forKey:(NSString *)key {
    // typedef simgear::PropertyObject<bool> SGPropObjBool;
    [self writeIntValue:(boolValue ? 1 : 0) forKey:key];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    if (sock != _socket) return;

    [_socket writeData:[@"data\r\n" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:kSocketTimeout tag:0];
    queue = [[CHCircularBufferQueue alloc] initWithCapacity:kQueueCapacity];
    isReady = YES;

    [_delegate propertyTreeClient:self didBindToHost:_socket.connectedHost onPort:_socket.connectedPort];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (sock != _socket) return;

    NSString *key = [queue firstObject]; [queue removeFirstObject];
    NSString *value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    switch ((ReceiveDataType) tag) {
        case ReceiveDataTypeString:
            [_delegate propertyTreeClient:self didReceiveStringValue:value forKey:key];
            break;
        case ReceiveDataTypeDouble:
            [_delegate propertyTreeClient:self didReceiveDoubleValue:value.doubleValue forKey:key];
            break;
        case ReceiveDataTypeLong:
            [_delegate propertyTreeClient:self didReceiveLongValue:value.longLongValue forKey:key]; // no "longValue" exists
            break;
        case ReceiveDataTypeInt:
            [_delegate propertyTreeClient:self didReceiveIntValue:value.intValue forKey:key];
            break;
        case ReceiveDataTypeBool:
            [_delegate propertyTreeClient:self didReceiveBoolValue:value.boolValue forKey:key];
            break;
    }
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    if (sock != _socket) return 0;
    [_delegate propertyTreeClientDidTimeout:self];
    return 0;
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    if (sock != _socket) return 0;
    [_delegate propertyTreeClientDidTimeout:self];
    return 0;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    [_delegate propertyTreeClientDidDisconnect:self];
    if (sock != _socket) return;
    [self unbind];
}

@end
