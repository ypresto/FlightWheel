//
//  FlightWheelViewController.m
//  FlightWheel
//
//  Created by ypresto on 13/10/20.
//  Copyright (c) 2013 Yuya Tanaka. All rights reserved.
//

#import "FlightWheelViewController.h"

#import "FGFSPropertyTreeClient.h"
#import <CoreMotion/CoreMotion.h>

static const NSInteger kDefaultPort = 65535;
static const NSInteger kNumberOfEngines = 4;
static const NSInteger kNumberOfFlapsPositions = 7;
static const NSInteger kMotionFrequencyHz = 20;
static NSString *const kTreeKeyForGear = @"/controls/gear/gear-down";
static NSString *const kTreeKeyForBrakeLeft = @"/controls/gear/brake-left";
static NSString *const kTreeKeyForBrakeRight = @"/controls/gear/brake-right";
static NSString *const kTreeKeyForBrakeParking = @"/controls/gear/brake-parking";
static NSString *const kTreeKeyForFirstThrottle = @"/controls/engines/engine/throttle";
static NSString *const kTreeKeyForFirstReverser = @"/controls/engines/engine/reverser";
static NSString *const kTreeKeyFormatForThrottle = @"/controls/engines/engine[%d]/throttle";
static NSString *const kTreeKeyFormatForReverser = @"/controls/engines/engine[%d]/reverser";
static NSString *const kTreeKeyForAileron = @"/controls/flight/aileron";
static NSString *const kTreeKeyForElevator = @"/controls/flight/elevator";
static NSString *const kTreeKeyForRudder = @"/controls/flight/rudder";
static NSString *const kTreeKeyForFlaps = @"/controls/flight/flaps";
static NSString *const kTreeKeyForCurrentFlapsPosition = @"/sim/flaps/current-setting";
static NSString *const kTreeKeyFormatForFlapsSettings = @"/sim/flaps/setting[%d]";
static NSString *const kTreeKeyPatternForFlapsSettings = @"/sim/flaps/setting\\[(\\d+)\\]";

@interface FlightWheelViewController () <FGFSPropertyTreeClientDelegate, UITextFieldDelegate, UIAccelerometerDelegate>

@property (nonatomic) BOOL flapsSettingsRetrieved;
@property (nonatomic) BOOL flapsPositionRetrieved;

@end

@implementation FlightWheelViewController
{
    __weak IBOutlet UITextField *hostText;
    __weak IBOutlet UISwitch *gearSwitch;
    __weak IBOutlet UISwitch *brakeSwitch;
    __weak IBOutlet UISwitch *parkingBrakeSwitch;
    __weak IBOutlet UISwitch *reverserSwitch;
    __weak IBOutlet UISlider *throttleSlider;
    __weak IBOutlet UISlider *flapsSlider;
    __weak IBOutlet UIView *throttleSliderContainer;
    __weak IBOutlet UIProgressView *elevatorMeter;
    __weak IBOutlet UIProgressView *alieronMeter;
    __weak IBOutlet UIProgressView *rudderMeter;

    FGFSPropertyTreeClient *client;
    NSMutableDictionary *flapsSettings;
    CMMotionManager *motionManager;
    double rollCalibrate;
    double pitchCalibrate;
    double yawCalibrate;
    float elevatorSensitivity;
    float alieronSensitivity;
    float rudderSensitivity;
}

static NSRegularExpression *regexForFlapsSettings;

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupRegexForFlapsSettings];
    elevatorSensitivity = 2.0f;
    alieronSensitivity = 1.0f;
    rudderSensitivity = 1.0f;

    client = [FGFSPropertyTreeClient new];
    client.delegate = self;
    hostText.delegate = self;

    flapsSlider.maximumValue = kNumberOfFlapsPositions - 1;

    throttleSliderContainer.transform = CGAffineTransformMakeRotation(-M_PI_2);
    flapsSlider.transform = CGAffineTransformMakeRotation(M_PI);

    motionManager = [CMMotionManager new];
    motionManager.deviceMotionUpdateInterval = 1.0f / kMotionFrequencyHz;
    motionManager.showsDeviceMovementDisplay = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopMotionUpdate) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startMotionUpdate) name:UIApplicationWillEnterForegroundNotification object:nil];
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground) {
        [self startMotionUpdate];
    }
}

- (void)setupRegexForFlapsSettings
{
    if (regexForFlapsSettings) return;
    NSError *error;
    regexForFlapsSettings = [NSRegularExpression regularExpressionWithPattern:kTreeKeyPatternForFlapsSettings options:0 error:&error];
    assert(!error);
}

- (void)startMotionUpdate
{
    [motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical toQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
        if (error) {
            NSLog(@"Error in motion handler, domain: %@, code: %ld", error.domain, (long)error.code);
            return;
        }

        double elevator = -(motion.attitude.roll - rollCalibrate) / M_PI;
        if (elevator > 1.0) elevator -=2.0; else if (elevator < -1.0) elevator += 2.0;
        elevator = MAX(MIN(elevator * elevatorSensitivity, 1.0), -1.0);
        double alieron = -(motion.attitude.pitch - pitchCalibrate) / M_PI_2;
        if (alieron > 1.0) alieron -=2.0; else if (alieron < -1.0) alieron += 2.0;
        alieron = MAX(MIN(alieron * alieronSensitivity, 1.0), -1.0);
        double rudder = -(motion.attitude.yaw - yawCalibrate) / M_PI_2;
        if (rudder > 1.0) rudder -=2.0; else if (rudder < -1.0) rudder += 2.0;
        rudder = MAX(MIN(rudder * rudderSensitivity, 1.0), -1.0);
        elevatorMeter.progress = (elevator + 1.0) / 2.0;
        alieronMeter.progress = (alieron + 1.0) / 2.0;
        rudderMeter.progress = (rudder + 1.0) / 2.0;
        [client writeDoubleValue:elevator forKey:kTreeKeyForElevator];
        [client writeDoubleValue:alieron forKey:kTreeKeyForAileron];
        [client writeDoubleValue:rudder forKey:kTreeKeyForRudder];
    }];
}

- (void)stopMotionUpdate
{
    [motionManager stopDeviceMotionUpdates];
}

- (void)requestFlapsSettings
{
    flapsSlider.enabled = NO;
    flapsSettings = [NSMutableDictionary dictionaryWithCapacity:kNumberOfFlapsPositions];
    for (int i = 0; i < kNumberOfFlapsPositions; i++) {
        [client requestDoubleValueForKey:[NSString stringWithFormat:kTreeKeyFormatForFlapsSettings, i]];
    }
}

- (void)requestInitialValues
{
    gearSwitch.enabled = NO;
    brakeSwitch.enabled = NO;
    parkingBrakeSwitch.enabled = NO;
    throttleSlider.enabled = NO;
    reverserSwitch.enabled = NO;
    flapsSlider.enabled = NO;
    [client requestBoolValueForKey:kTreeKeyForGear];
    [client requestBoolValueForKey:kTreeKeyForBrakeLeft];
    [client requestBoolValueForKey:kTreeKeyForBrakeParking];
    [client requestDoubleValueForKey:kTreeKeyForFirstThrottle];
    [client requestBoolValueForKey:kTreeKeyForFirstReverser];
    [client requestIntValueForKey:kTreeKeyForCurrentFlapsPosition];
}

- (void)updateFlapsSliderEnabled
{
    flapsSlider.enabled = _flapsPositionRetrieved && _flapsSettingsRetrieved;
}

#pragma mark Custom getter/setter

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

- (IBAction)calibrateTapped:(UIButton *)sender {
    CMDeviceMotion *motion = motionManager.deviceMotion;
    rollCalibrate = motion.attitude.roll;
    pitchCalibrate = motion.attitude.pitch;
    yawCalibrate = motion.attitude.yaw;
}

- (IBAction)throttleChanged:(UISlider *)sender {
    for (int i = 0; i < kNumberOfEngines; i++) {
        [client writeDoubleValue:sender.value forKey:[NSString stringWithFormat:kTreeKeyFormatForThrottle, i]];
    }
}

- (IBAction)reverserChanged:(UISwitch *)sender {
    for (int i = 0; i < kNumberOfEngines; i++) {
        [client writeBoolValue:sender.isOn forKey:[NSString stringWithFormat:kTreeKeyFormatForReverser, i]];
    }
}

- (IBAction)flapsChanged:(UISlider *)sender {
    int flapsPosition = roundf(sender.value);
    sender.value = flapsPosition;
    double flapsSetting = [[flapsSettings objectForKey:[NSNumber numberWithInt:flapsPosition]] doubleValue];
    [client writeDoubleValue:flapsSetting forKey:kTreeKeyForFlaps];
    [client writeIntValue:flapsPosition forKey:kTreeKeyForCurrentFlapsPosition];
}

- (IBAction)gearChanged:(UISwitch *)sender {
    [client writeBoolValue:sender.isOn forKey:kTreeKeyForGear];
}

- (IBAction)brakeChanged:(UISwitch *)sender {
    [client writeBoolValue:sender.isOn forKey:kTreeKeyForBrakeLeft];
    [client writeBoolValue:sender.isOn forKey:kTreeKeyForBrakeRight];
}

- (IBAction)parkingBrakeChanged:(UISwitch *)sender {
    [client writeBoolValue:sender.isOn forKey:kTreeKeyForBrakeParking];
}

#pragma mark UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField != hostText) return NO;

    NSString *hostAndPort = hostText.text;
    NSArray *components = [hostAndPort componentsSeparatedByString:@":"];
    if (components.count > 2) return NO;

    NSString *host = components[0];
    if (host.length == 0) return NO;
    NSInteger port = components.count == 2 ? [components[1] intValue] : kDefaultPort;

    [textField resignFirstResponder];
    [client bindToHost:host onPort:port];
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
    NSTextCheckingResult *match = [regexForFlapsSettings firstMatchInString:key options:0 range:NSMakeRange(0, key.length)];
    if (match.numberOfRanges > 1) {
        int index = [[key substringWithRange:[match rangeAtIndex:1]] intValue];
        [flapsSettings setObject:[NSNumber numberWithDouble:doubleValue] forKey:[NSNumber numberWithInt:index]];
        if (flapsSettings.count == kNumberOfFlapsPositions) {
            self.flapsSettingsRetrieved = YES;
        }
    } else if ([key isEqualToString:kTreeKeyForFirstThrottle]) {
        [throttleSlider setValue:doubleValue animated:YES];
        throttleSlider.enabled = YES;
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
        flapsSlider.value = intValue;
        self.flapsPositionRetrieved = YES;
    } else {
        NSLog(@"Missing handler for property tree int value of key: %@", key);
    }
}

- (void)propertyTreeClient:(FGFSPropertyTreeClient *)client didReceiveBoolValue:(BOOL)boolValue forKey:(NSString *)key
{
    if ([key isEqualToString:kTreeKeyForGear]) {
        [gearSwitch setOn:boolValue animated:YES];
        gearSwitch.enabled = YES;
    } else if ([key isEqualToString:kTreeKeyForBrakeLeft]) {
        [brakeSwitch setOn:boolValue animated:YES];
        brakeSwitch.enabled = YES;
    } else if ([key isEqualToString:kTreeKeyForBrakeParking]) {
        [parkingBrakeSwitch setOn:boolValue animated:YES];
        parkingBrakeSwitch.enabled = YES;
    } else if ([key isEqualToString:kTreeKeyForFirstReverser]) {
        [reverserSwitch setOn:boolValue animated:YES];
        reverserSwitch.enabled = YES;
    } else {
        NSLog(@"Missing handler for property tree bool value of key: %@", key);
    }
}

@end
