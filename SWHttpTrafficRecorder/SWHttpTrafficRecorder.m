/***********************************************************************************
 * Copyright 2015 Capital One Services, LLC
 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 
 * http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 ***********************************************************************************/


////////////////////////////////////////////////////////////////////////////////

//  Created by Jinlian (Sunny) Wang on 8/23/15.

#import "SWHttpTrafficRecorder.h"

#import "SWRecordingProtocol.h"

NSString * const SWHTTPTrafficRecordingProgressRequestKey   = @"REQUEST_KEY";
NSString * const SWHTTPTrafficRecordingProgressResponseKey  = @"RESPONSE_KEY";
NSString * const SWHTTPTrafficRecordingProgressBodyDataKey  = @"BODY_DATA_KEY";
NSString * const SWHTTPTrafficRecordingProgressFilePathKey  = @"FILE_PATH_KEY";
NSString * const SWHTTPTrafficRecordingProgressFileFormatKey= @"FILE_FORMAT_KEY";
NSString * const SWHTTPTrafficRecordingProgressErrorKey     = @"ERROR_KEY";

NSString * const SWHttpTrafficRecorderErrorDomain           = @"RECORDER_ERROR_DOMAIN";

@interface SWHttpTrafficRecorder ()

@property(nonatomic, assign, readwrite) BOOL isRecording;
@property(nonatomic, assign) int fileNo;
@property(nonatomic, strong) NSURLSessionConfiguration *sessionConfig;

@property (nonatomic, assign, readwrite) NSUInteger runTimeStamp;
@property (nonatomic, copy, readwrite) NSString *recordingPath;

// dependencies
@property (nonatomic, strong) NSFileManager* fileManager;

@end

@implementation SWHttpTrafficRecorder

+ (instancetype)sharedRecorder {
    static SWHttpTrafficRecorder *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] _init];
    });
    return shared;
}

- (instancetype)_init {
    if (self = [super init]) {
        _isRecording = NO;
        _fileNo = 0;
        _runTimeStamp = 0;
        _fileCreationQueue = [[NSOperationQueue alloc] init];
        _recordingFormat = SWHTTPTrafficRecordingFormatMocktail;
        _fileManager = [NSFileManager defaultManager];
    }
    return self;
}

- (instancetype)init {
    id msg = @"%@: Use designated initializer.";
    id reason = [NSString stringWithFormat:msg, NSStringFromSelector(_cmd)];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

- (BOOL)startRecording {
    return [self startRecordingAtPath:nil forSessionConfiguration:nil error:nil];
}

- (BOOL)startRecordingAtPath:(NSString *)recordingPath
                       error:(NSError **)error {
    return [self startRecordingAtPath:recordingPath forSessionConfiguration:nil error:error];
}

- (BOOL)startRecordingAtPath:(NSString *)recordingPath
     forSessionConfiguration:(NSURLSessionConfiguration *)sessionConfig
                       error:(NSError **)error {
    
    if (!self.isRecording){
        if (recordingPath){
            self.recordingPath = recordingPath;
            
            NSFileManager* fileManager = self.fileManager;
            
            if (![fileManager fileExistsAtPath:recordingPath]) {
                NSError *bError = nil;
                if (![fileManager createDirectoryAtPath:recordingPath
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:&bError]) {
                    if (error) {
                        id key = [NSString stringWithFormat:@"Path '%@' does not exist and error while creating it.", recordingPath];
                        id info = @{
                                    NSLocalizedDescriptionKey : key,
                                    NSUnderlyingErrorKey : bError
                                    };
                        *error = [NSError errorWithDomain:SWHttpTrafficRecorderErrorDomain
                                                     code:SWHttpTrafficRecorderErrorPathFailedToCreate
                                                 userInfo:info
                                  ];
                    }
                    return NO;
                }
            }
            else if (![fileManager isWritableFileAtPath:recordingPath]) {
                if (error){
                    id key = [NSString stringWithFormat:@"Path '%@' is not writable.", recordingPath];
                    id info = @{NSLocalizedDescriptionKey : key};
                    *error = [NSError errorWithDomain:SWHttpTrafficRecorderErrorDomain
                                                 code:SWHttpTrafficRecorderErrorPathNotWritable
                                             userInfo:info];
                }
                return NO;
            }
        } else {
            self.recordingPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
        }

        self.fileNo = 0;
        self.runTimeStamp = (NSUInteger)[NSDate timeIntervalSinceReferenceDate];
    }
    
    if (sessionConfig){
        self.sessionConfig = sessionConfig;
        NSMutableOrderedSet *mutableProtocols = [[NSMutableOrderedSet alloc] initWithArray:sessionConfig.protocolClasses];
        [mutableProtocols insertObject:[SWRecordingProtocol class] atIndex:0];
        sessionConfig.protocolClasses = [mutableProtocols array];
    }
    else {
        [NSURLProtocol registerClass:[SWRecordingProtocol class]];
    }

    self.isRecording = YES;
    
    return YES;
}

- (void)stopRecording{
    if(self.isRecording){
        if(self.sessionConfig) {
            NSMutableArray *mutableProtocols = [[NSMutableArray alloc] initWithArray:self.sessionConfig.protocolClasses];
            [mutableProtocols removeObject:[SWRecordingProtocol class]];
            self.sessionConfig.protocolClasses = mutableProtocols;
            self.sessionConfig = nil;
        }
        else {
            [NSURLProtocol unregisterClass:[SWRecordingProtocol class]];
        }
    }
    self.isRecording = NO;
}

- (int)increaseFileNo{
    @synchronized(self) {
        return self.fileNo++;
    }
}

- (NSDictionary *)fileExtensionMapping {
    static NSDictionary *mapped = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mapped = @{
                   @"application/json": @"json",
                   @"image/png": @"png",
                   @"image/jpeg" : @"jpg",
                   
                   @"image/gif": @"gif",
                   @"image/bmp": @"bmp",
                   @"text/plain": @"txt",
                   
                   @"text/css": @"css",
                   @"text/html": @"html",
                   @"application/javascript": @"js",
                   
                   @"text/javascript": @"js",
                   @"application/xml": @"xml",
                   @"text/xml": @"xml",
                   
                   @"image/tiff": @"tiff",
                   @"image/x-tiff": @"tiff"
                   };
    });
    return mapped;
}

@end
