//
//  scanViewController.m
//  iOSPeripheralBTConnectivity
//
//  Created by Christos Christodoulou on 10/10/2017.
//  Copyright © 2017 Christos Christodoulou. All rights reserved.
//

#import "scanViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <CocoaLumberjack/CocoaLumberjack.h>
#import "DDLog.h"
#import "DDFileLogger.h"
#import "CocoaLumberjack.h"
#import <MessageUI/MessageUI.h>

static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

@interface scanViewController () <CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource>
{
    
}

@property (strong,nonatomic) CBCentralManager *manager;
@property (strong,nonatomic) CBPeripheral *p;
@property (strong,nonatomic) CBPeripheral *connectedPeripheral;
@property (strong,nonatomic) NSMutableDictionary *discoveredPeripherals;
@property (strong,nonatomic) NSMutableArray *devices;
@property (retain, nonatomic) NSTimer *restartTimer;

@property (weak, nonatomic) IBOutlet UIButton *scanButton;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIButton *disconnectButton;
@property (weak, nonatomic) IBOutlet UILabel *currentStateLabel;
@property (weak, nonatomic) IBOutlet UILabel *sensorDataLabel;

@end

@implementation scanViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.8];;//[UIColor lightGrayColor];
    self.tableView.backgroundColor = [UIColor colorWithRed:8.0 / 255.0 green:37.0 / 255.0 blue:43.0 / 255.0 alpha:1];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.disconnectButton.enabled = NO;
    self.disconnectButton.tintColor = [UIColor lightGrayColor];
    self.currentStateLabel.text = @"";
}


- (IBAction)scanPressed:(id)sender {
    NSLog(@"scanPressed  init CentralManager");
    [self.devices removeAllObjects];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.sensorDataLabel.text = @"";
    });
    self.devices = [[NSMutableArray alloc]init];
    self.discoveredPeripherals = [[NSMutableDictionary alloc] init];
    self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
}
- (IBAction)disconnectPressed:(id)sender {
    NSLog(@"disconnectPressed cancelPeripheralConnection");
    [self.manager cancelPeripheralConnection:self.connectedPeripheral];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.disconnectButton.backgroundColor = [UIColor clearColor];
        self.disconnectButton.tintColor = [UIColor lightGrayColor];
        self.disconnectButton.enabled = NO;
        self.sensorDataLabel.text = @"";
        [self.tableView reloadData];
    });
}

- (IBAction)emailPressed:(id)sender {
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
        mailViewController.mailComposeDelegate = self;
        NSMutableData *errorLogData = [NSMutableData data];
        for (NSData *errorLogFileData in [self errorLogData]) {
            [errorLogData appendData:errorLogFileData];
        }
        [mailViewController addAttachmentData:errorLogData mimeType:@"text/plain" fileName:@"sampleAltimeterData.log"];
        [mailViewController setSubject:NSLocalizedString(@"Sample Altimeter Data", @"")];
        NSArray *toRecipientsNames = [NSArray arrayWithObjects:@"gpolitis@kyontracker.com",@"gmavropoulos@kyontracker.com",@"cchristodoulou@kyontracker.com", @"kfrantzeskakis@kyontracker.com",nil];
        [mailViewController setToRecipients:toRecipientsNames];
        
        [self presentViewController:mailViewController animated:YES completion:nil];
        
    } else {
        NSString *message = NSLocalizedString(@"Sorry, your issue can't be reported right now. This is most likely because no mail accounts are set up on your mobile device.", @"");
        [[[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles: nil] show];
    }
}

#pragma mark - Email Related
- (void)mailComposeController:(MFMailComposeViewController *)mailer didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self becomeFirstResponder];
    [mailer dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - log method
- (NSMutableArray *)errorLogData {
    DDFileLogger *ddFileLogger = [DDFileLogger new];
    NSArray <NSString *> *logFilePaths = [ddFileLogger.logFileManager sortedLogFilePaths];
    NSMutableArray <NSData *> *logFileDataArray = [NSMutableArray new];
    for (NSString* logFilePath in logFilePaths) {
        NSURL *fileUrl = [NSURL fileURLWithPath:logFilePath];
        NSData *logFileData = [NSData dataWithContentsOfURL:fileUrl options:NSDataReadingMappedIfSafe error:nil];
        if (logFileData) {
            [logFileDataArray insertObject:logFileData atIndex:0];
        }
    }
    return logFileDataArray;
}


#pragma mark - CBCentralManagerDelegate Callbacks

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOff) {
        NSLog(@"CBCentralManager not powered on yet");
      
        [self.manager cancelPeripheralConnection:self.connectedPeripheral];
        self.manager = nil;
        return;
    }
    
    if (central.state == CBManagerStateUnauthorized) {
        NSLog(@"CBCentralManager CBManagerStateUnauthorized");
        [self.manager cancelPeripheralConnection:self.connectedPeripheral];
        self.manager = nil;
        
    }
    
    if (central.state == CBManagerStateUnknown) {
        NSLog(@"CBCentralManager CBManagerStateUnknown");
        [self.manager cancelPeripheralConnection:self.connectedPeripheral];
        self.manager = nil;
    }
    
    if (central.state == CBManagerStateUnsupported) {
        NSLog(@"CBCentralManager CBManagerStateUnsupported");
        [self.manager cancelPeripheralConnection:self.connectedPeripheral];
        self.manager = nil;
    }
    
    if (central.state == CBManagerStatePoweredOn) {
        NSLog(@"CBCentralManager CBManagerStatePoweredOn");
        NSDictionary *xOptions = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber  numberWithBool:YES], CBCentralManagerScanOptionAllowDuplicatesKey, nil];
        [self.manager scanForPeripheralsWithServices:nil options:xOptions];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {

    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentStateLabel.text = @"Discovering Peripherals";
    });
    
    if ([self.devices containsObject:peripheral]) {
        NSLog(@"STEP: PERIPHERAL EXIST in DEVICES: %@", peripheral.name);
        return;
    }
    else {
        NSLog(@"STEP: PERIPHERAL ADDED in DEVICES: %@", peripheral.name);
        [self.devices addObject:peripheral];
        if ([peripheral.name isEqualToString: @"KYC:9C1D58154F80"]) {
            [self.manager connectPeripheral:peripheral options:nil];
            [self.manager stopScan];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"STEP: didConnectPeripheral: %@", peripheral.name);
    peripheral.delegate = self;
    self.connectedPeripheral = peripheral;
    [NSThread sleepForTimeInterval:4.0f];//Not sure if we need this one
    [self.connectedPeripheral discoverServices:@[[CBUUID UUIDWithString:@"A030"]]];//-- A030 NORMAL SERVICE

    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentStateLabel.text =  [NSString stringWithFormat:@"Connected to:  %@", peripheral.name];
        self.disconnectButton.enabled = YES;
        self.disconnectButton.backgroundColor = [UIColor redColor];
    });
}



- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"STEP: didDisconnectPeripheral: %@", peripheral.name);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentStateLabel.text =  [NSString stringWithFormat:@"Disconnected:  %@", peripheral.name];
    });
    //Start 1 min timer
    //Restart the scan after 1 minute
    self.restartTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:60.0]
                                                   interval:0
                                                     target:self
                                                   selector:@selector(restartScan:)
                                                   userInfo:nil
                                                    repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.restartTimer forMode:NSDefaultRunLoopMode];

}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"STEP: Got didFailToConnectPeripheral:  %@", peripheral.name);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentStateLabel.text =  [NSString stringWithFormat:@"Failed to:  %@", peripheral.name];
    });
}

#pragma mark - CBPeripheralDelegate Callbacks

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services)
    {
        if ([[service.UUID UUIDString] isEqualToString:@"A030"] ) //-- A030  NORMAL SERVICE
        {
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:@"A032"]] forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if ([[characteristic.UUID UUIDString] isEqualToString:@"A032"])//-- A032
        {
            [peripheral readValueForCharacteristic:characteristic];//request to read value from characteristic
            break;
        }
    }
}
             
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
                 
    UInt8 batteryPercentageAndchargingStatus;
    UInt8 temperature;
    UInt8 wet;
    UInt8 streched;
    UInt32 pressure;
    UInt32 lastMessagesUpdateTimeStamp;
    UInt32 FirmwarePIC24FJ;
    UInt32 FirmwareCC2540;
    BOOL isWet;
    BOOL charging;
    BOOL isStreched;
    
    if ([[characteristic.UUID UUIDString] isEqualToString:@"A032"]) {//-- Α032 OR not in validation process
                     
        NSData *rawData = characteristic.value;
        // Length Validation
        if (rawData.length != 19) {
            NSLog(@"INVALID RAW DATA LENGTH, DISCARD THIS READ");
            [self.manager cancelPeripheralConnection:peripheral];
            return;
        }
        
        //0 UInt8 Battery Percentage (State Of Charge) and Charging Status
        [[rawData subdataWithRange:NSMakeRange(0, 1)] getBytes:&batteryPercentageAndchargingStatus length:sizeof(batteryPercentageAndchargingStatus)];
        if (batteryPercentageAndchargingStatus > 128) {
            NSLog(@"Charging.....");
            batteryPercentageAndchargingStatus = batteryPercentageAndchargingStatus - 128;
            NSLog(@"%hhu",batteryPercentageAndchargingStatus);
            charging = YES;
        }else{
            NSLog(@"Not charging..... %hhu",batteryPercentageAndchargingStatus);
            charging = FALSE;
        }
        
        //1-3, Pressure
        [[rawData subdataWithRange:NSMakeRange(1, 3)] getBytes:&pressure length:sizeof(pressure)];
        pressure = CFSwapInt32HostToBig(pressure);
        pressure /= 256;
        pressure &= 0x00FFFFFF;
        NSLog(@"PRESSURE IS : %u",(unsigned int)pressure);
        NSLog(@"RAWDATA1 : %@",rawData);
        
        // 4, Temperature
        [[rawData subdataWithRange:NSMakeRange(4, 1)] getBytes:&temperature length:sizeof(temperature)];
        NSLog(@"TEMPERATURE IS %u",(unsigned int)temperature);
        NSLog(@"RAWDATA2 : %@",rawData);
        
        // 5, Wet (uint8). Values=1 if wet, otherwise 0.
        [[rawData subdataWithRange:NSMakeRange(0, 1)] getBytes:&wet length:sizeof(wet)];
        
        isWet = (wet == 1) ? TRUE : FALSE;
        NSLog(@"is Yet: %d",isWet);
        
        //6, Stretched (deformed) Collar (uint8). Values=1 if stretched, otherwise 0.
        [[rawData subdataWithRange:NSMakeRange(0, 1)] getBytes:&streched length:sizeof(streched)];
        isStreched = (streched == 1) ? TRUE : FALSE;
        NSLog(@"is Streched: %d",isStreched);
        
        //11-14 Last Messages Update Timestamp (uint32)
        [[rawData subdataWithRange:NSMakeRange(11, 4)] getBytes:&lastMessagesUpdateTimeStamp length:sizeof(lastMessagesUpdateTimeStamp)];
        NSLog(@"Last message update %u",(unsigned int)lastMessagesUpdateTimeStamp);
        
        if (lastMessagesUpdateTimeStamp == 4294967295) { // 0xFFFFFFFF = 4294967295
            lastMessagesUpdateTimeStamp = 0;
        }
        
        // 15-16, PIC24FJ Firmware Version
        [[rawData subdataWithRange:NSMakeRange(15, 2)] getBytes:&FirmwarePIC24FJ length:sizeof(FirmwarePIC24FJ)];
        FirmwarePIC24FJ = CFSwapInt32HostToBig(FirmwarePIC24FJ);
        NSLog(@"Swaaped FirmwarePIC24FJ %u",(unsigned int)FirmwarePIC24FJ);
        
        // 16-17, CC2540 Firmware Version
        [[rawData subdataWithRange:NSMakeRange(17, 2)] getBytes:&FirmwareCC2540 length:sizeof(FirmwareCC2540)];
        FirmwareCC2540 = CFSwapInt32HostToBig(FirmwareCC2540);
        NSLog(@"Swaaped FirmwareCC2540 %u",(unsigned int)FirmwareCC2540);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sensorDataLabel.text =  [NSString stringWithFormat:@"Pressure | %0.2f | Temp | %u | %@ |",(float)pressure/100, (unsigned int)temperature, rawData];
            DDLogInfo(@"Sensor %@", self.sensorDataLabel.text);
            
            NSLog(@"disconnect Automatically from read Sensors");
            [self.manager cancelPeripheralConnection:self.connectedPeripheral];
        });
        
    }
}

#pragma mark - TableView Datasource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.devices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"peripheralCell"];
    // Configure the cell...
    CBPeripheral *p = [self.devices objectAtIndex:indexPath.row];
    if (p.name == nil || [p.name isEqual: @""]) {
        cell.textLabel.text = @"uknown";
    }
    else {
        cell.textLabel.text = p.name;
    }
    cell.backgroundColor = [UIColor colorWithRed:8.0 / 255.0 green:37.0 / 255.0 blue:43.0 / 255.0 alpha:1];
    cell.textLabel.textColor = [UIColor whiteColor];
    return cell;
}

#pragma mark - TableView Delegates

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    self.p = [self.devices objectAtIndex:indexPath.row];
    [self.manager connectPeripheral:self.p options:nil];
    [self.manager stopScan];
}




#pragma mark - restartScan Timer
- (void)restartScan:(NSTimer *)timer
{
    NSLog(@"restartTimer reconnect");
    if (self.restartTimer) {
        [self.restartTimer invalidate];
        self.restartTimer = nil;
    }
    
    [self.manager connectPeripheral:self.connectedPeripheral options:nil];
    [self.tableView reloadData];
    
//    self.devices = nil;
//    NSDictionary *xOptions = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber  numberWithBool:YES], CBCentralManagerScanOptionAllowDuplicatesKey, nil];
//    [self.manager scanForPeripheralsWithServices:nil options:xOptions];
}
@end
