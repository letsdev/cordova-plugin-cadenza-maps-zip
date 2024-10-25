//
//  NSFileManager+Tar.m
//  Tar
//
//  Created by Mathieu Hausherr Octo Technology on 25/11/11.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "NSFileManager+Tar.h"
#import "GTMZipUtilsPlugin.h"

#pragma mark - Definitions

// Login mode
// Comment this line for production
//#define TAR_VERBOSE_LOG_MODE

// const definition
#define TAR_BLOCK_SIZE 512
#define TAR_NAME_POSITION 0
#define TAR_SIZE_POSITION 124
#define TAR_TYPE_POSITION 156
#define TAR_PREFIX_POSITION 345
#define TAR_NAME_SIZE 100
#define TAR_SIZE_SIZE 12
#define TAR_PREFIX_SIZE 155
#define TAR_MAX_BLOCK_LOAD_IN_MEMORY 100

// Error const
#define TAR_ERROR_DOMAIN @"com.lightuntar"
#define TAR_ERROR_CODE_BAD_BLOCK 1
#define TAR_ERROR_CODE_SOURCE_NOT_FOUND 2
#define TAR_ERROR_DOMAIN_DISY @"net.disy.lightuntar"
#define TAR_ERROR_CODE_PAXHEADER_NO_NAME_FOUND 3

#pragma mark - Private Methods
@interface NSFileManager(Tar_Private)
-(BOOL)createFilesAndDirectoriesAtPath:(NSString *)path filename:(NSString*)filename withTarObject:(id)object size:(unsigned long long)size fileCount:(NSNumber**)fileCount error:(NSError **)error plugin:(NSObject*)plugin;

+ (char)typeForObject:(id)object atOffset:(unsigned long long)offset;
+ (NSString*)nameForObject:(id)object atOffset:(unsigned long long)offset;
+ (unsigned long long)sizeForObject:(id)object atOffset:(unsigned long long)offset;
- (void)writeFileDataForObject:(id)object inRange:(NSRange)range atPath:(NSString*)path;
- (void)writeFileDataForObject:(id)object atLocation:(unsigned long long)location withLength:(unsigned long long)length atPath:(NSString*)path;
+ (NSData*)dataForObject:(id)object inRange:(NSRange)range orLocation:(unsigned long long)location andLength:(unsigned long long)length;
@end

#pragma mark - Implementation
@implementation NSFileManager (Tar)

- (BOOL)createFilesAndDirectoriesAtURL:(NSURL*)url filename:(NSString*)filename withTarData:(NSData*)tarData  fileCount:(NSNumber**)fileCount error:(NSError**)error plugin:(NSObject*)plugin
{
    return[self createFilesAndDirectoriesAtPath:[url path] filename:filename withTarData:tarData fileCount:fileCount error:error plugin:plugin];
}

- (BOOL)createFilesAndDirectoriesAtPath:(NSString*)path filename:(NSString*)filename withTarData:(NSData*)tarData fileCount:(NSNumber**)fileCount error:(NSError**)error plugin:(NSObject*)plugin
{
    return [self createFilesAndDirectoriesAtPath:path filename:filename withTarObject:tarData size:[tarData length] fileCount:fileCount error:error plugin:plugin];
}

-(BOOL)createFilesAndDirectoriesAtPath:(NSString *)path filename:(NSString*)filename withTarPath:(NSString *)tarPath fileCount:(NSNumber**)fileCount error:(NSError **)error plugin:(NSObject*)plugin
{
    NSFileManager * filemanager = [NSFileManager defaultManager];
    if([filemanager fileExistsAtPath:tarPath]){
        NSDictionary * attributes = [filemanager attributesOfItemAtPath:tarPath error:nil];
        unsigned long long  size = [[attributes objectForKey:NSFileSize] longLongValue]; //NSFileSize retourne un NSNumber long long
        NSFileHandle* fileHandle = [NSFileHandle fileHandleForReadingAtPath:tarPath];
        BOOL result = [self createFilesAndDirectoriesAtPath:path filename:filename withTarObject:fileHandle size:size fileCount:fileCount error:error plugin:plugin];
        [fileHandle closeFile];
        return result;
    }
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Source file not found"
                                                         forKey:NSLocalizedDescriptionKey];
    if (error != NULL) *error = [NSError errorWithDomain:TAR_ERROR_DOMAIN code:TAR_ERROR_CODE_SOURCE_NOT_FOUND userInfo:userInfo];
    return NO;
}

-(BOOL)createFilesAndDirectoriesAtPath:(NSString *)path filename:(NSString*)filename withTarObject:(id)object size:(unsigned long long)size fileCount:(NSNumber**)fileCount error:(NSError **)error plugin:(NSObject*)plugin
{
    [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]; //Create path on filesystem

    unsigned long long location = 0; // Position in the file

    NSAutoreleasePool *pool;
    __block int countExtractedFiles = 0;
    __block int percentageActualFile = -1;
    __block int oldPercentageActualFile = -1;
    __block unsigned long long countedSize = 0;
    unsigned long long originalSize = size;

    __block BOOL paxHeaderMode = NO;
    __block NSString *paxHeaderName = nil;
    CFAbsoluteTime oldTime = CFAbsoluteTimeGetCurrent();
    pool = [[NSAutoreleasePool alloc] init];
    unsigned long long numberOfIterations = 0;
    while (location<size) {
        unsigned long long blockCount = 1; // 1 block for the header

        switch ([NSFileManager typeForObject:object atOffset:location]) {
            case '0': // It's a File
            {
                NSString* name = [NSFileManager nameForObject:object atOffset:location];
                if (paxHeaderMode == YES) {
                    if (paxHeaderName==nil) {
                        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Found no name for PaxHeader-Entry"
                                                                             forKey:NSLocalizedDescriptionKey];
                        if (error != NULL) *error = [NSError errorWithDomain:TAR_ERROR_DOMAIN_DISY code:TAR_ERROR_CODE_PAXHEADER_NO_NAME_FOUND userInfo:userInfo];
                        [pool drain];
                        return NO;
                    } else {
                        NSLog(@"paxHeaderName IN FILE: %@", paxHeaderName);
                        name = [NSString stringWithString:paxHeaderName];
                        paxHeaderMode = NO;
                        [paxHeaderName release];
                        paxHeaderName = nil;
                    }
                }
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - file - %@",name);
#endif
                NSString *filePath = [path stringByAppendingPathComponent:name]; // Create a full path from the name

                unsigned long long size = [NSFileManager sizeForObject:object atOffset:location];
                countedSize += size;
                if (size == 0){
#ifdef TAR_VERBOSE_LOG_MODE
                    NSLog(@"UNTAR - empty_file - %@", filePath);
#endif
                    [@"" writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:error];
                    break;
                }

                blockCount += (size-1)/TAR_BLOCK_SIZE+1; // size/TAR_BLOCK_SIZE rounded up

                // [self writeFileDataForObject:object inRange:NSMakeRange(location+TAR_BLOCK_SIZE, size) atPath:filePath];
                [self writeFileDataForObject:object atLocation:(location+TAR_BLOCK_SIZE) withLength:size atPath:filePath];

                percentageActualFile = (int) ((float) ((float) countedSize / (float) originalSize) * 100);
                CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
                if (percentageActualFile-oldPercentageActualFile>=1 && currentTime - oldTime > 1){
                    NSLog(@"currenttime: %f", currentTime);
                    oldTime = currentTime;
                    oldPercentageActualFile = percentageActualFile;
                    dispatch_async(dispatch_get_main_queue(),^{
                        NSString *updateUiJs = [NSString stringWithFormat:@"var event = document.createEvent(\'CustomEvent\');event.initCustomEvent(\'progressUpdate\', true, true, {filename:\'%@\', progress:\'%@\', title: \'Karte importieren\'});document.dispatchEvent(event);", filename, [NSNumber numberWithInt:percentageActualFile]];
                        //[plugin writeJavascript:updateUiJs];
                        [((GTMZipUtilsPlugin*)plugin) sendJsCallback:updateUiJs];
                    });
                }
                countExtractedFiles++;

                break;
            }
            case '5': // It's a directory
            {
                NSString* name = [NSFileManager nameForObject:object atOffset:location];
                if (paxHeaderMode == YES) {
                    if (paxHeaderName==nil) {
                        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Found no name for PaxHeader-Entry"
                                                                             forKey:NSLocalizedDescriptionKey];
                        if (error != NULL) *error = [NSError errorWithDomain:TAR_ERROR_DOMAIN_DISY code:TAR_ERROR_CODE_PAXHEADER_NO_NAME_FOUND userInfo:userInfo];
                        [pool drain];
                        return NO;
                    } else {
                        NSLog(@"paxHeaderName IN DIRECTORY: %@", paxHeaderName);
                        name = [NSString stringWithString:paxHeaderName];
                        paxHeaderMode = NO;
                        [paxHeaderName release];
                        paxHeaderName = nil;
                    }
                }
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - directory - %@",name);
#endif
                NSString *directoryPath = [path stringByAppendingPathComponent:name]; // Create a full path from the name
                [self createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil]; //Write the directory on filesystem
                break;
            }
            case '\0': // It's a nul block
            {
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - empty block");
#endif
                paxHeaderMode = NO;
                paxHeaderName = nil;
                break;
            }
            case 'x': {
                // Found a PaxHeader-Entry
                NSLog(@"UNTAR - PaxHeader-Entry found");
                paxHeaderMode = YES;
                //Springe einen Block weiter
                location+=blockCount*TAR_BLOCK_SIZE;
                // GET PAXHEADER NAME:
                paxHeaderName = [[NSString alloc] initWithString:[NSFileManager nameForPaxHeaderObject:object atOffset:location]];
                NSLog(@"paxHeaderName : %@", paxHeaderName);
                //Lese bis zum Leerzeichen
                //Parse die Zahl
                //Lese von der aktuellen Position die Zahl der Zeichen minus Zeichen für Zahl
                //Filtere dann die Schlüsselwörter raus, merke das Schlüsselwort PATH=, falls vorhanden,
                //Wenn vorhanden, nimm den Rest des Strings als Namen
                //Entweder 5 oder 0 als ObjectType
                //Ansonsten wieder GET PAXHEADER NAME
                //In andere Sachen außer 0/5/x muss PaxHeaderName resettet werden
                break;
            }
            case '1':
            case '2':
            case '3':
            case '4':
            case '6':
            case '7':
            case 'g': // It's not a file neither a directory
            {
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - unsupported block");
#endif
                unsigned long long size = [NSFileManager sizeForObject:object atOffset:location];
                blockCount += ceil(size/TAR_BLOCK_SIZE);
                break;
            }
            default: // It's not a tar type
            {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Invalid block type found"
                                                                     forKey:NSLocalizedDescriptionKey];
                if (error != NULL) *error = [NSError errorWithDomain:TAR_ERROR_DOMAIN code:TAR_ERROR_CODE_BAD_BLOCK userInfo:userInfo];
                [pool drain];
                return NO;
            }
        }

        location+=blockCount*TAR_BLOCK_SIZE;
        if (numberOfIterations % 10 == 0){
            [pool drain];
            pool = [[NSAutoreleasePool alloc] init];
        }
        numberOfIterations++;
    }
    [pool drain];
    [pool release];
    *fileCount = [NSNumber numberWithInt:countExtractedFiles];
    return YES;
}

#pragma mark Private methods implementation

+ (NSString*)nameForPaxHeaderObject:(id)object atOffset:(unsigned long long)absoluteOffset
{
    unsigned long long currentAbsoluteOffset = 0;
    unsigned long long currentRelativeOffset = 0;
    BOOL foundFileName = NO;
    BOOL endOfDataReached = NO;
    NSString *parsedHeaderString = nil;
    //Lese bis zum Leerzeichen
    while (endOfDataReached==NO && foundFileName == NO && currentAbsoluteOffset < TAR_BLOCK_SIZE) {
        switch ([NSFileManager charAtOffset:object atOffset:absoluteOffset+currentAbsoluteOffset+currentRelativeOffset]) {
            case ' ' : {
                NSLog(@"foundSpaceCharater at absoluteOffset: %llu + currentAbsoluteOffset: %llu", absoluteOffset, currentAbsoluteOffset);
                parsedHeaderString = [self parsePaxHeaderForNameRecord:object atOffset:absoluteOffset+currentAbsoluteOffset withSizeLength:currentRelativeOffset];
                if (parsedHeaderString==nil) {
                    currentAbsoluteOffset = [self goToNextNewLine:object fromOffset:currentAbsoluteOffset];
                    currentRelativeOffset = 0;
                } else {
                    foundFileName = YES;
                }
                break;
            }
            case '\0': {
                endOfDataReached = YES;
                break;
            }
            default: {
                currentRelativeOffset+=1;
                break;
            }
        }
    }
    return parsedHeaderString;
    //Filtere dann die Schlüsselwörter raus, merke das Schlüsselwort PATH=, falls vorhanden,
    //Wenn vorhanden, nimm den Rest des Strings als Namen
    /*
    char nameBytes[TAR_NAME_SIZE+1]; // TAR_NAME_SIZE+1 for nul char at end
    memset(&nameBytes, '\0', TAR_NAME_SIZE+1); // Fill byte array with nul char
    memcpy(&nameBytes,[self dataForObject:object inRange:NSMakeRange(offset+TAR_NAME_POSITION, TAR_NAME_SIZE) orLocation:offset+TAR_NAME_POSITION andLength:TAR_NAME_SIZE].bytes, TAR_NAME_SIZE);
    return [NSString stringWithCString:nameBytes encoding:NSASCIIStringEncoding];
     */
}

+ (NSString*)parsePaxHeaderForNameRecord:(id)object atOffset:(unsigned long long)offset withSizeLength:(unsigned long long)length {
    //Parse die Zahl
    NSData *decimalLengthData = [self dataForObject:object inRange:NSMakeRange(offset, length) orLocation:offset andLength:length];
    //NSLog(@"DATA %@", data);
    NSString* stringValue = [[[NSString alloc] initWithData:decimalLengthData
                                                   encoding:NSUTF8StringEncoding] autorelease];
    unsigned long long longValue = [stringValue longLongValue];
    //NSLog(@"StringValue %llu", longValue);
    //Lese von der aktuellen Position die Zahl der Zeichen minus Zeichen für Zahl
    NSData *paxHeaderData = [self dataForObject:object inRange:NSMakeRange(offset+length+1, longValue-length-1-1) orLocation:offset+length+1 andLength:longValue-length-1-1];
    NSString* stringValuePaxHeaderData = [[[NSString alloc] initWithData:paxHeaderData
                                                                encoding:NSUTF8StringEncoding] autorelease];
    NSLog(@"stringValuePaxHeaderData %@", stringValuePaxHeaderData);
    if ([stringValuePaxHeaderData hasPrefix:@"path="]) {
        return [stringValuePaxHeaderData substringFromIndex:5];
    }
    return nil;
}

+ (unsigned long long) goToNextNewLine:(id)object fromOffset:(unsigned long long)offset {
    unsigned long long relativeOffset = 0;
    BOOL endOfDataReached = NO;
    BOOL foundNewLine = NO;
    while (endOfDataReached==NO && foundNewLine==NO) {
        switch ([NSFileManager charAtOffset:object atOffset:offset+relativeOffset]) {
            case '\n': {
                foundNewLine = YES;
                break;
            }
            case '\0': {
                endOfDataReached = YES;
                break;
            }
            default: {
                relativeOffset+=1;
                break;
            }
        }
    }
    return offset + relativeOffset;
}

+ (char)typeForObject:(id)object atOffset:(unsigned long long)offset
{
    char type;
    memcpy(&type,[self dataForObject:object inRange:NSMakeRange(offset+TAR_TYPE_POSITION, 1) orLocation:offset+TAR_TYPE_POSITION andLength:1].bytes, 1);
    return type;
}

+ (char)charAtOffset:(id)object atOffset:(unsigned long long)offset
{
    char type;
    memcpy(&type,[self dataForObject:object inRange:NSMakeRange(offset, 1) orLocation:offset andLength:1].bytes, 1);
    return type;
}

+ (NSString*)prefixForObject:(id)object atOffset:(unsigned long long)offset
{
    char prefixBytes[TAR_PREFIX_SIZE+1]; // TAR_PREFIX_SIZE+1 for nul char at end
    memset(&prefixBytes, '\0', TAR_PREFIX_SIZE+1); // Fill byte array with nul char
    memcpy(&prefixBytes,[self dataForObject:object inRange:NSMakeRange(offset+TAR_PREFIX_POSITION, TAR_PREFIX_SIZE) orLocation:offset+TAR_PREFIX_POSITION andLength:TAR_PREFIX_SIZE].bytes, TAR_PREFIX_SIZE);
    return [NSString stringWithCString:prefixBytes encoding:NSASCIIStringEncoding];
}

+ (NSString*)nameForObject:(id)object atOffset:(unsigned long long)offset
{
    NSString* prefix = [self prefixForObject:object atOffset:offset];
    char nameBytes[TAR_NAME_SIZE+1]; // TAR_NAME_SIZE+1 for nul char at end
    memset(&nameBytes, '\0', TAR_NAME_SIZE+1); // Fill byte array with nul char
    memcpy(&nameBytes,[self dataForObject:object inRange:NSMakeRange(offset+TAR_NAME_POSITION, TAR_NAME_SIZE) orLocation:offset+TAR_NAME_POSITION andLength:TAR_NAME_SIZE].bytes, TAR_NAME_SIZE);
    NSString* name = [NSString stringWithCString:nameBytes encoding:NSASCIIStringEncoding];
    if ([prefix length] == 0) {
      return name;
    } else {
      return [NSString stringWithFormat:@"%@%@", prefix, name];
    }
}

+ (unsigned long long)sizeForObject:(id)object atOffset:(unsigned long long)offset
{
    char sizeBytes[TAR_SIZE_SIZE+1]; // TAR_SIZE_SIZE+1 for nul char at end
    memset(&sizeBytes, '\0', TAR_SIZE_SIZE+1); // Fill byte array with nul char
    memcpy(&sizeBytes,[self dataForObject:object inRange:NSMakeRange(offset+TAR_SIZE_POSITION, TAR_SIZE_SIZE) orLocation:offset+TAR_SIZE_POSITION andLength:TAR_SIZE_SIZE].bytes, TAR_SIZE_SIZE);
    return strtol(sizeBytes, NULL, 8); // Size is an octal number, convert to decimal
}


- (void)writeFileDataForObject:(id)object atLocation:(unsigned long long)location withLength:(unsigned long long)length atPath:(NSString*)path
{
    if([object isKindOfClass:[NSData class]]) {
        [self createFileAtPath:path contents:[object subdataWithRange:NSMakeRange(location, length)] attributes:nil]; //Write the file on filesystem
    }
    else if([object isKindOfClass:[NSFileHandle class]]) {
        if([[NSData data] writeToFile:path atomically:NO]) {

            NSFileHandle *destinationFile = [NSFileHandle fileHandleForWritingAtPath:path];
            [object seekToFileOffset:location];

            unsigned long long maxSize = TAR_MAX_BLOCK_LOAD_IN_MEMORY*TAR_BLOCK_SIZE;

            while(length > maxSize) {
                @autoreleasepool {
                    //NSAutoreleasePool *poll = [[NSAutoreleasePool alloc] init];
                    [destinationFile writeData:[object readDataOfLength:maxSize]];
                    location += maxSize;
                    length -= maxSize;
                    //[poll release];
                }
            }
            @autoreleasepool {
            [destinationFile writeData:[object readDataOfLength:length]];
            [destinationFile closeFile];
            }
        }
    }
}

+ (NSData*)dataForObject:(id)object inRange:(NSRange)range orLocation:(unsigned long long)location andLength:(unsigned long long)length
{
    if([object isKindOfClass:[NSData class]]) {
        return [object subdataWithRange:range];
    }
    else if([object isKindOfClass:[NSFileHandle class]]) {
        [object seekToFileOffset:location];
        return [object readDataOfLength:length];
    }
    return nil;
}


@end
