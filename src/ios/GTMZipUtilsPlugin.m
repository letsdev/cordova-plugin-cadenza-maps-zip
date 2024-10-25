//
//  GTMZipUtilsPlugin.m
//  CadenzaMobile
//
//  Created by developer on 11.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

// TODO_NOW ks 21.08.2012: Methoden-Namen ändern:
// Im Moment heisst alles nur *zip*, mit dem integrierten TAR ist das nicht mehr korrekt
/*
 #import "GTMZipUtilsPlugin.h"

 #import "Ensure.h"

 #import "ZipFile.h"
 #import "ZipException.h"
 #import "FileInZipInfo.h"
 #import "ZipReadStream.h"
 #import "ZipWriteStream.h"

 #import "NSFileManager+Tar.h"
 */
#import "GTMZipUtilsPlugin.h"

#import "Ensure.h"

#import "ZipFile.h"
#import "ZipException.h"
#import "FileInZipInfo.h"
#import "ZipReadStream.h"
#import "ZipWriteStream.h"

#import "NSFileManager+Tar.h"

int const ARCHIVE_FILE_DOES_NOT_EXIST = 1;
int const DESTINATION_DIRECTORY_EXISTS = 2;
int const DIRECTORY_COULD_NOT_BE_DELETED = 3;
int const DIRECTORY_COULD_NOT_BE_CREATED = 4;
int const IO_EXCEPTION = 5;
int const INVALID_ARGUMENT_EXCEPTION = 6;
int const JSON_EXCEPTION = 7;
int const ARCHIVE_FILE_EXISTS = 8;
int const TEMPORARY_FILE_COULD_NOT_BE_DELETED = 9;
int const SOURCE_DIRECTORY_DOES_NOT_EXIST = 10;
int const COULD_NOT_MOVE = 11;

@implementation GTMZipUtilsPlugin

@synthesize callbackID;

-(BOOL)directoryExistsAtAbsolutePath:(NSString*)filename {
    BOOL isDirectory;
    BOOL fileExistsAtPath = [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDirectory];

    return fileExistsAtPath && isDirectory;
}

-(void)closeQuietly:(ZipReadStream*)stream data:(NSMutableData*)data
{
    if (stream != nil) {
        [stream finishedReading];
    }

    [data release];
}

-(void)throwGTMException: (NSString*)message code:(int)code fullPath:(NSString*)fullPath methodName:methodName
{
    NSNumber *errorCode = [NSNumber numberWithInt:code];
    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:errorCode forKey:@"code"];
    [userInfo setObject:fullPath forKey:@"fullPath"];
    NSException *gtmException = [NSException exceptionWithName:methodName reason:message userInfo:userInfo];
    [gtmException raise];
}

-(int) addDirectoryFilesIntoZip: (NSString*) sourceDirectory actualDirectory:(NSString*) actualDirectory zipFile:(ZipFile*) zipFile
{
    NSError *error;
    int numberOfCompressedFiles = 0;

    NSString* pathToSearch = [sourceDirectory stringByAppendingString:actualDirectory];

    NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pathToSearch error:&error];
    ZipWriteStream *stream = nil;
    @try {
        for (NSString *file in directoryContents) {
            NSAutoreleasePool *releasePool = [[NSAutoreleasePool alloc] init];

            NSString* relativePath = [actualDirectory stringByAppendingString:@"/"];
            relativePath = [relativePath stringByAppendingString:file];
            NSString* absolutePath = [sourceDirectory stringByAppendingString:relativePath];
            NSLog(@"Relative Path: %@", relativePath);
            NSLog(@"Absolute Path: %@", absolutePath);

            if ([self directoryExistsAtAbsolutePath:absolutePath]){
                numberOfCompressedFiles += [self addDirectoryFilesIntoZip:sourceDirectory actualDirectory:relativePath zipFile:zipFile];
            }
            else {
                NSString * relativePathWithoutTrailingSlash = [relativePath substringFromIndex:1];
                stream= [zipFile writeFileInZipWithName:relativePathWithoutTrailingSlash compressionLevel:ZipCompressionLevelNone];
                [stream writeData:[NSData dataWithContentsOfFile:absolutePath]];
                [stream finishedWriting];
                NSLog(@"ADDED FILE Absolute Path: %@", absolutePath);
                numberOfCompressedFiles++;
            }
            [releasePool drain];
        }
        return numberOfCompressedFiles;
    }
    @catch (ZipException *e) {
        NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.addDirectoryFilesIntoZip] Adding files into ZIP from [%@] failed.", sourceDirectory];
        [self throwGTMException:exceptionMessage code:IO_EXCEPTION fullPath:sourceDirectory methodName:@"GTMZipUtilsPlugin.addDirectoryFilesIntoZip"];
    }
    @finally {
        /*
         if (stream != nil) {
         @try {
         [stream finishedWriting];
         }
         @catch (ZipException *zex) {
         //do nothing
         }
         }
         */
    }
}

-(NSNumber *)zipDirectory: (NSString*)sourceDirectory tempFile:(NSString*)tempFile
{
    int numberOfCompressedFiles = 0;
    ZipFile *zipFile = nil;
    @try {
        ZipFile *zipFile= [[[ZipFile alloc] initWithFileName:tempFile mode:ZipFileModeCreate] autorelease];
        numberOfCompressedFiles += [self addDirectoryFilesIntoZip:sourceDirectory actualDirectory:@"" zipFile:zipFile];
        [zipFile close];
        NSLog(@"[GTMZipUtilsPlugin.zipDirectory] Added %d files to the new zipFile: %@", numberOfCompressedFiles, tempFile);
        return [NSNumber numberWithInt:numberOfCompressedFiles];
    }
    @catch (ZipException *exception) {
        NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.zipDirectory] Creating a ZIP from the directory [%@] failed.", sourceDirectory];
        [self throwGTMException:exceptionMessage code:IO_EXCEPTION fullPath:sourceDirectory methodName:@"GTMZipUtilsPlugin.zipDirectory"];

    }
    @finally {
        if(zipFile != nil) {
            @try {
                [zipFile close];
            }
            @catch (ZipException *e) {
                //do nothing
            }
        }
    }
}

-(void)sendJsCallback: (NSString*)js
{
    [self.commandDelegate evalJs:js];
}


-(NSNumber *)unzipFile: (NSString*)archiveFile tempDirectoryName:(NSString*)tempDirectoryName
{
    NSLog(@"[GTMZipUtilsPlugin.unzipFile] archiveFile: %@", archiveFile);
    NSLog(@"[GTMZipUtilsPlugin.unzipFile] tempDirectoryName: %@", tempDirectoryName);

    NSFileManager *fileMgr = [NSFileManager defaultManager];
    __block int countExtractedFiles = 0;

    ZipFile *fileToUnzip= [[ZipFile alloc] initWithFileName:archiveFile mode:ZipFileModeUnzip];
    //NSString *pathToSaveTemp = [tempDirectoryName stringByAppendingString:@"/"];

    if (fileToUnzip==nil){
        NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.unzipFile] The archive file [%@] cannot be opened.", archiveFile];
        [self throwGTMException:exceptionMessage code:IO_EXCEPTION fullPath:archiveFile methodName:@"GTMZipUtilsPlugin.unzipFile"];
    }

    // Open the zip file
    [fileToUnzip goToFirstFileInZip];

    int numFilesInZip = [fileToUnzip numFilesInZip];
    BOOL continueReading = YES;
    NSError *errorw;
    ZipReadStream *stream = nil;
    NSMutableData *data = nil;
    NSError *error = nil;
    FileInZipInfo *info = nil;
    static const NSUInteger BATCH_SIZE_REALEASE_POOL = 10;

    __block int percentageActualFile = -1;
    __block int oldPercentageActualFile = -1;
    NSAutoreleasePool *releasePool = [[NSAutoreleasePool alloc] init];
    // do something you want to measure
    CFAbsoluteTime oldTime = CFAbsoluteTimeGetCurrent();
    @try {
        while (continueReading) {
            //NSAutoreleasePool *releasePool = [[NSAutoreleasePool alloc] init];
            // Get file info
            info = [fileToUnzip getCurrentFileInZipInfo];
            //NSLog(@"[GTMZipUtilsPlugin.unzipFile] Extract file: %@", info.name);

            NSString *pathToSaveTemp = [tempDirectoryName stringByAppendingString:@"/"];
            NSString *pathToSave = [pathToSaveTemp stringByAppendingString:info.name];

            //NSLog(@"[GTMZipUtilsPlugin.unzipFile] Path to save: %@", pathToSave);

            NSString *pathToCreate = [pathToSave stringByDeletingLastPathComponent];

            if (![fileMgr createDirectoryAtPath:pathToCreate withIntermediateDirectories:YES attributes:nil error:&errorw ]){
                NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.unzipFile] Creating the directory [%@] failed.", pathToCreate];
                [self throwGTMException:exceptionMessage code:IO_EXCEPTION fullPath:archiveFile methodName:@"GTMZipUtilsPlugin.unzipFile"];
            }
            if (![pathToSave hasSuffix:@"/"] ){
                // Read data into buffer
                stream = [fileToUnzip readCurrentFileInZip];
                data = [[NSMutableData alloc] initWithLength:info.length];
                [stream readDataWithBuffer:data];

                // Save data to file
                [data writeToFile:pathToSave options:NSDataWritingAtomic error:&error];
                if (error) {
                    NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.unzipFile] Error unzipping file: %@", [error localizedDescription]];
                    [self throwGTMException:exceptionMessage code:IO_EXCEPTION fullPath:archiveFile methodName:@"GTMZipUtilsPlugin.unzipFile"];
                }

                [data release];
            } else {
                NSLog(@"[GTMZipUtilsPlugin.unzipFile] Extract directory: %@", info.name);
            }

            if(countExtractedFiles % BATCH_SIZE_REALEASE_POOL == 0)
            {
                [releasePool drain];
                releasePool = [[NSAutoreleasePool alloc] init];
            }

            countExtractedFiles++;

            percentageActualFile = (int) ((float) ((float) countExtractedFiles / (float) numFilesInZip) * 100);

            CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();

            if (percentageActualFile-oldPercentageActualFile>=1 && currentTime - oldTime > 1){
                oldTime = currentTime;
                oldPercentageActualFile = percentageActualFile;
                dispatch_async(dispatch_get_main_queue(),^{
                    NSString *updateUiJs = [NSString stringWithFormat:@"var event = document.createEvent(\'CustomEvent\');event.initCustomEvent(\'progressUpdate\', true, true, {filename:\'%@\', progress:\'%@\', title: \'Karte importieren\'});document.dispatchEvent(event);", [archiveFile lastPathComponent], [NSNumber numberWithInt:percentageActualFile]];
                    //[self writeJavascript:updateUiJs];
                    [self.commandDelegate evalJs:updateUiJs];
                });
            }

            // Check if we should continue reading
            continueReading = [fileToUnzip goToNextFileInZip];
        }
    }
    @catch (ZipException *e) {
        NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.unzipFile] Unzipping files on [%@] failed.", archiveFile];
        [self throwGTMException:exceptionMessage code:IO_EXCEPTION fullPath:archiveFile methodName:@"GTMZipUtilsPlugin.unzipFile"];
    }
    @finally {
        [fileToUnzip close];
        //[self closeQuietly:stream data:data];
        [releasePool drain];
    }
    NSNumber *extractedFileCount = [NSNumber numberWithInt:countExtractedFiles];
    NSLog(@"[GTMZipUtilsPlugin.unzipFile] Unzipping of %@ files completed.", extractedFileCount);

    [fileToUnzip release];
    //[fileMgr release];
    return extractedFileCount;
}



// -(void)unzip:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
- (void)unzip:(CDVInvokedUrlCommand*)command
{
    self.callbackID = command.callbackId;
    NSArray *arguments = command.arguments;
    NSDictionary *options = [arguments objectAtIndex:0];
    NSLog(@"NSDictionary options: %@", options);


    // The first argument in the arguments parameter is the callbackID.
    // We use this to send data back to the successCallback or failureCallback
    // through PluginResult.
//    self.callbackID = [arguments pop];

    NSString* selfCallbackID = self.callbackID;

    @try {
        __block NSError *error;

        [Ensure ensureString:[arguments objectAtIndex:0]];
        [Ensure ensureString:[arguments objectAtIndex:1]];
        [Ensure ensureString:[arguments objectAtIndex:2]];

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectoryPath = paths[0];

        NSString *archivePath = [arguments objectAtIndex:0];
        NSString *archiveFileName = @"";
        if ([archivePath containsString:@"file://"]) {
            archiveFileName = [archivePath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        } else {
            archiveFileName = [NSString stringWithFormat:@"%@/%@", documentsDirectoryPath, archivePath];
        }
        NSLog(@"archive: %@", archiveFileName);


        NSString *destinationPath = [arguments objectAtIndex:1];
        NSString *destinationDirectoryName = @"";
        if ([destinationPath containsString:@"file://"]) {
            destinationDirectoryName = [destinationPath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        } else {
            destinationDirectoryName = [NSString stringWithFormat:@"%@/%@", documentsDirectoryPath, destinationPath];
        }
        NSLog(@"dest: %@", destinationDirectoryName);

        NSString *tempPath = [arguments objectAtIndex:2];
        NSString *tempDirectoryName = @"";
        if ([tempPath containsString:@"file://"]) {
            tempDirectoryName = [tempPath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        } else {
            tempDirectoryName = [NSString stringWithFormat:@"%@/%@", documentsDirectoryPath, tempPath];
        }
        NSLog(@"temp: %@", tempDirectoryName);

        if (![[NSFileManager defaultManager] fileExistsAtPath:archiveFileName]){
            NSLog(@"[GTMZipUtilsPlugin.unzip] Archive file does not exist: %@", archiveFileName);
            NSString *exceptionMessage = [NSString stringWithFormat:@"The archive file [%@] does not exists.", archiveFileName];
            [self throwGTMException:exceptionMessage code:ARCHIVE_FILE_DOES_NOT_EXIST fullPath:archiveFileName methodName:@"GTMZipUtilsPlugin.unzip"];
        } else {
            NSLog(@"[GTMZipUtilsPlugin.unzip] Archive file exists: %@", archiveFileName);
        }

        if ([[NSFileManager defaultManager] fileExistsAtPath:destinationDirectoryName]){
            NSLog(@"[GTMZipUtilsPlugin.unzip] The destination directory [%@] already exists.", destinationDirectoryName);
            NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.unzip] The destination directory [%@] already exists.", destinationDirectoryName];
            [self throwGTMException:exceptionMessage code:DESTINATION_DIRECTORY_EXISTS fullPath:destinationDirectoryName methodName:@"GTMZipUtilsPlugin.unzip"];
        } else {
            NSLog(@"[GTMZipUtilsPlugin.unzip] The destination directory [%@] does not exist.", destinationDirectoryName);
        }

        if ([[NSFileManager defaultManager] fileExistsAtPath:tempDirectoryName])    //Does directory exist?
        {
            if (![[NSFileManager defaultManager] removeItemAtPath:tempDirectoryName error:&error])  //Delete it
            {
                NSLog(@"[GTMZipUtilsPlugin.unzip] The temporary directory [%@] could not be deleted.", tempDirectoryName);
                NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.unzip] The temporary directory [%@] could not be deleted.", tempDirectoryName];
                [self throwGTMException:exceptionMessage code:DIRECTORY_COULD_NOT_BE_DELETED fullPath:tempDirectoryName methodName:@"GTMZipUtilsPlugin.unzip"];
            } else {
                NSLog(@"[GTMZipUtilsPlugin.unzip] The temporary directory [%@] was deleted.", tempDirectoryName);
            }
        } else {
            NSLog(@"[GTMZipUtilsPlugin.unzip] The temporary directory [%@] didn't exist. No deletion occured.", tempDirectoryName);
        }

        if ([[NSFileManager defaultManager] createDirectoryAtPath:tempDirectoryName
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error])
        {
            NSLog(@"[GTMZipUtilsPlugin.unzip] Created temporary directory: %@", tempDirectoryName);
        } else {
            NSLog(@"[GTMZipUtilsPlugin.unzip] Create directory error: %@", error);

            NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.unzip] The temporary directory [%@] could not be created.", tempDirectoryName];
            [self throwGTMException:exceptionMessage code:DIRECTORY_COULD_NOT_BE_CREATED fullPath:tempDirectoryName methodName:@"GTMZipUtilsPlugin.unzip"];

        }

        NSLog(@"[GTMZipUtilsPlugin.unzip] GTMZipUtilsPlugin - Extracting archive file.");

        // Temporary, was nil
        //__block NSNumber *extractedFileCount = [NSNumber numberWithInt:0];
        __block NSNumber *extractedFileCount = nil;

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
            @try {
                //Look at magic numbers for TAR and ZIP/ZIP64 files at http://www.astro.keele.ac.uk/oldusers/rno/Computing/File_magic.html
                // Magic numbers in ZIP/ZIP64 files start with an offset of 0 bytes with 4 bytes length
                // Magic numbers in TAR files (POSIX) start with an offset of 257 bytes with 5 bytes length
                NSFileHandle *fileToReadSeveralBytes = [NSFileHandle fileHandleForReadingAtPath:archiveFileName];
                // First read 4 bytes to look for the magic numbers of ZIP/ZIP64 files
                // Base64 of "50 4B 03 04" / "PK..""
                if ([[[fileToReadSeveralBytes readDataOfLength:4] base64EncodedStringWithOptions:0] isEqualToString:@"UEsDBA=="]){
                    //NSLog(@"FOUND A ZIP/ZIP64 CMMAP-FILE");
                    extractedFileCount = [self unzipFile:archiveFileName tempDirectoryName:tempDirectoryName];
                } else {
                    // 4 bytes read before, so read 253 bytes to get the right position to read the magic numbers of TAR files
                    [fileToReadSeveralBytes readDataOfLength:253];

                    // Now read 5 bytes to look for the magic numbers of TAR (POSIX) files
                    // Base64 encoded "ustar"
                    NSData* tarMagicNumber = [fileToReadSeveralBytes readDataOfLength:5];
                    if ([[tarMagicNumber base64EncodedStringWithOptions:0] isEqualToString:@"dXN0YXI="]){
                        //NSLog(@"FOUND A TAR(POSIX) CMMAP-FILE");
                        BOOL success = [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:tempDirectoryName filename:[archiveFileName lastPathComponent] withTarPath:archiveFileName fileCount:&extractedFileCount error:&error plugin:self];
                        if (!success) {
                            NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.unzipFile] Error untaring file."];
                            [self throwGTMException:exceptionMessage code:IO_EXCEPTION fullPath:archiveFileName methodName:@"GTMZipUtilsPlugin.unzipFile"];
                        }
                    }
                    else {
                        NSLog(@"FOUND A NON-CONFORM CMMAP-FILE");
                        NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.unzipFile] THIS FILE FORMAT IS NOT SUPPORTED"];
                        [self throwGTMException:exceptionMessage code:IO_EXCEPTION fullPath:archiveFileName methodName:@"GTMZipUtilsPlugin.unzipFile"];
                    }
                }

                NSLog(@"[GTMZipUtilsPlugin.unzip] GTMZipUtilsPlugin - Extracted %@ files from archive file %@.", extractedFileCount, archiveFileName);


                if (![[NSFileManager defaultManager] moveItemAtPath:tempDirectoryName toPath:destinationDirectoryName error:&error]){
                    NSLog(@"[GTMZipUtilsPlugin.unzip] Moving old path %@ to new path %@ failed.", tempDirectoryName, destinationDirectoryName);

                    NSString *exceptionMessage = [NSString stringWithFormat:@"Moving old path %@ to new path %@ failed.", tempDirectoryName, destinationDirectoryName];
                    [self throwGTMException:exceptionMessage code:COULD_NOT_MOVE fullPath:destinationDirectoryName methodName:@"GTMZipUtilsPlugin.unzip"];
                } else {
                    NSLog(@"[GTMZipUtilsPlugin.unzip] Moving old path %@ to new path %@ was successful.", tempDirectoryName, destinationDirectoryName);
                }

                NSMutableDictionary* result = [[NSMutableDictionary alloc] init];

                [result setObject:extractedFileCount forKey:@"extractedFileCount"];
                [result setObject:archiveFileName forKey:@"archiveFileName"];
                [result setObject:destinationDirectoryName forKey:@"destinationDirectoryName"];

                // Create Plugin Result
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];

                dispatch_async(dispatch_get_main_queue(),^{
                    //[self writeJavascript: [pluginResult toSuccessCallbackString:selfCallbackID]];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:selfCallbackID];
                });
            }
            @catch (NSException *e){
                NSMutableDictionary* messageDictionary = [[NSMutableDictionary alloc] init];

                NSString *message = e.reason;
                NSNumber *code = [e.userInfo valueForKey:@"code"];
                NSString *fullPath = [e.userInfo valueForKey:@"fullPath"];
                NSLog(@"[GTMZipUtilsPlugin.unzip] Catched an exception: %@ , code: %@, fullPath: %@",message, code, fullPath);

                [messageDictionary setObject:message forKey:@"message"];
                [messageDictionary setObject:code forKey:@"code"];
                [messageDictionary setObject:fullPath forKey:@"fullPath"];
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:messageDictionary];
                dispatch_async(dispatch_get_main_queue(),^{
                    //[self writeJavascript: [pluginResult toErrorCallbackString:selfCallbackID]];
                    //[self.commandDelegate evalJs:[pluginResult toErrorCallbackString:selfCallbackID]];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:selfCallbackID];
                });
            }
        });
    }
    @catch (NSException *e){
        NSMutableDictionary* messageDictionary = [[NSMutableDictionary alloc] init];

        NSString *message = e.reason;
        NSNumber *code = [e.userInfo valueForKey:@"code"];
        NSString *fullPath = [e.userInfo valueForKey:@"fullPath"];
        NSLog(@"[GTMZipUtilsPlugin.unzip] Catched an exception: %@ , code: %@, fullPath: %@",message, code, fullPath);

        [messageDictionary setObject:message forKey:@"message"];
        [messageDictionary setObject:code forKey:@"code"];
        [messageDictionary setObject:fullPath forKey:@"fullPath"];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:messageDictionary];
        //[self writeJavascript: [pluginResult toErrorCallbackString:selfCallbackID]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:selfCallbackID];
    }

}

// -(void)zip:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
- (void)zip:(CDVInvokedUrlCommand*)command
{
    self.callbackID = command.callbackId;
    NSArray *arguments = command.arguments;

    NSDictionary *options = [arguments objectAtIndex:0];

    @try {
        NSError *error;
        // The first argument in the arguments parameter is the callbackID.
        // We use this to send data back to the successCallback or failureCallback
        // through PluginResult.
        // self.callbackID = [arguments pop];

        [Ensure ensureString:[arguments objectAtIndex:0]];
        [Ensure ensureString:[arguments objectAtIndex:1]];
        [Ensure ensureString:[arguments objectAtIndex:2]];

        // Get the string that javascript sent us
//        NSString *sourceDirectoryName = [arguments objectAtIndex:0];
//        NSString *archiveFileName = [arguments objectAtIndex:1];
//        NSString *tempFileName = [arguments objectAtIndex:2];

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectoryPath = paths[0];
        //         NSString *baumkataster = @"baumkataster_ortsbegehung.cmmap";
        NSLog(@"doc dir path: %@", documentsDirectoryPath);
        NSString *sourceDirectoryName = [NSString stringWithFormat:@"%@/%@", documentsDirectoryPath, [arguments objectAtIndex:0]];
        NSString *archiveFileName = [NSString stringWithFormat:@"%@/%@", documentsDirectoryPath, [arguments objectAtIndex:1]];
        NSString *tempFileName = [NSString stringWithFormat:@"%@/%@", documentsDirectoryPath, [arguments objectAtIndex:2]];


        if (!([[NSFileManager defaultManager] fileExistsAtPath:sourceDirectoryName])){
            NSLog(@"[GTMZipUtilsPlugin.zip] The source directory [%@] does not exist.", sourceDirectoryName);
            NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.zip] The source directory [%@] does not exist.", sourceDirectoryName];
            [self throwGTMException:exceptionMessage code:SOURCE_DIRECTORY_DOES_NOT_EXIST fullPath:sourceDirectoryName methodName:@"GTMZipUtilsPlugin.zip"];
        } else {
            NSLog(@"[GTMZipUtilsPlugin.zip] The source directory [%@] exists.", sourceDirectoryName);
        }

        if ([[NSFileManager defaultManager] fileExistsAtPath:archiveFileName]){
            NSLog(@"[GTMZipUtilsPlugin.zip] Archive file already exists: %@", archiveFileName);
            NSString *exceptionMessage = [NSString stringWithFormat:@"The archive file [%@] already exists.", archiveFileName];
            [self throwGTMException:exceptionMessage code:ARCHIVE_FILE_EXISTS fullPath:archiveFileName methodName:@"GTMZipUtilsPlugin.zip"];
        } else {
            NSLog(@"[GTMZipUtilsPlugin.zip] Archive file does not exist: %@", archiveFileName);
        }

        if ([[NSFileManager defaultManager] fileExistsAtPath:tempFileName]){
            NSLog(@"[GTMZipUtilsPlugin.zip] Temporary file already exists, will be deleted: %@", tempFileName);

            if (![[NSFileManager defaultManager] removeItemAtPath:tempFileName error:&error])   //Delete it
            {
                NSLog(@"[GTMZipUtilsPlugin.zip] The temporary file [%@] could not be deleted.", tempFileName);
                NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.unzip] The temporary file [%@] could not be deleted.", tempFileName];
                [self throwGTMException:exceptionMessage code:TEMPORARY_FILE_COULD_NOT_BE_DELETED fullPath:tempFileName methodName:@"GTMZipUtilsPlugin.zip"];
            } else {
                NSLog(@"[GTMZipUtilsPlugin.zip] The temporary file [%@] was deleted.", tempFileName);
            }

        } else {
            NSLog(@"[GTMZipUtilsPlugin.zip] Temporary file does not exist, no deletion will occur: %@", archiveFileName);
        }

        NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
        NSNumber *compressedFileCount = [self zipDirectory:sourceDirectoryName tempFile:tempFileName];

        NSLog(@"[GTMZipUtilsPlugin.zip] Added %@ files to the new zipFile: %@", compressedFileCount, tempFileName);

        if (![[NSFileManager defaultManager] moveItemAtPath:tempFileName toPath:archiveFileName error:&error]){
            NSLog(@"[GTMZipUtilsPlugin.zip] Moving old file %@ to new file %@ failed.", tempFileName, archiveFileName);

            NSString *exceptionMessage = [NSString stringWithFormat:@"Moving old file %@ to new file %@ failed.", tempFileName, archiveFileName];
            [self throwGTMException:exceptionMessage code:COULD_NOT_MOVE fullPath:archiveFileName methodName:@"GTMZipUtilsPlugin.zip"];
        } else {
            NSLog(@"[GTMZipUtilsPlugin.zip] Moving old file %@ to new file %@ was successful.", tempFileName, archiveFileName);
        }

        if ([[NSFileManager defaultManager] fileExistsAtPath:archiveFileName]){
            if ([[NSFileManager defaultManager] fileExistsAtPath:sourceDirectoryName]){
                if (![[NSFileManager defaultManager] removeItemAtPath:sourceDirectoryName error:&error])
                {
                    NSLog(@"[GTMZipUtilsPlugin.zip] The temporary directory [%@] could not be deleted.", sourceDirectoryName);
                    NSString *exceptionMessage = [NSString stringWithFormat:@"[GTMZipUtilsPlugin.zip] The temporary directory [%@] could not be deleted.", sourceDirectoryName];
                    [self throwGTMException:exceptionMessage code:TEMPORARY_FILE_COULD_NOT_BE_DELETED fullPath:sourceDirectoryName methodName:@"GTMZipUtilsPlugin.zip"];
                } else {
                    NSLog(@"[GTMZipUtilsPlugin.zip] The temporary directory [%@] was deleted.", sourceDirectoryName);
                }
            }
        }

        [result setObject:compressedFileCount forKey:@"compressedFileCount"];

        // Create Plugin Result
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];

        //[self writeJavascript: [pluginResult toSuccessCallbackString:self.callbackID]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackID];
    }
    @catch(NSException *e) {
        //TODO get rid of DRY
        NSMutableDictionary* messageDictionary = [[NSMutableDictionary alloc] init];

        NSString *message = e.reason;
        NSNumber *code = [e.userInfo valueForKey:@"code"];
        NSString *fullPath = [e.userInfo valueForKey:@"fullPath"];
        NSLog(@"[GTMZipUtilsPlugin.zip] Catched an exception: %@ , code: %@, fullPath: %@",message, code, fullPath);

        [messageDictionary setObject:message forKey:@"message"];
        [messageDictionary setObject:code forKey:@"code"];
        [messageDictionary setObject:fullPath forKey:@"fullPath"];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:messageDictionary];
        //[self writeJavascript: [pluginResult toErrorCallbackString:self.callbackID]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackID];
    }

}

-(void) sendProgressUpdate:(NSString*)javascript {
    dispatch_async(dispatch_get_main_queue(),^{
        //[self.commandDelegate evalJs:javascript];
        //[self writeJavascript:javascript];
        [self.commandDelegate evalJs:javascript];
    });
}



@end
