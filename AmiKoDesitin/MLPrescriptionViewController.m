//
//  MLPrescriptionViewController.m
//  AmikoDesitin
//
//  Created by Alex Bettarini on 22 Jan 2018.
//  Copyright © 2018 Ywesee GmbH. All rights reserved.
//

#import "MLPrescriptionViewController.h"
#import "SWRevealViewController.h"

@interface MLPrescriptionViewController ()

@end

@implementation MLPrescriptionViewController
{
#ifdef DEBUG
    NSArray *tableData;
#endif
}

- (void)viewDidLoad
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    // SWRevealViewController extends UIViewController!
    SWRevealViewController *revealController = [self revealViewController];
    
    [self.navigationController.navigationBar addGestureRecognizer:revealController.panGestureRecognizer];

    UIBarButtonItem *revealButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"reveal-icon.png"]
                                                                         style:UIBarButtonItemStylePlain
                                                                        target:revealController
                                                                        action:@selector(revealToggle:)];
    
    self.navigationItem.leftBarButtonItem = revealButtonItem;
    
    // PanGestureRecognizer goes here
    [self.view addGestureRecognizer:revealController.panGestureRecognizer];

#ifdef DEBUG
    tableData = [NSArray arrayWithObjects:@"Ponstan", @"Marcoumar", @"Abilify", nil];
#endif
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (nullable NSString *)tableView:(UITableView *)tableView
         titleForHeaderInSection:(NSInteger)section
{
#ifdef DEBUG
    NSLog(@"%s section:%ld", __FUNCTION__, section);
#endif
    if (section == 0)
        return NSLocalizedString(@"Doctor", nil);
    
    if (section == 1)
        return NSLocalizedString(@"Patient", nil);
    
    return NSLocalizedString(@"Medicines", nil);
}

- (NSInteger) tableView: (UITableView *)tableView
  numberOfRowsInSection: (NSInteger)section
{
#ifdef DEBUG
    NSLog(@"%s section:%ld", __FUNCTION__, section);
#endif
    // Return the number of rows in the section.
    if ((section == 0) || (section == 1))
        return 1;

#ifdef DEBUG
    return [tableData count];
#else
    return 6; // TODO
#endif
}

#pragma mark - Table view delegate

- (UITableViewCell *) tableView: (UITableView *)tableView
          cellForRowAtIndexPath: (NSIndexPath *)indexPath
{
#ifdef DEBUG
    NSLog(@"%s section:%ld, row:%ld", __FUNCTION__, indexPath.section, indexPath.row);
    static NSString *tableIdentifier = @"PrescriptionTableItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:tableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:tableIdentifier];
    }
    
    if (indexPath.section == 0)
        cell.textLabel.text = @"Doctor's name";
    else if (indexPath.section == 1)
        cell.textLabel.text = @"Patient's name";
    else {
        cell.textLabel.text = [tableData objectAtIndex:indexPath.row];
        //cell.imageView.image = [UIImage imageNamed:@"test.jpg"];
    }

    return cell;
#endif
}
@end
