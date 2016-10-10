#import "CsZBar.h"
#import <AVFoundation/AVFoundation.h>
#import "AlmaZBarReaderViewController.h"

#pragma mark - State

@interface CsZBar ()
@property bool scanInProgress;
@property NSString *scanCallbackId;
@property AlmaZBarReaderViewController *scanReader;

@end

#pragma mark - Synthesize

@implementation CsZBar

@synthesize scanInProgress;
@synthesize scanCallbackId;
@synthesize scanReader;

#pragma mark - Cordova Plugin

- (void)pluginInitialize {
    self.scanInProgress = NO;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    return;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES; //(interfaceOrientation == UIInterfaceOrientationPortrait);
}
/*
- (void)viewDidLoad {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:@"Turn on Flash" forState:UIControlStateNormal];
    [button sizeToFit];
    // Set a new (x,y) point for the button's center
    button.center = CGPointMake(320/2, 60);
    [button addTarget:self action:@selector(flashOn) forControlEvents:UIControlEventTouchUpInside];
    [self.viewController parentViewController:button];
}*/

#pragma mark - Plugin API

- (void)scan: (CDVInvokedUrlCommand*)command; 
{
    if (self.scanInProgress) {
        [self.commandDelegate
         sendPluginResult: [CDVPluginResult
                            resultWithStatus: CDVCommandStatus_ERROR
                            messageAsString:@"A scan is already in progress."]
         callbackId: [command callbackId]];
    } else {
        self.scanInProgress = YES;
        self.scanCallbackId = [command callbackId];
        self.scanReader = [AlmaZBarReaderViewController new];

        self.scanReader.readerDelegate = self;
        self.scanReader.supportedOrientationsMask = ZBarOrientationMask(UIInterfaceOrientationPortrait);

        // Get user parameters
        NSDictionary *params = (NSDictionary*) [command argumentAtIndex:0];
        NSString *camera = [params objectForKey:@"camera"];
        if([camera isEqualToString:@"front"]) {
            // We do not set any specific device for the default "back" setting,
            // as not all devices will have a rear-facing camera.
            self.scanReader.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }
        self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;

        NSString *flash = [params objectForKey:@"flash"];
        
        if ([flash isEqualToString:@"on"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        } else if ([flash isEqualToString:@"off"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        }else if ([flash isEqualToString:@"auto"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
        }

        // Hack to hide the bottom bar's Info button... originally based on http://stackoverflow.com/a/16353530
	NSInteger infoButtonIndex;
        if ([[[UIDevice currentDevice] systemVersion] compare:@"10.0" options:NSNumericSearch] != NSOrderedAscending) {
            infoButtonIndex = 1;
        } else {
            infoButtonIndex = 3;
        }
        UIView *infoButton = [[[[[self.scanReader.view.subviews objectAtIndex:2] subviews] objectAtIndex:0] subviews] objectAtIndex:infoButtonIndex];
        [infoButton setHidden:YES];
        // Add an action in current code file (i.e. target)
      //  [infoButton addTarget: action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];

        //UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem]; [button setTitle:@"Press Me" forState:UIControlStateNormal]; [button sizeToFit]; [self.view addSubview:button];

        BOOL drawSight = [params objectForKey:@"drawSight"] ? [[params objectForKey:@"drawSight"] boolValue] : true;
        if(drawSight){
            CGRect screenRect = [[UIScreen mainScreen] bounds];
            CGFloat screenWidth = screenRect.size.width;
            CGFloat screenHeight = screenRect.size.height;
            CGFloat dim = screenWidth < screenHeight ? screenWidth / 1.1 : screenHeight / 1.1;
//            UIView *polygonView = [[UIView alloc] initWithFrame: CGRectMake  ( (screenWidth/2) - (dim/2), (screenHeight/2) - (dim/2), dim, dim)];
           UIView *polygonView = [[UIView alloc] initWithFrame: CGRectMake ( (screenWidth/2) - (dim/2), (screenHeight/2) - (dim/2), dim, dim)]; 
            //polygonView.center = self.scanReader.view.center;
            //polygonView.layer.borderColor = [UIColor greenColor].CGColor;
            //polygonView.layer.borderWidth = 3.0f;

 //          UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(0,dim / 2, dim, 1)];
			UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(dim / 2, 0, 1, dim)];
            lineView.backgroundColor = [UIColor redColor];
            [polygonView addSubview:lineView];

	
//            self.scanReader.scanCrop = CGRectMake  ( 0.54, 0, 0.005, 1);
            self.scanReader.cameraOverlayView = polygonView;
            //[self.scanReader.view addSubview:polygonView];
        } 

        // Force only QR codes:
        [self.scanReader.scanner setSymbology: 0 config: ZBAR_CFG_ENABLE to: 0];
        [self.scanReader.scanner setSymbology: ZBAR_QRCODE config: ZBAR_CFG_ENABLE to: 1];
		// need this to make the little Filament codes work well
        [self.scanReader.scanner setSymbology: 0 config: ZBAR_CFG_X_DENSITY to: 1];
        [self.scanReader.scanner setSymbology: 0 config: ZBAR_CFG_Y_DENSITY to: 1];
        
        [self.viewController presentModalViewController: self.scanReader animated: YES];
    }
}

- (void)toggleflash {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    [device lockForConfiguration:nil];
    if (device.torchAvailable == 1) {
        if (device.torchMode == 0) {
            [device setTorchMode:AVCaptureTorchModeOn];
            [device setFlashMode:AVCaptureFlashModeOn];
        } else {
            [device setTorchMode:AVCaptureTorchModeOff];
            [device setFlashMode:AVCaptureFlashModeOff];
        }
    }
    
    [device unlockForConfiguration];
}

#pragma mark - Helpers

- (void)sendScanResult: (CDVPluginResult*)result {
    [self.commandDelegate sendPluginResult: result callbackId: self.scanCallbackId];
}

#pragma mark - ZBarReaderDelegate

- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    return;
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info {
    if ([self.scanReader isBeingDismissed]) {
        return;
    }
    
    id<NSFastEnumeration> results = [info objectForKey: ZBarReaderControllerResults];
    
    ZBarSymbol *symbol = nil;
    for(symbol in results) break; // get the first result

    [self.scanReader dismissModalViewControllerAnimated: YES];
    self.scanInProgress = NO;
    [self sendScanResult: [CDVPluginResult
                           resultWithStatus: CDVCommandStatus_OK
                           messageAsString: symbol.data]];
}

- (void) imagePickerControllerDidCancel:(UIImagePickerController*)picker
{
    [self.scanReader dismissModalViewControllerAnimated: YES];
    self.scanInProgress = NO;
    [self sendScanResult: [CDVPluginResult
                           resultWithStatus: CDVCommandStatus_ERROR
                           messageAsString: @"cancelled"]];
}

- (void) readerControllerDidFailToRead:(ZBarReaderController*)reader withRetry:(BOOL)retry
{
    [self.scanReader dismissModalViewControllerAnimated: YES];
    self.scanInProgress = NO;
    [self sendScanResult: [CDVPluginResult
                           resultWithStatus: CDVCommandStatus_ERROR
                           messageAsString: @"Failed"]];
}

@end
