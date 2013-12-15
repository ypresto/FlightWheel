//
//  FGFSConnection.h
//  FlightWheel
//
//  Created by ypresto on 13/10/21.
//  Copyright (c) 2013年 Yuya Tanaka. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GCDAsyncSocket.h>

@class FGFSPropertyTreeClient;

@protocol FGFSPropertyTreeClientDelegate

- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didBindToHost:(NSString *)host onPort:(uint16_t)port;
- (void)propertyTreeClientDidTimeout:(FGFSPropertyTreeClient *)client;
- (void)propertyTreeClientDidDisconnect:(FGFSPropertyTreeClient *)client;

@optional

- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didReceiveStringValue:(NSString *)stringValue forKey:(NSString *)key;
- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didReceiveDoubleValue:(double)doubleValue forKey:(NSString *)key;
- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didReceiveLongValue:(long)longValue forKey:(NSString *)key;
- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didReceiveIntValue:(int)intValue forKey:(NSString *)key;
- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didReceiveBoolValue:(BOOL)boolValue forKey:(NSString *)key;

@end

@interface FGFSPropertyTreeClient : NSObject <GCDAsyncSocketDelegate>

@property (nonatomic, weak) id<FGFSPropertyTreeClientDelegate> delegate;
@property (nonatomic, retain) GCDAsyncSocket *socket;

- (void)bindToHost:(NSString *)host onPort:(uint16_t)port;
- (void)unbind;
- (void)requestStringValueForKey:(NSString *)key;
- (void)requestDoubleValueForKey:(NSString *)key;
- (void)requestLongValueForKey:(NSString *)key;
- (void)requestIntValueForKey:(NSString *)key;
- (void)requestBoolValueForKey:(NSString *)key;
- (void)writeStringValue:(NSString *)stringValue forKey:(NSString *)key;
- (void)writeDoubleValue:(double)doubleValue forKey:(NSString *)key;
- (void)writeLongValue:(long)longValue forKey:(NSString *)key;
- (void)writeIntValue:(int)intValue forKey:(NSString *)key;
- (void)writeBoolValue:(BOOL)boolValue forKey:(NSString *)key;

@end
