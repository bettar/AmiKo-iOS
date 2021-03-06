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

#import "MLMedication.h"

@implementation MLMedication

@synthesize medId;
@synthesize customerId;
@synthesize title;
@synthesize auth;  // owner
@synthesize atccode;
@synthesize substances;
@synthesize regnrs;
@synthesize atcClass;
@synthesize therapy;
@synthesize application;
@synthesize indications;
@synthesize packInfo;        // all the packages, comma separated
@synthesize addInfo;
@synthesize sectionIds;
@synthesize sectionTitles;
@synthesize styleStr;
@synthesize contentStr;

@synthesize packages;

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ id:%ld, regnrs:%@ <%@>",
            NSStringFromClass([self class]), self.medId, self.regnrs, self.title];
}

@end
