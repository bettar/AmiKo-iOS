//
//  MLPrescriptionViewController.m
//  AmikoDesitin
//
//  Created by Alex Bettarini on 22 Jan 2018.
//  Copyright © 2018 Ywesee GmbH. All rights reserved.
//

#import "MLPrescriptionViewController.h"
#import "SWRevealViewController.h"
#import "MLUtility.h"

#import "MLViewController.h"
#import "MLAppDelegate.h"
#import "MLAmkListViewController.h"
#import "MLPatientDBAdapter.h"

static const float kInfoCellHeight = 20.0;  // fixed

static const float kSectionHeaderHeight = 27.0;

// Medicine cell layout
static const float kLabelVerMargin = 2.4;
static const float kMedCellHorMargin = 12.0;
static const float kMedCellHeight = 44.0;  // minimum height

enum {
    kSectionMeta=0,
    kSectionOperator,
    kSectionPatient,
    kSectionMedicines,

    kNumSections
};

CGSize getSizeOfLabel(UILabel *label, CGFloat width)
{
    CGSize constraint = CGSizeMake(width, CGFLOAT_MAX);
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    CGSize boundSize = [label.text boundingRectWithSize:constraint
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                             attributes:@{NSFontAttributeName:label.font}
                                                context:context].size;
    return CGSizeMake(ceil(boundSize.width), ceil(boundSize.height));
}

#pragma mark -

@interface MLPrescriptionViewController ()

- (void)layoutCellSeparator:(UITableViewCell *)cell;
- (void)layoutFrames;
- (void)loadDefaultDoctor;
- (BOOL)loadDefaultPrescription;
- (BOOL)loadDefaultPatient;

@end

#pragma mark -

@implementation MLPrescriptionViewController
{
    CGRect mainFrame;
}

@synthesize prescription;
@synthesize infoView;
@synthesize editedMedicines;

+ (MLPrescriptionViewController *)sharedInstance
{
    __strong static id sharedObject = nil;
    
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedObject = [[self alloc] init];
    });
    
    return sharedObject;
}

- (void)layoutFrames
{
    CGRect infoFrame = self.infoView.frame;
    infoFrame.origin.y = 0.6;
    infoFrame.size.width = self.view.bounds.size.width;

    infoFrame.size.height = ((kSectionHeaderHeight * 2) +
                             (kInfoCellHeight * [prescription.doctor entriesCount]) +
                             (kInfoCellHeight * [prescription.patient entriesCount]) +
                             20.8); // margin
    [self.infoView setFrame:infoFrame];
}

- (void)layoutCellSeparator:(UITableViewCell *)cell
{
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        cell.separatorInset = UIEdgeInsetsZero;
    }

    if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
        cell.preservesSuperviewLayoutMargins = NO;
    }

    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        cell.layoutMargins = UIEdgeInsetsZero;
    }
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    UIBarButtonItem *patientsItem =
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Search Patients", nil)
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(showPatientDbList:)];

    UIBarButtonItem *spacer =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                      target:nil
                                                      action:nil];
    spacer.width = 90.0f;

    self.navigationItem.leftBarButtonItems =
        [NSArray arrayWithObjects:revealButtonItem, spacer, patientsItem, nil];
#endif
    
    // Right button
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
    self.navigationItem.rightBarButtonItem = rightRevealButtonItem;
    
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    int statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    int navBarHeight = self.navigationController.navigationBar.frame.size.height;
    int barHeight = statusBarHeight + navBarHeight;
    mainFrame = CGRectMake(0, barHeight,
                           screenBounds.size.width,
                           CGRectGetHeight(screenBounds) - barHeight);
    
    if (!prescription)
        prescription = [[MLPrescription alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(amkListDidChangeSelection:)
                                                 name:@"AmkFilenameSelectedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(amkDeleted:)
                                                 name:@"AmkFilenameDeletedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(patientDbListDidChangeSelection:)
                                                 name:@"PatientSelectedNotification"
                                               object:nil];
    self.editedMedicines = false;
}

- (void) viewWillAppear:(BOOL)animated
{
    if ([[self.view gestureRecognizers] count] == 0)
        [self.view addGestureRecognizer:[self revealViewController].panGestureRecognizer];
}

- (void) viewDidAppear:(BOOL)animated
{
    if (editedMedicines) {
#ifdef DEBUG
        NSLog(@"%s %d", __FUNCTION__, __LINE__);
#endif
        [self loadDefaultDoctor];
    }
    else {
#ifdef DEBUG
        NSLog(@"%s %d", __FUNCTION__, __LINE__);
#endif
        // do the following only if we haven't added any medicines yet
        if (![self loadDefaultPrescription]) {
            [self loadDefaultDoctor];
            [self loadDefaultPatient];
        }
    }
    
    [infoView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -

- (NSString *) makeNewUniqueHash
{
    // Creates and returns a new UUID with RFC 4122 version 4 random bytes
    return [[NSUUID UUID] UUIDString];
}

#pragma mark -

- (BOOL) checkDefaultDoctor
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *doctorDictionary = [defaults dictionaryForKey:@"currentDoctor"];
    if (doctorDictionary)
        return TRUE;
    
#ifdef DEBUG
    NSLog(@"Default doctor is not yet defined");
#endif
    return FALSE;
}

- (void) loadDefaultDoctor
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
#if 0
    if ([self checkDefaultDoctor])
        return;
#else
    // Init from defaults
    // See also MLOperator importFromDict
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *doctorDictionary = [defaults dictionaryForKey:@"currentDoctor"];
    if (!doctorDictionary) {
#ifdef DEBUG
        NSLog(@"Default doctor is not yet defined");
#endif
        return;
    }
#endif
    
#ifdef DEBUG
    //NSLog(@"Default doctor %@", doctorDictionary);
#endif
    if (!prescription.doctor)
        prescription.doctor = [[MLOperator alloc] init];
    
    [prescription.doctor importFromDict:doctorDictionary];
    [prescription.doctor importSignature];
}

// Try to reopen the last used file
- (BOOL)loadDefaultPrescription
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    // Try to reopen the last used file
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *fileName = [defaults stringForKey:@"lastUsedPrescription"];
    if (!fileName) {
        NSLog(@"%s %d", __FUNCTION__, __LINE__);
        return FALSE;
    }
    
    NSString *fullFilePath = [[MLUtility amkDirectory] stringByAppendingPathComponent:fileName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fullFilePath]) {
        [defaults removeObjectForKey:@"lastUsedPrescription"];
        [defaults synchronize];
        NSLog(@"%s %d", __FUNCTION__, __LINE__);
        return FALSE;
    }

    NSURL *url = [NSURL fileURLWithPath:fullFilePath];
    [prescription importFromURL:url];
    NSLog(@"Reopening:%@", fileName);
    return TRUE;
}

- (BOOL)loadDefaultPatient
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *patientId = [defaults stringForKey:@"currentPatient"];
    if (!patientId) {
#ifdef DEBUG
        NSLog(@"Default patient is not yet defined");
#endif
        return FALSE;
    }
    
    MLPatientDBAdapter *patientDb = [[MLPatientDBAdapter alloc] init];
    if (![patientDb openDatabase:@"patient_db"]) {
        NSLog(@"Could not open patient DB!");
        return FALSE;
    }

    MLPatient *pat = [patientDb getPatientWithUniqueID:patientId];
    [prescription setPatient:pat];
    [patientDb closeDatabase];
    return TRUE;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kNumSections;
}

- (NSInteger) tableView: (UITableView *)tableView
  numberOfRowsInSection: (NSInteger)section
{
    if (section == kSectionMeta)
        return 1;

    if ((section == kSectionOperator) && (prescription.doctor != nil))
        return [prescription.doctor entriesCount];
    
    if ((section == kSectionPatient) && (prescription.patient != nil))
        return [prescription.patient entriesCount];
    
    if (section == kSectionMedicines)
        return [prescription.medications count];
    
    return 0;
}

#pragma mark - Table view delegate

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // set height by section
    CGRect frame = CGRectMake(0, 0, CGRectGetWidth(tableView.frame), 0);
    UIView *view = [[UIView alloc] initWithFrame:frame];
    
    CGRect labelFrame = CGRectMake(kMedCellHorMargin, 2, 200, kSectionHeaderHeight-2);
    UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightLight];
    label.textColor = [UIColor darkGrayColor];
    frame.size.height = kSectionHeaderHeight-2;
    
    if (section == kSectionMeta) {
        frame.size.height = 0;
        label.text = @"";
    }
    else if (section == kSectionOperator)
        label.text = NSLocalizedString(@"Doctor", nil);
    else if (section == kSectionPatient)
        label.text = NSLocalizedString(@"Patient", nil);
    else if (section == kSectionMedicines) {
        NSString *format;
        NSInteger count = [prescription.medications count];
        if (count == 1)
            format = NSLocalizedString(@"Medicine", nil);
        else
            format = NSLocalizedString(@"Medicines", nil);

        label.text = [NSString stringWithFormat:@"%@ (%lu)", format, count];
        [view setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
    }

    [view addSubview:label];
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // default value: UITableViewAutomaticDimension;
    if (section == kSectionMeta)
        return kSectionHeaderHeight / 2.5;
    
    // operator|patient
    return kSectionHeaderHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
//    if ((indexPath.section == kSectionOperator) && (indexPath.row == 0))
//        return DOCTOR_TN_H;

    if (indexPath.section != kSectionMedicines)
        return kInfoCellHeight;

    if (prescription.medications==nil)
        return kInfoCellHeight;

    MLProduct *med = prescription.medications[indexPath.row];
    if (med==nil)
        return kMedCellHeight;

    CGFloat height = 0.0;
    CGFloat width = tableView.frame.size.width - 24.0; // TODO

    // package name label
    UILabel *packLabel = [self makeLabel:med.packageInfo
                               textColor:[UIColor clearColor]];
    height += getSizeOfLabel(packLabel, width).height;
    height += kLabelVerMargin;
    // ean label
    UILabel *eanLabel = [self makeLabel:med.eanCode
                              textColor:[UIColor clearColor]];
    height += getSizeOfLabel(eanLabel, width).height;
    height += kLabelVerMargin;
    height += 8.0;
    // comment label
    UILabel *commentLabel = [self makeLabel:med.comment
                                  textColor:[UIColor clearColor]];
    height += getSizeOfLabel(commentLabel, width).height;
    height += kLabelVerMargin;
    height += 8.0;
    if (height > kMedCellHeight)
        return height;

    return kMedCellHeight;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
{
    [self layoutCellSeparator:cell];
}

- (UITableViewCell *) tableView: (UITableView *)tableView
          cellForRowAtIndexPath: (NSIndexPath *)indexPath
{
#ifdef DEBUG
    //NSLog(@"%s section:%ld, row:%ld", __FUNCTION__, indexPath.section, indexPath.row);
    //NSLog(@"size: %@", NSStringFromCGSize(tableView.frame.size));
#endif

    static NSString *tableIdentifier = @"PrescriptionTableItem";
    UITableViewCell *cell;
#if 0
    cell = [tableView dequeueReusableCellWithIdentifier:tableIdentifier];
    if (cell == nil)
#endif
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:tableIdentifier];
        cell.contentView.translatesAutoresizingMaskIntoConstraints = YES;
    }
    
    if (indexPath.section != kSectionMedicines)
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

    CGRect frame = CGRectMake(12.0, 0, tableView.frame.size.width, 25.0);  // TODO: remove magic numbers
    
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    if (indexPath.section == kSectionMeta) {
        label.font = [UIFont systemFontOfSize:13.8];
        label.textAlignment = NSTextAlignmentLeft;
        label.textColor = [UIColor blackColor];
        label.backgroundColor = [UIColor clearColor];
        label.text = prescription.placeDate;
    }
    else if (indexPath.section == kSectionOperator) {
        if (!prescription.doctor) {
            cell.textLabel.text = @"";
            return cell;
        }

        label.font = [UIFont systemFontOfSize:13.0];
        label.textAlignment = NSTextAlignmentLeft;
        label.textColor = [UIColor blackColor];
        label.backgroundColor = [UIColor clearColor];
        label.text = @"";  // Initialize for appending
        cell.backgroundColor = [UIColor clearColor];  // Allow the signature to show over multiple cells
        switch (indexPath.row) {
            case 0:
                label.text = [NSString stringWithFormat:@"%@ %@ %@",
                              prescription.doctor.title,
                              prescription.doctor.familyName,
                              prescription.doctor.givenName];

                if (([prescription.doctor signature] != nil) &&
                    ![prescription.doctor.signature isEqualToString:@""])
                {
                    UIImage *img = [prescription.doctor thumbnailFromSignature:CGSizeMake(DOCTOR_TN_W, DOCTOR_TN_H)];
                    UIImageView *signatureView = [[UIImageView alloc] initWithImage:img];
                    [signatureView setFrame:CGRectMake(frame.size.width - (DOCTOR_TN_W + 10.0),
                                                       0,
                                                       DOCTOR_TN_W,
                                                       DOCTOR_TN_H)];
                    signatureView.contentMode = UIViewContentModeTopRight;
                    [cell.contentView addSubview:signatureView];
                }
                break;
            case 1:
                label.text = prescription.doctor.postalAddress;
                break;
            case 2:
                    label.text = [NSString stringWithFormat:@"%@ %@",
                                  prescription.doctor.zipCode,
                                  prescription.doctor.city];
                break;
            case 3:
                    label.text = prescription.doctor.phoneNumber;
                break;
            case 4:
                    label.text = prescription.doctor.emailAddress;
                break;
            default:
                break;
        }
    }
    else if (indexPath.section == kSectionPatient) {
        if (!prescription.patient) {
            cell.textLabel.text = @"";
            return cell;
        }

        label.font = [UIFont systemFontOfSize:13.0];
        label.textAlignment = NSTextAlignmentLeft;
        label.textColor = [UIColor blackColor];
        label.backgroundColor = [UIColor clearColor];
        switch (indexPath.row) {
            case 0:
                label.text = [NSString stringWithFormat:@"%@ %@",
                              prescription.patient.familyName,
                              prescription.patient.givenName];
                break;
            case 1:
                label.text = [NSString stringWithFormat:@"%dkg/%dcm %@ %@",
                              prescription.patient.weightKg,
                              prescription.patient.heightCm,
                              prescription.patient.gender,
                              prescription.patient.birthDate];
                break;
            case 2:
                label.text = prescription.patient.postalAddress;
                break;
            case 3:
                label.text = [NSString stringWithFormat:@"%@ %@ %@",
                              prescription.patient.zipCode,
                              prescription.patient.city,
                              prescription.patient.country];
                break;
            case 4:
                label.text = prescription.patient.phoneNumber;
                break;
            case 5:
                label.text = prescription.patient.emailAddress;
                break;
            default:
                break;
        }
    }
    else {

        MLProduct * med = prescription.medications[indexPath.row];
        UILabel *packLabel = [self makeLabel:med.packageInfo
                                   textColor:[UIColor blackColor]];

        UILabel *eanLabel = [self makeLabel:med.eanCode
                                  textColor:[UIColor darkGrayColor]];

        UILabel *commentLabel = [self makeLabel:med.comment
                                      textColor:[UIColor darkGrayColor]];

        // layout
        CGRect eanFrame = CGRectMake(kMedCellHorMargin,
                                     packLabel.frame.origin.y + packLabel.frame.size.height + kLabelVerMargin,
                                     eanLabel.frame.size.width,
                                     eanLabel.frame.size.height);
        [eanLabel setFrame:eanFrame];
        
        CGRect commentFrame = CGRectMake(kMedCellHorMargin,
                                         eanLabel.frame.origin.y + eanLabel.frame.size.height + kLabelVerMargin,
                                         commentLabel.frame.size.width,
                                         commentLabel.frame.size.height);
        [commentLabel setFrame:commentFrame];
        [cell.contentView addSubview:packLabel];
        [cell.contentView insertSubview:eanLabel belowSubview:packLabel];
        [cell.contentView insertSubview:commentLabel belowSubview:eanLabel];
        return cell;
    }

    if (label.text) { // 1 cell per row
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.numberOfLines = 0;
        label.preferredMaxLayoutWidth = frame.size.width;
        [label sizeToFit];
        [cell.contentView addSubview:label];
    }
    
    return cell;
}

#pragma mark - Actions

- (IBAction)myRightRevealToggle:(id)sender
{
    SWRevealViewController *revealController = [self revealViewController];
    
    // Check that the right controller class is MLAmkListViewController
    UIViewController *vc_right = revealController.rightViewController;
    
#ifdef DEBUG
    //NSLog(@"%s vc: %@", __FUNCTION__, [vc_right class]);
#endif
    
    if (![vc_right isKindOfClass:[MLAmkListViewController class]] ) {
        // Replace right controller
        MLAmkListViewController *amkListViewController =
        [[MLAmkListViewController alloc] initWithNibName:@"MLAmkListViewController"
                                                       bundle:nil];
        [revealController setRightViewController:amkListViewController];
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

- (IBAction) showPatientDbList:(id)sender
{
#ifdef DEBUG
    //NSLog(@"%s", __FUNCTION__);
#endif
    MLAppDelegate *appDel = (MLAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDel switchRigthToPatientDbList];
}

#pragma mark - Toolbar actions

- (IBAction) newPrescription:(id)sender
{
    UIBarButtonItem *btn = (UIBarButtonItem *)sender;
#ifdef DEBUG
    NSLog(@"%s tag:%ld, title:%@", __FUNCTION__, btn.tag, btn.title);
#endif
    [self loadDefaultDoctor];
    
    if ([self loadDefaultPatient])
        [infoView reloadData];
    
    // TODO: clear medicines
}

- (IBAction) checkForInteractions:(id)sender
{
    // TODO:
}

- (IBAction) savePrescription:(id)sender
{
    NSString *alertMessage = nil;
    NSString *alertTitle = nil;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:alertTitle
                                                                             message:alertMessage
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *actionOk = [UIAlertAction actionWithTitle:NSLocalizedString(@"Overwrite Prescription", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
                                                         [alertController dismissViewControllerAnimated:YES completion:nil];
                                                         [self overwritePrescription];
                                                     }];
    
    UIAlertAction *actionNo = [UIAlertAction actionWithTitle:NSLocalizedString(@"Save as New Prescription", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             [alertController dismissViewControllerAnimated:YES completion:nil];
                                                             [self saveNewPrescription];
                                                         }];
    
    // Cancel buttons are removed from popovers automatically, because tapping outside the popover represents "cancel", in a popover context
    UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
                                                             [alertController dismissViewControllerAnimated:YES completion:nil];
                                                         }];
    [alertController addAction:actionOk];
    [alertController addAction:actionNo];
    [alertController addAction:actionCancel];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        //UIBarButtonItem *button = (UIBarButtonItem *)sender;
        alertController.popoverPresentationController.barButtonItem = sender;
        alertController.popoverPresentationController.sourceView = self.view;
    }

    [self presentViewController:alertController animated:YES completion:nil]; // It returns immediately
}

- (IBAction) sendPrescription:(id)sender
{
    [self savePrescription:sender];
    // TODO:
}

#pragma mark -

- (void) overwritePrescription
{
    NSString *documentsDir = [MLUtility documentsDirectory];
#ifdef DEBUG
    NSLog(@"documentsDir:%@", documentsDir);
#endif
    
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
}

- (void) saveNewPrescription
{
    if (![self checkDefaultDoctor])
        return;
    
    if ((!self.prescription.medications) ||
        ([self.prescription.medications count] < 1)) {
        NSLog(@"Cannot save prescription with no medications");
        return;
    }
    
    NSString *amkDir;
    NSString *uid = [self.prescription.patient uniqueId];
    if (uid)
        amkDir = [MLUtility amkDirectoryForPatient:uid];
    else
        amkDir = [MLUtility amkDirectory];
    
    NSError *error;
//    [[NSFileManager defaultManager] createDirectoryAtPath:amkDir
//                              withIntermediateDirectories:YES
//                                               attributes:nil
//                                                    error:&error];
//    if (error) {
//        NSLog(@"%@", error.localizedDescription);
//        return;
//    }
    
    NSLocale *currentLocale = [NSLocale currentLocale];
    NSString *countryCode = [currentLocale objectForKey:NSLocaleCountryCode];
    prescription.placeDate = [NSString stringWithFormat:@"%@, %@",
                              countryCode, //[defaults stringForKey:KEY_AMK_DOC_CITY],  // TODO:
                              [MLUtility prettyTime]];
    
    prescription.hash = [self makeNewUniqueHash];

    NSMutableDictionary *prescriptionDict = [[NSMutableDictionary alloc] init];
    [prescriptionDict setObject:prescription.hash forKey:KEY_AMK_HASH];
    [prescriptionDict setObject:prescription.placeDate forKey:KEY_AMK_PLACE_DATE];
    [prescriptionDict setObject:[prescription makePatientDictionary] forKey:KEY_AMK_PATIENT];
    [prescriptionDict setObject:[prescription makeOperatorDictionary] forKey:KEY_AMK_OPERATOR];
    [prescriptionDict setObject:[prescription makeMedicationsArray] forKey:KEY_AMK_MEDICATIONS];
    
    //NSLog(@"Line %d, prescriptionDict:%@", __LINE__, prescriptionDict);

    if ([NSJSONSerialization isValidJSONObject:prescriptionDict]) {
        NSLog(@"Invalid JSON object:%@", prescriptionDict);
        //return;
    }
    // TODO:
    
    // Map cart array to json
    NSData *jsonObject = [NSJSONSerialization dataWithJSONObject:prescriptionDict
                                                         options:NSJSONWritingPrettyPrinted
                                                           error:&error];
    
    NSString *jsonStr = [[NSString alloc] initWithData:jsonObject encoding:NSUTF8StringEncoding];
    NSLog(@"Line %d, jsonStr:%@", __LINE__, jsonStr);
    NSString *base64Str = [MLUtility encodeStringToBase64:jsonStr];
    
#if 1
    // Prescription file name like AmiKo
    NSString *currentTime = [[MLUtility currentTime] stringByReplacingOccurrencesOfString:@":" withString:@""];
    currentTime = [currentTime stringByReplacingOccurrencesOfString:@"." withString:@""];
    NSString *amkFile = [NSString stringWithFormat:@"RZ_%@.amk", currentTime];
    NSString *amkFilePath = [amkDir stringByAppendingPathComponent:amkFile];
#else
    // Prescription file name like Generika
    time_t timestamp = (time_t)[[NSDate date] timeIntervalSince1970];
    NSString *amkFile = [NSString stringWithFormat:@"%@_%d.amk", @"RZ", (int)timestamp];
    NSString *amkFilePath = [amkDir stringByAppendingPathComponent:amkFile];
#endif

    BOOL amkSaved = [base64Str writeToFile:amkFilePath
                                atomically:YES
                                  encoding:NSUTF8StringEncoding
                                     error:&error];
    if (!amkSaved)
        NSLog(@"Error: %@", [error userInfo]);
}

- (UILabel *)makeLabel:(NSString *)text textColor:(UIColor *)color
{
    CGRect frame = CGRectMake(kMedCellHorMargin,
                              8.0,
                              mainFrame.size.width - 2*kMedCellHorMargin,
                              kMedCellHeight);
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.font = [UIFont systemFontOfSize:12.2];
    label.textAlignment = NSTextAlignmentLeft;
    label.textColor = color;
    label.text = text;
    label.backgroundColor = [UIColor clearColor];
    label.highlighted = NO;
    // use multiple lines for wrapped text as required
    label.numberOfLines = 0;
    label.preferredMaxLayoutWidth = frame.size.width;
    // this line must be after `numberOfLines`
    [label sizeToFit];
    return label;
}

#pragma mark - Notifications

- (void)amkListDidChangeSelection:(NSNotification *)aNotification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[aNotification object] forKey:@"lastUsedPrescription"];
    [defaults synchronize];
    
    NSString *amkDir = [MLUtility amkDirectory];
    NSString *fullFilePath = [amkDir stringByAppendingPathComponent:[aNotification object]];
    NSURL *url = [NSURL fileURLWithPath:fullFilePath];
    [prescription importFromURL:url];
    [infoView reloadData];
    
    [self.revealViewController rightRevealToggleAnimated:YES];
}

- (void)amkDeleted:(NSNotification *)aNotification
{
#ifdef DEBUG
    NSLog(@"%s", __PRETTY_FUNCTION__);
#endif
    
    prescription.hash = nil;
    prescription.placeDate = nil;
    prescription.medications = nil;
    prescription.patient = nil;
    
    [infoView reloadData];
    
    [self.revealViewController rightRevealToggleAnimated:YES];
}

- (void)patientDbListDidChangeSelection:(NSNotification *)aNotification
{
    [prescription setPatient:[aNotification object]];
    [infoView reloadData];
    // TODO: (TBC) make sure the right view is back to the AMK list, for the sake of the swiping action
}

@end
