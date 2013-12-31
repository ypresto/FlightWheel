//
//  FGFSPropertyTreeClientTests.m
//  FlightWheel
//
//  Created by ypresto on 2013/10/26.
//  Copyright (c) 2013年 Yuya Tanaka. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FGFSPropertyTreeClient.h"
#import "OCMock.h"

@interface FGFSPropertyTreeClientTests : XCTestCase

@end

@implementation FGFSPropertyTreeClientTests {
    FGFSPropertyTreeClient *client;
}

- (void)setUp {
    [super setUp];
    client = [[FGFSPropertyTreeClient alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

- (id)setupRequestValueForKeySocketMockWithKey:(NSString *)key typePrefix:(long)typePrefix {
    id socketMock = [OCMockObject mockForClass:[GCDAsyncSocket class]];

    [[socketMock expect] writeData:[[NSString stringWithFormat:@"get %@\r\n", key] dataUsingEncoding:NSUTF8StringEncoding] withTimeout:3.0f tag:0];

    [[socketMock expect] readDataToData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:3.0f maxLength:102400 tag:typePrefix];

    return socketMock;
}

- (void)testRequestStringValueForKey {
    NSString *key = @"/sim/presets/airport-id";
    NSString *value = @"KBUR";
    char typePrefix = 'S';

    id socketMock = [self setupRequestValueForKeySocketMockWithKey:key typePrefix:typePrefix];
    client.socket = socketMock;
    id delegateMock = [OCMockObject mockForProtocol:@protocol(FGFSPropertyTreeClientDelegate)];
    [[delegateMock expect] propertyTreeClient:client didReceiveStringValue:value forKey:key];
    client.delegate = delegateMock;

    [client requestStringValueForKey:key];

    [client socket:socketMock didReadData:[value dataUsingEncoding:NSUTF8StringEncoding] withTag:typePrefix];

    [socketMock verify];
    [delegateMock verify];
}

- (void)testRequestDoubleValueForKey {
    NSString *key = @"/position/longitude-deg";
    double value = 12.3456;
    char typePrefix = 'D';

    id socketMock = [self setupRequestValueForKeySocketMockWithKey:key typePrefix:typePrefix];
    client.socket = socketMock;
    id delegateMock = [OCMockObject mockForProtocol:@protocol(FGFSPropertyTreeClientDelegate)];
    [[delegateMock expect] propertyTreeClient:client didReceiveDoubleValue:value forKey:key];
    client.delegate = delegateMock;

    [client requestDoubleValueForKey:key];

    [client socket:socketMock didReadData:[[NSString stringWithFormat:@"%f", value] dataUsingEncoding:NSUTF8StringEncoding] withTag:typePrefix];

    [socketMock verify];
    [delegateMock verify];
}

- (void)testRequestLongValueForKey {
    NSString *key = @"/long-value-test";
    long value = LONG_MAX;
    char typePrefix = 'L';

    id socketMock = [self setupRequestValueForKeySocketMockWithKey:key typePrefix:typePrefix];
    client.socket = socketMock;
    id delegateMock = [OCMockObject mockForProtocol:@protocol(FGFSPropertyTreeClientDelegate)];
    [[delegateMock expect] propertyTreeClient:client didReceiveLongValue:value forKey:key];
    client.delegate = delegateMock;

    [client requestLongValueForKey:key];

    [client socket:socketMock didReadData:[[NSString stringWithFormat:@"%ld", value] dataUsingEncoding:NSUTF8StringEncoding] withTag:typePrefix];

    [socketMock verify];
    [delegateMock verify];
}

- (void)testRequestIntValueForKey {
    NSString *key = @"/controls/engines/engine/magneto";
    int value = 123;
    char typePrefix = 'I';

    id socketMock = [self setupRequestValueForKeySocketMockWithKey:key typePrefix:typePrefix];
    client.socket = socketMock;
    id delegateMock = [OCMockObject mockForProtocol:@protocol(FGFSPropertyTreeClientDelegate)];
    [[delegateMock expect] propertyTreeClient:client didReceiveIntValue:value forKey:key];
    client.delegate = delegateMock;

    [client requestIntValueForKey:key];

    [client socket:socketMock didReadData:[[NSString stringWithFormat:@"%d", value] dataUsingEncoding:NSUTF8StringEncoding] withTag:typePrefix];

    [socketMock verify];
    [delegateMock verify];
}

- (void)testRequestBoolValueForKey {
    NSString *key = @"/bool-value-test";
    BOOL value = YES;
    char typePrefix = 'B';

    id socketMock = [self setupRequestValueForKeySocketMockWithKey:key typePrefix:typePrefix];
    client.socket = socketMock;
    id delegateMock = [OCMockObject mockForProtocol:@protocol(FGFSPropertyTreeClientDelegate)];
    [[delegateMock expect] propertyTreeClient:client didReceiveBoolValue:value forKey:key];
    client.delegate = delegateMock;

    [client requestBoolValueForKey:key];

    [client socket:socketMock didReadData:[@"true" dataUsingEncoding:NSUTF8StringEncoding] withTag:typePrefix];

    [socketMock verify];
    [delegateMock verify];
}

- (void)testWriteStringValueForKey {
    NSString *key = @"/sim/presets/airport-id";
    NSString *value = @"KBUR";

    id socketMock = [OCMockObject mockForClass:[GCDAsyncSocket class]];
    [[socketMock expect] writeData:[[NSString stringWithFormat:@"set %@ %@\r\n", key, value] dataUsingEncoding:NSUTF8StringEncoding] withTimeout:3.0f tag:0];
    client.socket = socketMock;

    [client writeStringValue:value forKey:key];

    [socketMock verify];
}

@end
