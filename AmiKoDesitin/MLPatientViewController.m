//
//  MLPatientViewController.m
//  AmikoDesitin
//
//  Created by Alex Bettarini on 5 Feb 2018
//  Copyright © 2018 Ywesee GmbH. All rights reserved.
//

#import "MLPatientViewController.h"
#import "SWRevealViewController.h"
#import "MLContactsListViewController.h"
#import "MLPatientDBAdapter.h"
#import "MLViewController.h"
#import "MLAppDelegate.h"
#import "MLUtility.h"

#define DYNAMIC_BUTTONS

enum {
    NameFieldTag = 1,
    SurnameFieldTag,
    AddressFieldTag,
    CityFieldTag,
    ZIPFieldTag,
    DOBFieldTag,
    SexFieldTag
};

@interface MLPatientViewController ()

- (BOOL) stringIsNilOrEmpty:(NSString*)str;
- (BOOL) validateFields:(MLPatient *)patient;
- (MLPatient *) getAllFields;
- (void) friendlyNote:(NSString*)str;
#ifdef DYNAMIC_BUTTONS
- (void) saveCancelOn;
- (void) saveCancelOff;
#endif

@end

#pragma mark -

@implementation MLPatientViewController
{
    MLPatientDBAdapter *mPatientDb;
    NSString *mPatientUUID;
}

@synthesize scrollView;

+ (MLPatientViewController *)sharedInstance
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
    
    SWRevealViewController *revealController = [self revealViewController];

    // Left button(s)
    UIBarButtonItem *revealButtonItem =
    [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"reveal-icon.png"]
                                     style:UIBarButtonItemStylePlain
                                    target:revealController
                                    action:@selector(revealToggle:)];
#if 0
    // A single button on the left
    self.navigationItem.leftBarButtonItem = revealButtonItem;
#else
    // Two buttons on the left (with spacer between them)
    UIBarButtonItem *cancelItem =
    [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", nil)
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(cancelPatient:)];
#ifdef DYNAMIC_BUTTONS
    //cancelItem.enabled = NO; // Cancel always enabled
#endif

    UIBarButtonItem *spacer =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                  target:nil
                                                  action:nil];
    spacer.width = -15.0f;
    
    self.navigationItem.leftBarButtonItems =
    [NSArray arrayWithObjects:revealButtonItem, spacer, cancelItem, nil];
#endif
    
    // Right button(s)
#if 1
    // First ensure the "right" is a MLContactsListViewController
    id aTarget = self;
    SEL aSelector = @selector(myRightRevealToggle:);
#else
    id aTarget = revealController;
    SEL aSelector = @selector(rightRevealToggle:);
#endif
    UIBarButtonItem *rightRevealButtonItem =
    [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"reveal-icon.png"]
                                     style:UIBarButtonItemStylePlain
                                    target:aTarget
                                    action:aSelector];
#if 0
    // A single button on the right
    self.navigationItem.rightBarButtonItem = rightRevealButtonItem;
#else
    // Two buttons on the right (with spacer between them)
    UIBarButtonItem *saveItem =
    [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", nil)
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(savePatient:)];
#ifdef DYNAMIC_BUTTONS
    saveItem.enabled = NO;
#endif

    self.navigationItem.rightBarButtonItems =
    [NSArray arrayWithObjects:rightRevealButtonItem, spacer, saveItem, nil];
#endif
    
#ifdef DEBUG
    //self.navigationItem.prompt = @"Patient Edit";
#endif

    scrollView.bounces = NO;
    mPatientUUID = nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contactsListDidChangeSelection:)
                                                 name:@"ContactSelectedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

#ifdef DEBUG
- (void)viewDidAppear:(BOOL)animated
{
    NSLog(@"%s", __FUNCTION__);
    NSLog(@"gestureRecognizers:%ld %@", [[self.view gestureRecognizers] count], [self.view gestureRecognizers]);
}
#endif

- (void)viewWillAppear:(BOOL)animated
{
    if ([[self.view gestureRecognizers] count] == 0)
        [self.view addGestureRecognizer:[self revealViewController].panGestureRecognizer];
    
    // Open patient DB
    mPatientDb = [[MLPatientDBAdapter alloc] init];
    if (![mPatientDb openDatabase:@"patient_db"]) {
        NSLog(@"Could not open patient DB!");
        mPatientDb = nil;
    }
    
    [mNotification setText:@""];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL) stringIsNilOrEmpty:(NSString*)str
{
    return !(str && str.length);
}

- (void) resetFieldsColors
{
    mFamilyName.backgroundColor = nil;
    mGivenName.backgroundColor = nil;
    mBirthDate.backgroundColor = nil;
    mPostalAddress.backgroundColor = nil;
    mCity.backgroundColor = nil;
    mZipCode.backgroundColor = nil;
    mSex.backgroundColor = nil;
}

- (void) checkFields
{
    UIColor *lightRed = [UIColor colorWithRed:1.0
                                        green:0.0
                                         blue:0.0
                                        alpha:0.3];
    [self resetFieldsColors];
    
    if ([self stringIsNilOrEmpty:[mFamilyName text]])
        mFamilyName.backgroundColor = lightRed;

    if ([self stringIsNilOrEmpty:[mGivenName text]])
        mGivenName.backgroundColor = lightRed;

    if ([self stringIsNilOrEmpty:[mBirthDate text]])
        mBirthDate.backgroundColor = lightRed;

    if ([self stringIsNilOrEmpty:[mPostalAddress text]])
        mPostalAddress.backgroundColor = lightRed;

    if ([self stringIsNilOrEmpty:[mCity text]])
        mCity.backgroundColor = lightRed;

    if ([self stringIsNilOrEmpty:[mZipCode text]])
        mZipCode.backgroundColor = lightRed;
}

- (void) resetAllFields
{
#ifdef DEBUG
    //NSLog(@"%s %p", __FUNCTION__, self);
#endif
    
    [self resetFieldsColors];
    
    [mFamilyName setText:@""];
    [mGivenName setText:@""];
    [mBirthDate setText:@""];
    [mCity setText:@""];
    [mZipCode setText:@""];
    [mWeight_kg setText:@""];
    [mHeight_cm setText:@""];
    [mPostalAddress setText:@""];
    [mZipCode setText:@""];
    [mCity setText:@""];
    [mCountry setText:@""];
    [mPhone setText:@""];
    [mEmail setText:@""];
    [mSex setSelectedSegmentIndex:UISegmentedControlNoSegment];
    
    mPatientUUID = nil;
    
    [mNotification setText:@""];
}

- (void) setAllFields:(MLPatient *)p
{
    if (p.familyName)
        [mFamilyName setText:p.familyName];

    if (p.givenName)
        [mGivenName setText:p.givenName];

    if (p.birthDate)
        [mBirthDate setText:p.birthDate];

    if (p.city)
        [mCity setText:p.city];

    if (p.zipCode)
        [mZipCode setText:p.zipCode];

    if (p.weightKg>0)
        [mWeight_kg setText:[NSString stringWithFormat:@"%d", p.weightKg]];

    if (p.heightCm>0)
        [mHeight_cm setText:[NSString stringWithFormat:@"%d", p.heightCm]];

    if (p.country)
        [mCountry setText:p.country];

    if (p.postalAddress)
        [mPostalAddress setText:p.postalAddress];

    if (p.emailAddress)
        [mEmail setText:p.emailAddress];

    if (p.phoneNumber)
        [mPhone setText:p.phoneNumber];

    if (p.uniqueId)
        mPatientUUID = p.uniqueId;

    if (p.gender) {
        if ([p.gender isEqualToString:@"man"])
            [mSex setSelectedSegmentIndex:0];
        else if ([p.gender isEqualToString:@"woman"])
            [mSex setSelectedSegmentIndex:1];
    }
}

- (MLPatient *) getAllFields
{
    MLPatient *patient = [[MLPatient alloc] init];
    patient.familyName = [mFamilyName text];
    
    patient.givenName = [mGivenName text];
    patient.birthDate = [mBirthDate text];
    patient.city = [mCity text];
    patient.zipCode = [mZipCode text];
    patient.postalAddress = [mPostalAddress text];
    patient.weightKg = [[mWeight_kg text] intValue];
    patient.heightCm = [[mHeight_cm text] intValue];
    patient.country = [mCountry text];
    patient.phoneNumber = [mPhone text];
    patient.emailAddress = [mEmail text];
    
    switch ([mSex selectedSegmentIndex]) {
        case UISegmentedControlNoSegment:
            patient.gender = @"";
            break;
        case 0:
            patient.gender = @"man";
            break;
        case 1:
            patient.gender = @"woman";
            break;
    }

    return patient;
}

- (void) friendlyNote:(NSString*)str
{
    [mNotification setText:str];
}

// Validate "required" fields
- (BOOL) validateFields:(MLPatient *)patient
{
    BOOL valid = TRUE;
    UIColor *lightRed = [UIColor colorWithRed:1.0
                                        green:0.0
                                         blue:0.0
                                        alpha:0.3];
    
    [self resetFieldsColors];
    
    if ([self stringIsNilOrEmpty:patient.familyName]) {
        mFamilyName.backgroundColor = lightRed;
        valid = FALSE;
    }
    
    if ([self stringIsNilOrEmpty:patient.givenName]) {
        mGivenName.backgroundColor = lightRed;
        valid = FALSE;
    }
    
    if ([self stringIsNilOrEmpty:patient.birthDate]) {
        mBirthDate.backgroundColor = lightRed;
        valid = FALSE;
    }
    
    if ([self stringIsNilOrEmpty:patient.postalAddress]) {
        mPostalAddress.backgroundColor = lightRed;
        valid = FALSE;
    }
    
    if ([self stringIsNilOrEmpty:patient.city]) {
        mCity.backgroundColor = lightRed;
        valid = FALSE;
    }
    
    if ([self stringIsNilOrEmpty:patient.zipCode]) {
        mZipCode.backgroundColor = lightRed;
        valid = FALSE;
    }
    
    if ([mSex selectedSegmentIndex] == UISegmentedControlNoSegment) {
        mSex.backgroundColor = lightRed;
        valid = FALSE;
    }
    
    // TODO: the email is an optional field,
    // but if it's there, check at least that it is like *@*
    
    mPatientUUID = [patient generateUniqueID];
    
    return valid;
}

#ifdef DYNAMIC_BUTTONS
- (void) saveCancelOn
{
    self.navigationItem.leftBarButtonItems[0].enabled = NO;
    //self.navigationItem.leftBarButtonItems[2].enabled = YES;  // Cancel always enabled
    
    self.navigationItem.rightBarButtonItems[0].enabled = NO;
    self.navigationItem.rightBarButtonItems[2].enabled = YES;
}

- (void) saveCancelOff
{
    self.navigationItem.leftBarButtonItems[0].enabled = YES;
    //self.navigationItem.leftBarButtonItems[2].enabled = NO;
    
    self.navigationItem.rightBarButtonItems[0].enabled = YES;
    self.navigationItem.rightBarButtonItems[2].enabled = NO;
}
#endif

#pragma mark - UITextFieldDelegate

#ifdef DYNAMIC_BUTTONS
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self saveCancelOn];
}
#endif

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
#ifdef DEBUG
    //NSLog(@"%s tag:%ld", __FUNCTION__, textField.tag);
#endif
    if ((textField.tag == 6) ||     // country
        (textField.tag == 9) ||     // weight
        (textField.tag == 10) ||    // height
        (textField.tag == 11) ||    // phone
        (textField.tag == 12))      // email
    {
        return TRUE;  // Allow non mandatory fields to be empty
    }
        
    UIColor *lightRed = [UIColor colorWithRed:1.0
                                        green:0.0
                                         blue:0.0
                                        alpha:0.3];

    BOOL valid = TRUE;
    if ([textField.text isEqualToString:@""])
        valid = FALSE;

//    switch (textField.tag) {
//        case NameFieldTag: break;
//        case SurnameFieldTag: break;
//        case AddressFieldTag: break;
//        case CityFieldTag: break;
//        case ZIPFieldTag: break;
//        case DOBFieldTag: break;
//        case SexFieldTag: break;
//
//        default:
//            break;
//    }

    if (valid)
        textField.backgroundColor = nil;
    else
        textField.backgroundColor = lightRed;
    
    return valid;
}

#pragma mark - Actions

- (IBAction)myRightRevealToggle:(id)sender
{
    SWRevealViewController *revealController = [self revealViewController];

    // Check that the right controller class is MLContactsListViewController
    UIViewController *vc_right = revealController.rightViewController;
    
#ifdef DEBUG
    NSLog(@"%s vc: %@", __FUNCTION__, [vc_right class]);
#endif
    
    if (![vc_right isKindOfClass:[MLContactsListViewController class]] ) {
        // Replace right controller
        MLContactsListViewController *contactsListViewController =
        [[MLContactsListViewController alloc] initWithNibName:@"MLContactsListViewController"
                                                       bundle:nil];
        [revealController setRightViewController:contactsListViewController];
        NSLog(@"Replaced right VC");
    }

#ifdef CONTACTS_LIST_FULL_WIDTH
    float frameWidth = self.view.frame.size.width;
    revealController.rightViewRevealWidth = frameWidth;
#endif
    
    if ([revealController frontViewPosition] == FrontViewPositionLeft)
        [revealController setFrontViewPosition:FrontViewPositionLeftSide animated:YES];
    else
        [revealController setFrontViewPosition:FrontViewPositionLeft animated:YES];  // Center
}

- (IBAction) cancelPatient:(id)sender
{
#ifdef DEBUG
    //NSLog(@"%s", __FUNCTION__);
#endif
    [self resetAllFields];

#ifdef DYNAMIC_BUTTONS
    [self saveCancelOff];
#endif

    // Show list of patients from DB
    MLAppDelegate *appDel = (MLAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDel switchRigthToPatientDbList];
}

- (IBAction) savePatient:(id)sender
{
#ifdef DEBUG
    //NSLog(@"%s", __FUNCTION__);
#endif

    if (!mPatientDb) {
        NSLog(@"%s Patient DB is null", __FUNCTION__);
        return;
    }
    
    MLPatient *patient = [self getAllFields];
    if (![self validateFields:patient]) {
        NSLog(@"Patient field validation failed");
        return;
    }
    
#ifdef DEBUG
    //NSLog(@"before adding %@, count %ld", mPatientUUID, [mPatientDb getNumPatients]);
#endif
    
    if (mPatientUUID && [mPatientUUID length]>0)
        patient.uniqueId = mPatientUUID;
    
    NSString *note = NSLocalizedString(@"Contact was saved in the AmiKo address book", nil);
    
    if ([mPatientDb getPatientWithUniqueID:mPatientUUID]==nil)
        mPatientUUID = [mPatientDb addEntry:patient];       // insert into DB
    else {
        if (patient.uniqueId!=nil &&
            [patient.uniqueId length]>0)
        {
            note = NSLocalizedString(@"The entry has been updated", nil);
        }

        mPatientUUID = [mPatientDb insertEntry:patient];    // insert into DB or update
    }

    if (mPatientUUID==nil) {
#ifdef DEBUG
        NSLog(@"%s:%d Could not add/insert patient", __FUNCTION__, __LINE__);
#endif
        return;
    }
    
    [self friendlyNote:note];

#ifdef DYNAMIC_BUTTONS
    [self saveCancelOff];
#endif
    
#ifdef DEBUG
    //NSLog(@"patients after adding: %ld", [mPatientDb getNumPatients]);
#endif
    
    // Set as default patient for prescriptions
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:mPatientUUID forKey:@"currentPatient"];
    [defaults synchronize];
    
    // Create patient subdirectory for prescriptions
#if 0 //def DEBUG
    NSString *amkDir = [MLUtility amkDirectory];
    NSLog(@"amk subdirectory: %@", amkDir);
#else
    //[MLUtility amkDirectoryForPatient:mPatientUUID];
    [MLUtility amkDirectory];
#endif
    
    // Switch view
    MLAppDelegate *appDel = (MLAppDelegate *)[[UIApplication sharedApplication] delegate];
    if (appDel.editMode == EDIT_MODE_PATIENTS) {
        [appDel performSelector:@selector(switchRigthToPatientDbList) withObject:nil afterDelay:1.0];
    }
    else if (appDel.editMode == EDIT_MODE_PRESCRIPTION) {
        UIViewController *nc = self.revealViewController.rearViewController;
        MLViewController *vc = [nc.childViewControllers firstObject];
        [vc switchToPrescriptionView];
    }
}

#pragma mark - Notifications

- (void)keyboardDidShow:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    CGRect keyboardRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardRect = [self.view convertRect:keyboardRect fromView:nil];

    UIEdgeInsets contentInset = self.scrollView.contentInset;
    contentInset.bottom = keyboardRect.size.height;
    self.scrollView.contentInset = contentInset;
    self.scrollView.scrollIndicatorInsets = contentInset;
}

-(void)keyboardWillHide:(NSNotification *)notification
{
    UIEdgeInsets contentInset = self.scrollView.contentInset;
    contentInset.bottom = 0;
    self.scrollView.contentInset = contentInset;
    scrollView.scrollIndicatorInsets = contentInset;
}

- (void)contactsListDidChangeSelection:(NSNotification *)aNotification
{
    MLPatient *p = [aNotification object];
#ifdef DEBUG
    //NSLog(@"%s selected familyName:%@", __FUNCTION__, p.familyName);
#endif
    
    [self resetAllFields];
    [self setAllFields:p];
    
    // TODO: Add contact to patient DB
    
    SWRevealViewController *revealController = self.revealViewController;
#if 1
    [revealController rightRevealToggleAnimated:YES];
#else
    [revealController setFrontViewPosition:FrontViewPositionLeftSideMost animated:YES];
#endif
}

@end
