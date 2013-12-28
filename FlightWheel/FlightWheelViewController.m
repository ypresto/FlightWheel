//
//  FlightWheelViewController.m
//  FlightWheel
//
//  Created by ypresto on 13/10/20.
//  Copyright (c) 2013 Yuya Tanaka. All rights reserved.
//

#import "FlightWheelViewController.h"

#import "FGFSPropertyTreeClient.h"

@interface FlightWheelViewController () <FGFSPropertyTreeClientDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *hostText;
@property (weak, nonatomic) IBOutlet UISwitch *gearSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *brakeSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *parkingBrakeSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *reverserSwitch;
@property (weak, nonatomic) IBOutlet UISlider *throttleSlider;
@property (weak, nonatomic) IBOutlet UISlider *flapsSlider;
@property (weak, nonatomic) IBOutlet UIView *throttleSliderContainer;

@property (nonatomic) FGFSPropertyTreeClient *client;
@property (nonatomic, readonly) NSRegularExpression *regexForFlapsSettings;
@property (nonatomic) BOOL flapsSettingsRetrieved;
@property (nonatomic) BOOL flapsPositionRetrieved;

@end

@implementation FlightWheelViewController
{
    NSMutableDictionary *flapsSettings;
}

static const NSInteger kDefaultPort = 65535;
static NSString *const kTreeKeyForGear = @"/controls/gear/gear-down";
static NSString *const kTreeKeyForBrakeLeft = @"/controls/gear/brake-left";
static NSString *const kTreeKeyForBrakeRight = @"/controls/gear/brake-right";
static NSString *const kTreeKeyForBrakeParking = @"/controls/gear/brake-parking";
static NSString *const kTreeKeyForFirstThrottle = @"/controls/engines/engine/throttle";
static NSString *const kTreeKeyForFirstReverser = @"/controls/engines/engine/reverser";
static NSString *const kTreeKeyFormatForThrottle = @"/controls/engines/engine[%d]/throttle";
static NSString *const kTreeKeyFormatForReverser = @"/controls/engines/engine[%d]/reverser";
static NSString *const kTreeKeyForFlaps = @"/controls/flight/flaps";
static NSString *const kTreeKeyForCurrentFlapsPosition = @"/sim/flaps/current-setting";
static NSString *const kTreeKeyFormatForFlapsSettings = @"/sim/flaps/setting[%d]";
static NSString *const kTreeKeyPatternForFlapsSettings = @"/sim/flaps/setting\\[(\\d+)\\]";
static const NSInteger kNumberOfEngines = 4;
static const NSInteger kNumberOfFlapsPositions = 7;

- (void)viewDidLoad
{
    [super viewDidLoad];

    _client = [FGFSPropertyTreeClient new];
    _client.delegate = self;
    _hostText.delegate = self;

    _flapsSlider.maximumValue = kNumberOfFlapsPositions - 1;

    _throttleSliderContainer.transform = CGAffineTransformMakeRotation(-M_PI_2);
    _flapsSlider.transform = CGAffineTransformMakeRotation(M_PI);
}

- (void)requestFlapsSettings
{
    _flapsSlider.enabled = NO;
    flapsSettings = [NSMutableDictionary dictionaryWithCapacity:kNumberOfFlapsPositions];
    for (int i = 0; i < kNumberOfFlapsPositions; i++) {
        [_client requestDoubleValueForKey:[NSString stringWithFormat:kTreeKeyFormatForFlapsSettings, i]];
    }
}

- (void)requestInitialValues
{
    _gearSwitch.enabled = NO;
    _brakeSwitch.enabled = NO;
    _parkingBrakeSwitch.enabled = NO;
    _throttleSlider.enabled = NO;
    _reverserSwitch.enabled = NO;
    _flapsSlider.enabled = NO;
    [_client requestBoolValueForKey:kTreeKeyForGear];
    [_client requestBoolValueForKey:kTreeKeyForBrakeLeft];
    [_client requestBoolValueForKey:kTreeKeyForBrakeParking];
    [_client requestDoubleValueForKey:kTreeKeyForFirstThrottle];
    [_client requestBoolValueForKey:kTreeKeyForFirstReverser];
    [_client requestIntValueForKey:kTreeKeyForCurrentFlapsPosition];
}

- (void)updateFlapsSliderEnabled
{
    _flapsSlider.enabled = _flapsPositionRetrieved && _flapsSettingsRetrieved;
}

#pragma mark Custom getter/setter

- (NSRegularExpression *)regexForFlapsSettings
{
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:kTreeKeyPatternForFlapsSettings options:0 error:&error];
    assert(!error);
    return regex;
}

- (void)setFlapsSettingsRetrieved:(BOOL)flapsSettingsRetrieved
{
    _flapsSettingsRetrieved = flapsSettingsRetrieved;
    [self updateFlapsSliderEnabled];
}

- (void)setFlapsPositionRetrieved:(BOOL)flapsPositionRetrieved
{
    _flapsPositionRetrieved = flapsPositionRetrieved;
    [self updateFlapsSliderEnabled];
}

#pragma mark IBAction

- (IBAction)throttleChanged:(UISlider *)sender {
    for (int i = 0; i < kNumberOfEngines; i++) {
        [_client writeDoubleValue:sender.value forKey:[NSString stringWithFormat:kTreeKeyFormatForThrottle, i]];
    }
}

- (IBAction)reverserChanged:(UISwitch *)sender {
    for (int i = 0; i < kNumberOfEngines; i++) {
        [_client writeBoolValue:sender.isOn forKey:[NSString stringWithFormat:kTreeKeyFormatForReverser, i]];
    }
}

- (IBAction)flapsChanged:(UISlider *)sender {
    int flapsPosition = roundf(sender.value);
    sender.value = flapsPosition;
    double flapsSetting = [[flapsSettings objectForKey:[NSNumber numberWithInt:flapsPosition]] doubleValue];
    [_client writeDoubleValue:flapsSetting forKey:kTreeKeyForFlaps];
    [_client writeIntValue:flapsPosition forKey:kTreeKeyForCurrentFlapsPosition];
}

- (IBAction)gearChanged:(UISwitch *)sender {
    [_client writeBoolValue:sender.isOn forKey:kTreeKeyForGear];
}

- (IBAction)brakeChanged:(UISwitch *)sender {
    [_client writeBoolValue:sender.isOn forKey:kTreeKeyForBrakeLeft];
    [_client writeBoolValue:sender.isOn forKey:kTreeKeyForBrakeRight];
}

- (IBAction)parkingBrakeChanged:(UISwitch *)sender {
    [_client writeBoolValue:sender.isOn forKey:kTreeKeyForBrakeParking];
}

#pragma mark UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField != _hostText) return NO;

    NSString *hostAndPort = _hostText.text;
    NSArray *components = [hostAndPort componentsSeparatedByString:@":"];
    if (components.count > 2) return NO;

    NSString *host = components[0];
    if (host.length == 0) return NO;
    NSInteger port = components.count == 2 ? [components[1] intValue] : kDefaultPort;

    [textField resignFirstResponder];
    [_client bindToHost:host onPort:port];
    return YES;
}

#pragma mark FGFSPropertyTreeClientDelegate methods

- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didBindToHost:(NSString *)host onPort:(uint16_t)port
{
    NSLog(@"Connected to %@:%d.", host, port);
    [self requestFlapsSettings];
    [self requestInitialValues];
}

- (void)propertyTreeClientDidDisconnect:(FGFSPropertyTreeClient *)client
{
    NSLog(@"Disconnected.");
}

- (void)propertyTreeClientDidTimeout:(FGFSPropertyTreeClient *)client
{
    NSLog(@"Timeout occured.");
}

- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didReceiveStringValue:(NSString *)stringValue forKey:(NSString *)key
{
    NSLog(@"Missing handler for property tree string value of key: %@", key);
}

- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didReceiveDoubleValue:(double)doubleValue forKey:(NSString *)key
{
    NSTextCheckingResult *match = [self.regexForFlapsSettings firstMatchInString:key options:0 range:NSMakeRange(0, key.length)];
    if (match.numberOfRanges > 1) {
        int index = [[key substringWithRange:[match rangeAtIndex:1]] intValue];
        [flapsSettings setObject:[NSNumber numberWithDouble:doubleValue] forKey:[NSNumber numberWithInt:index]];
        if (flapsSettings.count == kNumberOfFlapsPositions) {
            self.flapsSettingsRetrieved = YES;
        }
    } else if ([key isEqualToString:kTreeKeyForFirstThrottle]) {
        [_throttleSlider setValue:doubleValue animated:YES];
        _throttleSlider.enabled = YES;
    } else {
        NSLog(@"Missing handler for property tree double value of key: %@", key);
    }
}

- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didReceiveLongValue:(long)longValue forKey:(NSString *)key
{
    NSLog(@"Missing handler for property tree long value of key: %@", key);
}

- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didReceiveIntValue:(int)intValue forKey:(NSString *)key
{
    if ([key isEqualToString:kTreeKeyForCurrentFlapsPosition]) {
        _flapsSlider.value = intValue;
        self.flapsPositionRetrieved = YES;
    } else {
        NSLog(@"Missing handler for property tree int value of key: %@", key);
    }
}

- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didReceiveBoolValue:(BOOL)boolValue forKey:(NSString *)key
{
    if ([key isEqualToString:kTreeKeyForGear]) {
        [_gearSwitch setOn:boolValue animated:YES];
        _gearSwitch.enabled = YES;
    } else if ([key isEqualToString:kTreeKeyForBrakeLeft]) {
        [_brakeSwitch setOn:boolValue animated:YES];
        _brakeSwitch.enabled = YES;
    } else if ([key isEqualToString:kTreeKeyForBrakeParking]) {
        [_parkingBrakeSwitch setOn:boolValue animated:YES];
        _parkingBrakeSwitch.enabled = YES;
    } else if ([key isEqualToString:kTreeKeyForFirstReverser]) {
        [_reverserSwitch setOn:boolValue animated:YES];
        _reverserSwitch.enabled = YES;
    } else {
        NSLog(@"Missing handler for property tree bool value of key: %@", key);
    }
}

@end
