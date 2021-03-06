/*
 
 Copyright (c) 2015 Max Lungarella <cybrmx@gmail.com>
 
 Created on 27/10/2015.
 
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

#import "MLUtility.h"

#import "MLConstants.h"

@implementation MLUtility

+ (int) checkVersion
{
    // Retrieve bundle root path, e.g. /var/mobile/Applications/<GUID>/<AppName>.app
    NSString *bundleRoot = [[NSBundle mainBundle] bundlePath];
    // Handle to file manager, initialize
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDictionary* attrs = [manager attributesOfItemAtPath:bundleRoot error:nil];
#ifdef DEBUG
    NSLog(@"App creation date: %@", [attrs fileCreationDate]);
    NSLog(@"App modification date (unless bundle changed by code): %@", [attrs fileModificationDate]);
#endif
    // e.g /var/mobile/Applications/<GUID>
    NSString *rootPath = [bundleRoot substringToIndex:[bundleRoot rangeOfString:@"/" options:NSBackwardsSearch].location];
    attrs = [manager attributesOfItemAtPath:rootPath error:nil];
#ifdef DEBUG
    NSLog(@"App installation date (or first reinstalled after deletion): %@", [attrs fileCreationDate]);
#endif
    
    return 0;
}

+ (NSNumber*) timeIntervalInSecondsSince1970:(NSDate *)date
{
    // Result in seconds
    NSNumber* timeInterval = [NSNumber numberWithDouble:[date timeIntervalSince1970]];
    return timeInterval;
}

+ (double) timeIntervalSinceLastDBSync
{
    double timeInterval = 0.0;
    
    if ([[MLConstants appLanguage] isEqualToString:@"de"]) {
        NSDate* lastUpdated = [[NSUserDefaults standardUserDefaults] objectForKey:@"germanDBLastUpdate"];
        if (lastUpdated!=nil)
            timeInterval = [[NSDate date] timeIntervalSinceDate:lastUpdated];
    }
    else if ([[MLConstants appLanguage] isEqualToString:@"fr"]) {
        NSDate* lastUpdated = [[NSUserDefaults standardUserDefaults] objectForKey:@"frenchDBLastUpdate"];
        if (lastUpdated!=nil)
            timeInterval = [[NSDate date] timeIntervalSinceDate:lastUpdated];
    }
    
    return timeInterval;
}

+ (NSString *) currentTime
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm.ss";
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    return [dateFormatter stringFromDate:[NSDate date]];
}

+ (NSString *) prettyTime
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"dd.MM.yyyy (HH:mm:ss)";
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    return [dateFormatter stringFromDate:[NSDate date]];
}

+ (NSString*) encodeStringToBase64:(NSString*)string
{
    NSData *plainData = [string dataUsingEncoding:NSUTF8StringEncoding];
    //return [plainData base64Encoding];
    return [plainData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
}

// Alternatively the implementation could also use NSHomeDirectory()
+ (NSString *) documentsDirectory
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
    // if you need to support iOS 7 or earlier
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    //NSLog(@"first:%@", [paths firstObject]);
    //NSLog(@"last:%@", [paths lastObject]);
    return [paths lastObject];
#else
    // iOS 8 and newer, this is the recommended method
    NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                        inDomains:NSUserDomainMask];
    NSURL *url = [paths lastObject];
    //NSLog(@"abs.: <%@>", url.absoluteString);   // "file:///Users/... ...Documents/"
    //NSLog(@"path: <%@>", url.path);             // "/Users/...  .../Documents"
    return url.path;
#endif
}

// Create the directory if it doesn't exist
+ (NSString *) amkBaseDirectory
{
    NSString *amk = [[MLUtility documentsDirectory] stringByAppendingPathComponent:@"amk"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:amk])
    {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:amk
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error) {
            NSLog(@"error creating directory: %@", error.localizedDescription);
            amk = nil;
        }
    }
    return amk;
}

+ (NSString *) amkDirectory
{
    NSString *amk = [MLUtility amkBaseDirectory];

    // If the current patient is defined in the defaults,
    // return his/her subdirectory
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *patientId = [defaults stringForKey:@"currentPatient"];
    if (patientId)
        return [MLUtility amkDirectoryForPatient:patientId];
    
    return amk;
}

+ (NSString *) amkDirectoryForPatient:(NSString*)uid
{
    NSString *amk = [MLUtility amkBaseDirectory];
    NSString *patientAmk = [amk stringByAppendingPathComponent:uid];
    if (![[NSFileManager defaultManager] fileExistsAtPath:patientAmk])
    {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:patientAmk
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error) {
            NSLog(@"error creating directory: %@", error.localizedDescription);
            patientAmk = nil;
        }
#ifdef DEBUG
        else
            NSLog(@"Created patient directory: %@", patientAmk);
#endif
    }
    
    return patientAmk;
}

@end
