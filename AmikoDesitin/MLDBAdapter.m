/*
 
 Copyright (c) 2013 Max Lungarella <cybrmx@gmail.com>
 
 Created on 11/08/2013.
 
 This file is part of AMiKoDesitin.
 
 AmiKoDesitin is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 
 ------------------------------------------------------------------------ */

#import "MLDBAdapter.h"

#import "MLSQLiteDatabase.h"
#import "MLConstants.h"

enum {
    kMedId = 0, kTitle, kAuth, kAtcCode, kSubstances, kRegnrs, kAtcClass, kTherapy, kApplication, kIndications, kCustomerId, kPackInfo, kPackages, kAddInfo, kIdsStr, kSectionsStr, kContentStr, kStyleStr
};

static NSString *KEY_ROWID = @"_id";
static NSString *KEY_TITLE = @"title";
static NSString *KEY_AUTH = @"auth";
static NSString *KEY_ATCCODE = @"atc";
static NSString *KEY_SUBSTANCES = @"substances";
static NSString *KEY_REGNRS = @"regnrs";
static NSString *KEY_ATCCLASS = @"atc_class";
static NSString *KEY_THERAPY = @"tindex_str";
static NSString *KEY_APPLICATION = @"application_str";
static NSString *KEY_INDICATIONS = @"indications_str";
static NSString *KEY_CUSTOMER_ID = @"customer_id";
static NSString *KEY_PACK_INFO = @"pack_info_str";
static NSString *KEY_ADDINFO = @"add_info_str";
static NSString *KEY_IDS = @"ids_str";
static NSString *KEY_SECTIONS = @"titles_str";
static NSString *KEY_CONTENT = @"content";
static NSString *KEY_STYLE = @"style_str";
static NSString *KEY_PACKAGES = @"packages";

static NSString *DATABASE_TABLE = @"amikodb";

/** Table columns used for fast queries
 */
static NSString *SHORT_TABLE = nil;
static NSString *FULL_TABLE = nil;


@implementation MLDBAdapter
{
    MLSQLiteDatabase *mySqliteDb;
    NSMutableDictionary *myDrugInteractionMap;
}

/** Class functions
 */
#pragma mark Class functions

+ (void) initialize
{
    if (self == [MLDBAdapter class]) {
        if (SHORT_TABLE == nil) {
            SHORT_TABLE = [[NSString alloc] initWithFormat:@"%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@",
                           KEY_ROWID, KEY_TITLE, KEY_AUTH, KEY_ATCCODE, KEY_SUBSTANCES, KEY_REGNRS, KEY_ATCCLASS, KEY_THERAPY, KEY_APPLICATION, KEY_INDICATIONS, KEY_CUSTOMER_ID, KEY_PACK_INFO, KEY_PACKAGES];
        }
        if (FULL_TABLE == nil) {
            FULL_TABLE = [[NSString alloc] initWithFormat:@"%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@",
                          KEY_ROWID, KEY_TITLE, KEY_AUTH, KEY_ATCCODE, KEY_SUBSTANCES, KEY_REGNRS, KEY_ATCCLASS, KEY_THERAPY, KEY_APPLICATION, KEY_INDICATIONS, KEY_CUSTOMER_ID, KEY_PACK_INFO, KEY_PACKAGES, KEY_ADDINFO, KEY_IDS, KEY_SECTIONS, KEY_CONTENT, KEY_STYLE];
        }
    }
}

/** Instance functions
 */
#pragma mark Instance functions

- (void) listDirectoriesAtPath:(NSString*)dir
{
    // List files in directory
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *fileList = [manager contentsOfDirectoryAtPath:dir error:nil];
    for (NSString *s in fileList){
        NSLog(@"%@",s);
    }
}

- (BOOL) openInteractionsCsvFile:(NSString *)name
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths lastObject];

    // [self listDirectoriesAtPath:documentsDir];
    
    // ** A. Check first users documents folder
    NSString *filePath = [[documentsDir stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"csv"];
    // Check if database exists
    if (filePath!=nil) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:filePath]) {
            NSLog(@"Drug interactions csv found documents folder - %@", filePath);
            return [self readDrugInteractionMap:filePath];
        }
    }
    
    // ** B. If no database is available, check if db is in app bundle
    filePath = [[NSBundle mainBundle] pathForResource:name ofType:@"csv"];
    if (filePath!=nil ) {
        NSLog(@"Drug interactions csv found in app bundle - %@", filePath);
        // Read drug interactions csv line after line
        return [self readDrugInteractionMap:filePath];
    }
    
    return FALSE;
}

- (void) closeInteractionsCsvFile
{
    if ([myDrugInteractionMap count]>0) {
        [myDrugInteractionMap removeAllObjects];
    }
}

- (BOOL) readDrugInteractionMap:(NSString *)filePath
{
    // Read drug interactions csv line after line
    NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    NSArray *rows = [content componentsSeparatedByString:@"\n"];
    myDrugInteractionMap = [[NSMutableDictionary alloc] init];
    /*
     token[0]: ATC-Code1
     token[1]: ATC-Code2
     token[2]: Html
     */
    for (NSString *s in rows) {
        if (![s isEqualToString:@""]) {
            NSArray *token = [s componentsSeparatedByString:@"||"];
            NSString *key = [NSString stringWithFormat:@"%@-%@", token[0], token[1]];
            [myDrugInteractionMap setObject:token[2] forKey:key];
        }
    }
    return TRUE;
}

- (NSInteger) getNumInteractions
{
    if (myDrugInteractionMap!=nil)
        return [myDrugInteractionMap count];
    
    return 0;
}

- (NSString *) getInteractionHtmlBetween:(NSString *)atc1 and:(NSString *)atc2
{
    if ([myDrugInteractionMap count]>0) {
        NSString *key = [NSString stringWithFormat:@"%@-%@", atc1, atc2];
        return [myDrugInteractionMap valueForKey:key];
    }
    return @"";
}

- (void) openDatabase
{
    NSString *filePath = nil;

    if ([APP_NAME isEqualToString:@"iAmiKo"] || [APP_NAME isEqualToString:@"AmiKoDesitin"])
        filePath = [[NSBundle mainBundle] pathForResource:@"amiko_db_full_idx_de" ofType:@"db"];
    else if ([APP_NAME isEqualToString:@"iCoMed"] || [APP_NAME isEqualToString:@"CoMedDesitin"])
        filePath = [[NSBundle mainBundle] pathForResource:@"amiko_db_full_idx_fr" ofType:@"db"];
    else
       filePath = [[NSBundle mainBundle] pathForResource:@"amiko_db_full_idx_de" ofType:@"db"];

    mySqliteDb = [[MLSQLiteDatabase alloc] initWithPath:filePath];
}

// Drugs database
- (BOOL) openDatabase: (NSString *)dbName
{
    // Check first users documents folder
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Get documents directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths lastObject];
    NSString *filePath = [[documentsDir stringByAppendingPathComponent:dbName] stringByAppendingPathExtension:@"db"];
    
    // Check if database exists
    if (filePath!=nil) {
        if ([fileManager fileExistsAtPath:filePath]) {
            mySqliteDb = [[MLSQLiteDatabase alloc] initWithPath:filePath];
            NSLog(@"Database found in documents folder - %@", filePath);
            return TRUE;
        }
    }
    
    // B. If no database is available, check if db is in app bundle
    filePath = [[NSBundle mainBundle] pathForResource:dbName ofType:@"db"];
    if (filePath!=nil ) {
        mySqliteDb = [[MLSQLiteDatabase alloc] initWithPath:filePath];
        NSLog(@"Database found in app bundle - %@", filePath);
        return TRUE;
    }
    
    return FALSE;
}

- (void) closeDatabase
{
    if (mySqliteDb)
        [mySqliteDb close];
}

- (NSInteger) getNumRecords
{
    NSInteger numRecords = [mySqliteDb numberRecordsForTable:DATABASE_TABLE];
    
    return numRecords;
}

- (NSArray *) getRecord: (long)rowId
{
    NSString *query = [NSString stringWithFormat:@"select %@ from %@ where %@=%ld",
                       FULL_TABLE, DATABASE_TABLE, KEY_ROWID, rowId];
    //NSArray *results = [mySqliteDb performQuery:query];
    
    return [mySqliteDb performQuery:query];
}

- (MLMedication *) searchId: (long)rowId
{
    // getRecord returns an NSArray* hence the objectAtIndex  
    return [self cursorToFullMedInfo:[[self getRecord:rowId] objectAtIndex:0]];
}

- (NSArray *) searchWithQuery: (NSString *)query;
{
    return [mySqliteDb performQuery:query];
}

/** Search Präparat
 */
- (NSArray *) searchTitle: (NSString *)title
{
    NSString *query = [NSString stringWithFormat:@"select %@ from %@ where %@ like '%@%%'",
                       SHORT_TABLE, DATABASE_TABLE, KEY_TITLE, title];
    NSArray *results = [mySqliteDb performQuery:query];
    
    return [self extractShortMedInfoFrom:results];
}

/** Search Inhaber
 */
- (NSArray *) searchAuthor: (NSString *)author
{
    NSString *query = [NSString stringWithFormat:@"select %@ from %@ where %@ like '%@%%'",
                       SHORT_TABLE, DATABASE_TABLE, KEY_AUTH, author];
    NSArray *results = [mySqliteDb performQuery:query];
    
    return [self extractShortMedInfoFrom:results];
}

/** Search ATC Code
 */
- (NSArray *) searchATCCode: (NSString *)atccode
{
    NSString *query = [NSString stringWithFormat:@"select %@ from %@ where %@ like '%%;%@%%' or %@ like '%@%%' or %@ like '%% %@%%' or %@ like '%%%@%%' or %@ like '%%;%%%@%%'",
                       SHORT_TABLE, DATABASE_TABLE, KEY_ATCCODE, atccode, KEY_ATCCODE, atccode, KEY_ATCCODE, atccode, KEY_ATCCLASS, atccode, KEY_ATCCLASS, atccode];
    NSArray *results = [mySqliteDb performQuery:query];
    
    return [self extractShortMedInfoFrom:results];
}

/** Search Reg. Nr.
 */
- (NSArray *) searchIngredients: (NSString *)ingredients
{
    NSString *query = [NSString stringWithFormat:@"select %@ from %@ where %@ like '%%, %@%%' or %@ like '%@%%' or %@ like '%%-%@%%'",
                       SHORT_TABLE, DATABASE_TABLE, KEY_SUBSTANCES, ingredients, KEY_SUBSTANCES, ingredients, KEY_SUBSTANCES, ingredients];
    NSArray *results = [mySqliteDb performQuery:query];
    
    return [self extractShortMedInfoFrom:results];
}

/** Search Wirkstoff
 */
- (NSArray *) searchRegNr: (NSString *)regnr
{
    NSString *query = [NSString stringWithFormat:@"select %@ from %@ where %@ like '%%, %@%%' or %@ like '%@%%'",
                       SHORT_TABLE, DATABASE_TABLE, KEY_REGNRS, regnr, KEY_REGNRS, regnr];
    NSArray *results = [mySqliteDb performQuery:query];
    
    return [self extractShortMedInfoFrom:results];
}

/** Search Therapie
 */
- (NSArray *) searchTherapy: (NSString *)therapy
{
    NSString *query = [NSString stringWithFormat:@"select %@ from %@ where %@ like '%%, %@%%' or %@ like '%@%%' or %@ like '%% %@%%'",
                       SHORT_TABLE, DATABASE_TABLE, KEY_THERAPY, therapy, KEY_THERAPY, therapy, KEY_THERAPY, therapy];
    NSArray *results = [mySqliteDb performQuery:query];

    return [self extractShortMedInfoFrom:results];
}

/** Search Application
 */
- (NSArray *) searchApplication: (NSString *)application
{
    NSString *query = [NSString stringWithFormat:@"select %@ from %@ where %@ like '%%, %@%%' or %@ like '%@%%' or %@ like '%% %@%%' or %@ like '%%;%@%%' or %@ like '%@%%' or %@ like '%%;%@%%'",
                       SHORT_TABLE, DATABASE_TABLE, KEY_APPLICATION, application, KEY_APPLICATION, application, KEY_APPLICATION, application, KEY_APPLICATION, application, KEY_INDICATIONS, application, KEY_INDICATIONS, application];
    NSArray *results = [mySqliteDb performQuery:query];
    
    return [self extractShortMedInfoFrom:results];
}
- (MLMedication *) cursorToShortMedInfo: (NSArray *)cursor
{
    MLMedication *m = [[MLMedication alloc] init];
        
    [m setMedId:[(NSString *)[cursor objectAtIndex:kMedId] longLongValue]];
    [m setTitle:(NSString *)[cursor objectAtIndex:kTitle]];
    [m setAuth:(NSString *)[cursor objectAtIndex:kAuth]];
    [m setAtccode:(NSString *)[cursor objectAtIndex:kAtcCode]];
    [m setSubstances:(NSString *)[cursor objectAtIndex:kSubstances]];
    [m setRegnrs:(NSString *)[cursor objectAtIndex:kRegnrs]];
    [m setAtcClass:(NSString *)[cursor objectAtIndex:kAtcClass]];
    [m setTherapy:(NSString *)[cursor objectAtIndex:kTherapy]];
    [m setApplication:(NSString *)[cursor objectAtIndex:kApplication]];
    [m setIndications:(NSString *)[cursor objectAtIndex:kIndications]];
    [m setCustomerId:[(NSString *)[cursor objectAtIndex:kCustomerId] intValue]];
    [m setPackInfo:(NSString *)[cursor objectAtIndex:kPackInfo]];
    
    return m;
}

- (MLMedication *) cursorToFullMedInfo: (NSArray *)cursor
{
    MLMedication *m = [[MLMedication alloc] init];
    
    [m setMedId:[(NSString *)[cursor objectAtIndex:kMedId] longLongValue]];
    [m setTitle:(NSString *)[cursor objectAtIndex:kTitle]];
    [m setAuth:(NSString *)[cursor objectAtIndex:kAuth]];
    [m setAtccode:(NSString *)[cursor objectAtIndex:kAtcCode]];
    [m setSubstances:(NSString *)[cursor objectAtIndex:kSubstances]];
    [m setRegnrs:(NSString *)[cursor objectAtIndex:kRegnrs]];
    [m setAtcClass:(NSString *)[cursor objectAtIndex:kAtcClass]];
    [m setTherapy:(NSString *)[cursor objectAtIndex:kTherapy]];
    [m setApplication:(NSString *)[cursor objectAtIndex:kApplication]];
    [m setIndications:(NSString *)[cursor objectAtIndex:kIndications]];
    [m setCustomerId:[(NSString *)[cursor objectAtIndex:kCustomerId] intValue]];
    [m setPackInfo:(NSString *)[cursor objectAtIndex:kPackInfo]];
    [m setPackages:(NSString *)[cursor objectAtIndex:kPackages]];

    [m setAddInfo:(NSString *)[cursor objectAtIndex:kAddInfo]];
    [m setSectionIds:(NSString *)[cursor objectAtIndex:kIdsStr]];
    [m setSectionTitles:(NSString *)[cursor objectAtIndex:kSectionsStr]];
    [m setContentStr:(NSString *)[cursor objectAtIndex:kContentStr]];
    [m setStyleStr:(NSString *)[cursor objectAtIndex:kStyleStr]];
    
    return m;
}

- (NSArray *) extractShortMedInfoFrom: (NSArray *)results
{
    NSMutableArray *medList = [NSMutableArray array];

    for (NSArray *cursor in results) {
        MLMedication *m = [[MLMedication alloc] init];
        
        [m setMedId:[(NSString *)[cursor objectAtIndex:kMedId] longLongValue]];
        [m setTitle:(NSString *)[cursor objectAtIndex:kTitle]];
        [m setAuth:(NSString *)[cursor objectAtIndex:kAuth]];
        [m setAtccode:(NSString *)[cursor objectAtIndex:kAtcCode]];
        [m setSubstances:(NSString *)[cursor objectAtIndex:kSubstances]];
        [m setRegnrs:(NSString *)[cursor objectAtIndex:kRegnrs]];
        [m setAtcClass:(NSString *)[cursor objectAtIndex:kAtcClass]];
        [m setTherapy:(NSString *)[cursor objectAtIndex:kTherapy]];
        [m setApplication:(NSString *)[cursor objectAtIndex:kApplication]];
        [m setIndications:(NSString *)[cursor objectAtIndex:kIndications]];
        [m setCustomerId:[(NSString *)[cursor objectAtIndex:kCustomerId] intValue]];
        [m setPackInfo:(NSString *)[cursor objectAtIndex:kPackInfo]];
        [m setPackages:(NSString *)[cursor objectAtIndex:kPackages]];
        
        [medList addObject:m];
    }
    
    return medList;
}

- (NSArray *) extractFullMedInfoFrom: (NSArray *)results;
{
    NSMutableArray *medList = [NSMutableArray array];
    
    for (NSArray *cursor in results) {
        MLMedication *m = [[MLMedication alloc] init];
        
        [m setMedId:[(NSString *)[cursor objectAtIndex:kMedId] longLongValue]];
        [m setTitle:(NSString *)[cursor objectAtIndex:kTitle]];
        [m setAuth:(NSString *)[cursor objectAtIndex:kAuth]];
        [m setAtccode:(NSString *)[cursor objectAtIndex:kAtcCode]];
        [m setSubstances:(NSString *)[cursor objectAtIndex:kSubstances]];
        [m setRegnrs:(NSString *)[cursor objectAtIndex:kRegnrs]];
        [m setAtcClass:(NSString *)[cursor objectAtIndex:kAtcClass]];
        [m setTherapy:(NSString *)[cursor objectAtIndex:kTherapy]];
        [m setApplication:(NSString *)[cursor objectAtIndex:kApplication]];
        [m setIndications:(NSString *)[cursor objectAtIndex:kIndications]];        
        [m setCustomerId:[(NSString *)[cursor objectAtIndex:kCustomerId] intValue]];
        [m setPackInfo:(NSString *)[cursor objectAtIndex:kPackInfo]];
        [m setPackages:(NSString *)[cursor objectAtIndex:kPackages]];

        [m setAddInfo:(NSString *)[cursor objectAtIndex:kAddInfo]];
        [m setSectionIds:(NSString *)[cursor objectAtIndex:kIdsStr]];
        [m setSectionTitles:(NSString *)[cursor objectAtIndex:kSectionsStr]];
        [m setContentStr:(NSString *)[cursor objectAtIndex:kContentStr]];
        [m setStyleStr:(NSString *)[cursor objectAtIndex:kStyleStr]];
        
        [medList addObject:m];
    }
    
    return medList;
}

@end
