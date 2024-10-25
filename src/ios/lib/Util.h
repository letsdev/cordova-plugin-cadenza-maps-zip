//
//  Util.h
//  CadenzaMobile
//
//  Created by developer on 08.08.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

@interface Util : NSObject

+ (void) gtmError: (NSString*) msg code: (int) code fullPath: (NSString *) path;

@end
