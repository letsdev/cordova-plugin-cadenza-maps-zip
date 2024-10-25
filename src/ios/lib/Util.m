//
//  Util.m
//  CadenzaMobile
//
//  Created by developer on 08.08.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "Util.h"

@implementation Util

+(void)throwGTMException: (NSString*)message code:(int)code fullPath:(NSString*)fullPath methodName:methodName
{
    NSNumber *errorCode = [NSNumber numberWithInt:code];
    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:errorCode forKey:@"code"];
    [userInfo setObject:fullPath forKey:@"fullPath"];
    NSException *gtmException = [NSException exceptionWithName:methodName reason:message userInfo:userInfo];
    [gtmException raise];
}

+ (void) gtmError: (NSString*) msg code: (int) code fullPath: (NSString *) path
{
    //NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.unzipFile] Error untaring file: %@", [error localizedDescription]];
    //[self throwGTMException:exceptionMessage code:IO_EXCEPTION fullPath:archiveFileName methodName:@"GTMZipUtilsPlugin.unzipFile"];
    //ALog(msg)
    
}


@end
