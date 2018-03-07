//
//  MLDoctorViewController.m
//  AmiKoDesitin
//
//  Created by Alex Bettarini on 5 Mar 2018
//  Copyright © 2018 Ywesee GmbH. All rights reserved.
//

#import "MLDoctorViewController.h"
#import "SWRevealViewController.h"
#import "MLUtility.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface MLDoctorViewController ()

@end

#pragma mark -

@implementation MLDoctorViewController

@synthesize signatureView;

+ (MLDoctorViewController *)sharedInstance
{
    __strong static id sharedObject = nil;
    
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedObject = [[self alloc] init];
    });
    return sharedObject;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
    SWRevealViewController *revealController = [self revealViewController];
    
    [self.view addGestureRecognizer:revealController.panGestureRecognizer];
    
    self.navigationItem.title = NSLocalizedString(@"Doctor", nil);
    
    // Left button(s)
    UIBarButtonItem *revealButtonItem =
    [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"reveal-icon.png"]
                                     style:UIBarButtonItemStylePlain
                                    target:revealController
                                    action:@selector(revealToggle:)];
    
    // A single button on the left
    self.navigationItem.leftBarButtonItem = revealButtonItem;
    
    // Right button(s)
    UIBarButtonItem *saveItem =
    [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", nil)
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(saveDoctor:)];
    saveItem.enabled = NO;
    self.navigationItem.rightBarButtonItem = saveItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.navigationItem.rightBarButtonItems[0].enabled = YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
#ifdef DEBUG
    //NSLog(@"%s tag:%ld", __FUNCTION__, textField.tag);
#endif
    UIColor *lightRed = [UIColor colorWithRed:1.0
                                        green:0.0
                                         blue:0.0
                                        alpha:0.3];
    BOOL valid = TRUE;
    if ([textField.text isEqualToString:@""])
        valid = FALSE;
    
    if (valid)
        textField.backgroundColor = nil;
    else
        textField.backgroundColor = lightRed;
    
    return valid;
}

#pragma mark - Actions

- (IBAction) saveDoctor:(id)sender
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
    // TODO: set as default for prescriptions
    
    // Back to main screen
    [[self revealViewController] revealToggle:nil];
}

- (IBAction) signWithSelfie:(id)sender
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        NSLog(@"Camera not available");
        return;
    }

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    //picker.navigationBarHidden = NO;
    //picker.wantsFullScreenLayout = NO;

    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.mediaTypes = @[(NSString *) kUTTypeImage];
    //picker.mediaTypes = @[(NSString *) kUTTypeImage, (NSString *) kUTTypeLivePhoto];
    picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
    //picker.showsCameraControls = NO;
    
    [self presentViewController:picker animated:YES completion:NULL];
}

- (IBAction) signWithPhoto:(id)sender
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        NSLog(@"Photo library not available");
        return;
    }
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    //picker.navigationBarHidden = NO;
    //picker.wantsFullScreenLayout = NO;

    //picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;  // all folders in gallery
    picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum; // camera roll
    
    [self presentViewController:picker animated:YES completion:NULL];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
#ifdef DEBUG
    //NSLog(@"%s %@", __FUNCTION__, info);
#endif
    UIImage *chosenImage = info[UIImagePickerControllerEditedImage];
    //NSLog(@"chosenImage %@", NSStringFromCGSize(chosenImage.size));
    
    // TODO: first resize it for the PNG file, then resize even smaller for the view

#if 0
    // If we want to keep the image for future use:
    // check if the image originated from the camera, store it in the photo album
    // this require NSAppleMusicUsageDescription in Info.plist
    UIImage *referenceURL = info[UIImagePickerControllerReferenceURL];
    if (!referenceURL) // nil if coming from camera
        UIImageWriteToSavedPhotosAlbum(chosenImage, nil, nil, nil);
#endif
    
    // Resize
    CGSize size = self.signatureView.frame.size;
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [chosenImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *smallImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //NSLog(@"smallImage %@", NSStringFromCGSize(smallImage.size));

    // Save to PNG file
    NSString *documentsDirectory = [MLUtility documentsDirectory];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"op_signature.png"];
    [UIImagePNGRepresentation(smallImage) writeToFile:filePath atomically:YES];

    // Show it
    self.signatureView.image = smallImage;
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end
