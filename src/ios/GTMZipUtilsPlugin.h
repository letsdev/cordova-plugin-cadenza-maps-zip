//
//  GTMZipUtilsPlugin.h
//  CadenzaMobile
//
//  Created by developer on 11.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>

@interface GTMZipUtilsPlugin : CDVPlugin {
    
    NSString* callbackID;
    
}

@property (nonatomic, copy) NSString* callbackID;

//Instance Method
-(void)unzip:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-(void)zip:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-(void)sendJsCallback: (NSString*)js;

@end
