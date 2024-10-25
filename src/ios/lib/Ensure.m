//
//  Ensure.m
//  CadenzaMobile
//
//  Created by developer on 07.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "Ensure.h"

@implementation Ensure

+ (void) ensureString:(NSObject*)arg {
    if(![arg isKindOfClass:[NSString class]]) {
        [NSException raise:@"Invalid argument" format:@"The argument %s must be a string.", arg];
    }
}

+ (void) ensureDictionary:(NSObject *)arg {
    if(![arg isKindOfClass:[NSDictionary class]] && ![arg isKindOfClass:[NSMutableDictionary class]]) {
        [NSException raise:@"Invalid argument" format:@"The argument %s must be a dictionary.", arg];
    }
}

@end
