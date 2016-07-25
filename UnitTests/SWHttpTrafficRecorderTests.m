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

//  Created by Michal Konturek on 7/25/2016.

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "SWHttpTrafficRecorder.h"
#import "SWRecordingProtocol.h"

#define VERIFY_ALL \
OCMVerifyAll((id)self.mockFileManager);\
OCMVerifyAll((id)self.mockURLProtocol);\
OCMVerifyAll((id)self.mockDate);\

@interface SWHttpTrafficRecorder ()

@property(nonatomic, assign, readwrite) BOOL isRecording;
//@property(nonatomic, strong) NSString *recordingPath;
@property (nonatomic, assign) int fileNo;
//@property (nonatomic, assign) NSUInteger runTimeStamp;

//@property (nonatomic, strong) NSOperationQueue *fileCreationQueue;
@property (nonatomic, strong) NSURLSessionConfiguration* sessionConfig;

//@property(nonatomic, strong) NSDictionary *fileExtensionMapping;

// dependencies
@property (nonatomic, strong) NSFileManager* fileManager;

@end

@interface SWHttpTrafficRecorderTests : XCTestCase

@property (nonatomic, strong) SWHttpTrafficRecorder* sut;

@property (nonatomic, strong) NSFileManager* mockFileManager;
@property (nonatomic, strong) NSURLProtocol* mockURLProtocol;
@property (nonatomic, strong) NSDate* mockDate;

@end

@implementation SWHttpTrafficRecorderTests

- (void)setUp {
    [super setUp];
    
    self.mockFileManager = OCMStrictClassMock([NSFileManager class]);
    self.mockURLProtocol = OCMClassMock([NSURLProtocol class]);
    self.mockDate = OCMClassMock([NSDate class]);
    
    self.sut = [SWHttpTrafficRecorder sharedRecorder];
    self.sut.fileManager = self.mockFileManager;
}

- (void)tearDown {
    [(id)self.mockURLProtocol stopMocking];
    [(id)self.mockDate stopMocking];
    
    [super tearDown];
}

- (void)test_init_isSingleton {
    id other = [SWHttpTrafficRecorder sharedRecorder];
    XCTAssertEqual(self.sut, other);
}

- (void)test_init {
    XCTAssertFalse(self.sut.isRecording);
    XCTAssertTrue(self.sut.fileNo == 0);
    XCTAssertTrue(self.sut.runTimeStamp == 0);
    XCTAssertTrue(self.sut.recordingFormat == SWHTTPTrafficRecordingFormatMocktail);
    XCTAssertNotNil(self.sut.fileCreationQueue);
    XCTAssertEqual(self.sut.fileManager, self.mockFileManager);
}

- (void)test_init_shouldUserDesignatedInitializer {
    id sut = nil;
    BOOL didThrowException = NO;
    
    @try {
        sut = [[SWHttpTrafficRecorder alloc] init];
    } @catch (NSException *exception) {
        id expected = @"init: Use designated initializer.";
        XCTAssertEqualObjects(exception.reason, expected);
        didThrowException = YES;
    }
    
    XCTAssertTrue(didThrowException);
    XCTAssertNil(sut);
}

- (void)test_startRecordingAtPath_whenRecording_andNoPathAndNoSessionGiven {
    
    // given
    self.sut.isRecording = YES;
    
    // expect
    OCMExpect([(id)self.mockURLProtocol registerClass:OCMOCK_ANY]);
    
    // when
    BOOL result = [self.sut startRecordingAtPath:nil
                         forSessionConfiguration:nil
                                           error:nil
                   ];
    
    // then
    XCTAssertTrue(result);
    XCTAssertTrue(self.sut.isRecording);
    VERIFY_ALL
}

- (void)test_startRecordingAtPath_whenRecording_andNoPathGiven {
    
    // given
    self.sut.isRecording = YES;
    
    NSURLSessionConfiguration* stubSessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    id stubURLProtocol = OCMStub([NSURLProtocol class]);
    id protocols = @[stubURLProtocol, stubURLProtocol];
    stubSessionConfig.protocolClasses = protocols;
    
    // when
    BOOL result = [self.sut startRecordingAtPath:nil
                         forSessionConfiguration:stubSessionConfig
                                           error:nil
                   ];
    
    // then
    XCTAssertTrue(result);
    XCTAssertTrue(self.sut.isRecording);
    
    XCTAssertEqual(self.sut.sessionConfig, stubSessionConfig);
    XCTAssertTrue(self.sut.sessionConfig.protocolClasses.count == 2);
    XCTAssertTrue(self.sut.sessionConfig.protocolClasses[0] == [SWRecordingProtocol class]);
    XCTAssertTrue(self.sut.sessionConfig.protocolClasses[1] == stubURLProtocol);
    
    VERIFY_ALL
}

- (void)test_startRecordingAtPath_whenNotRecording_andNoPathGiven {
    
    // given
    self.sut.isRecording = NO;
    
    NSURLSessionConfiguration* stubSessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    id stubURLProtocol = OCMStub([NSURLProtocol class]);
    id protocols = @[stubURLProtocol, stubURLProtocol];
    stubSessionConfig.protocolClasses = protocols;
    
    // expect
    NSTimeInterval expectedRunTimeStamp = 1234;
    [OCMExpect(ClassMethod([self.mockDate timeIntervalSinceReferenceDate])) andReturnValue:@(expectedRunTimeStamp)];
    
    // when
    BOOL result = [self.sut startRecordingAtPath:nil
                         forSessionConfiguration:stubSessionConfig
                                           error:nil
                   ];
    
    // then
    XCTAssertTrue(result);
    XCTAssertTrue(self.sut.isRecording);
    
    XCTAssertEqual(self.sut.sessionConfig, stubSessionConfig);
    XCTAssertTrue(self.sut.sessionConfig.protocolClasses.count == 2);
    XCTAssertTrue(self.sut.sessionConfig.protocolClasses[0] == [SWRecordingProtocol class]);
    XCTAssertTrue(self.sut.sessionConfig.protocolClasses[1] == stubURLProtocol);
    
    XCTAssertTrue(self.sut.fileNo == 0);
    XCTAssertTrue(self.sut.runTimeStamp == expectedRunTimeStamp);
    
    XCTAssertTrue([self.sut.recordingPath hasSuffix:@"/data/Library/Caches"]);
    
    VERIFY_ALL
}

- (void)test_startRecordingAtPath_whenNotRecording_andPathGiven {
    
    // given
    self.sut.isRecording = NO;
    
    NSURLSessionConfiguration* stubSessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    id stubURLProtocol = OCMStub([NSURLProtocol class]);
    id protocols = @[stubURLProtocol, stubURLProtocol];
    stubSessionConfig.protocolClasses = protocols;
    
    // expect
    NSTimeInterval expectedRunTimeStamp = 1234;
    [OCMExpect(ClassMethod([self.mockDate timeIntervalSinceReferenceDate])) andReturnValue:@(expectedRunTimeStamp)];
    
    id expectedPath = @"expectedPath";
    [OCMExpect([self.mockFileManager fileExistsAtPath:expectedPath]) andReturnValue:@YES];
    [OCMExpect([self.mockFileManager isWritableFileAtPath:expectedPath]) andReturnValue:@YES];
    
    // when
    BOOL result = [self.sut startRecordingAtPath:expectedPath
                         forSessionConfiguration:stubSessionConfig
                                           error:nil
                   ];
    
    // then
    XCTAssertTrue(result);
    XCTAssertTrue(self.sut.isRecording);
    
    XCTAssertEqual(self.sut.sessionConfig, stubSessionConfig);
    XCTAssertTrue(self.sut.sessionConfig.protocolClasses.count == 2);
    XCTAssertTrue(self.sut.sessionConfig.protocolClasses[0] == [SWRecordingProtocol class]);
    XCTAssertTrue(self.sut.sessionConfig.protocolClasses[1] == stubURLProtocol);
    
    XCTAssertTrue(self.sut.fileNo == 0);
    XCTAssertTrue(self.sut.runTimeStamp == expectedRunTimeStamp);
    
    XCTAssertEqualObjects(self.sut.recordingPath, expectedPath);
    
    VERIFY_ALL
}

- (void)test_startRecordingAtPath_whenNotRecording_andPathGivenButNotWriteable {
    
    // given
    self.sut.isRecording = NO;
    
    id expectedPath = @"expectedPath";
    [OCMExpect([self.mockFileManager fileExistsAtPath:expectedPath]) andReturnValue:@YES];
    [OCMExpect([self.mockFileManager isWritableFileAtPath:expectedPath]) andReturnValue:@NO];
    
    NSError* error = nil;
    
    // when
    BOOL result = [self.sut startRecordingAtPath:expectedPath
                         forSessionConfiguration:nil
                                           error:&error
                   ];
    
    // then
    XCTAssertFalse(result);
    XCTAssertFalse(self.sut.isRecording);
    
    XCTAssertTrue(self.sut.fileNo == 0);
    XCTAssertEqualObjects(self.sut.recordingPath, expectedPath);
    
    XCTAssertEqualObjects(error.domain, @"RECORDER_ERROR_DOMAIN");
    XCTAssertTrue(error.code == SWHttpTrafficRecorderErrorPathNotWritable);
    XCTAssertEqualObjects(error.userInfo[NSLocalizedDescriptionKey], @"Path 'expectedPath' is not writable.");
    
    VERIFY_ALL
}

- (void)test_startRecordingAtPath_whenNotRecording_andPathGivenButNotWriteable_noErrorGiven {
    
    // given
    self.sut.isRecording = NO;
    
    id expectedPath = @"expectedPath";
    [OCMExpect([self.mockFileManager fileExistsAtPath:expectedPath]) andReturnValue:@YES];
    [OCMExpect([self.mockFileManager isWritableFileAtPath:expectedPath]) andReturnValue:@NO];
    
    // when
    BOOL result = [self.sut startRecordingAtPath:expectedPath
                         forSessionConfiguration:nil
                                           error:nil
                   ];
    
    // then
    XCTAssertFalse(result);
    XCTAssertFalse(self.sut.isRecording);
    
    XCTAssertTrue(self.sut.fileNo == 0);
    XCTAssertEqualObjects(self.sut.recordingPath, expectedPath);
    
    VERIFY_ALL
}

- (void)test_startRecordingAtPath_whenNotRecording_andPathGivenButNotDoesNotExist_createsDirectory {
    
    // given
    self.sut.isRecording = NO;
    
    id expectedPath = @"expectedPath";
    [OCMExpect([self.mockFileManager fileExistsAtPath:expectedPath]) andReturnValue:@NO];
    
    NSError* error = nil;
    NSError* errorB = nil;
    
    [OCMExpect([self.mockFileManager createDirectoryAtPath:expectedPath
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:[OCMArg setTo:errorB]]) andReturnValue:@YES];
    
    // when
    BOOL result = [self.sut startRecordingAtPath:expectedPath
                         forSessionConfiguration:nil
                                           error:&error
                   ];
    
    // then
    XCTAssertTrue(result);
    XCTAssertTrue(self.sut.isRecording);
    
    XCTAssertTrue(self.sut.fileNo == 0);
    XCTAssertEqualObjects(self.sut.recordingPath, expectedPath);
    
    VERIFY_ALL
}

- (void)test_startRecordingAtPath_whenNotRecording_andPathGivenButNotDoesNotExist_createsDirectoryWithError {
    
    // given
    self.sut.isRecording = NO;
    
    id expectedPath = @"expectedPath";
    [OCMExpect([self.mockFileManager fileExistsAtPath:expectedPath]) andReturnValue:@NO];
    
    NSError* error = nil;
    NSError* stubError = OCMClassMock([NSError class]);
    
    [OCMExpect([self.mockFileManager createDirectoryAtPath:expectedPath
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:[OCMArg setTo:stubError]]) andReturnValue:@NO];
    
    // when
    BOOL result = [self.sut startRecordingAtPath:expectedPath
                         forSessionConfiguration:nil
                                           error:&error
                   ];
    
    // then
    XCTAssertFalse(result);
    XCTAssertFalse(self.sut.isRecording);
    
    XCTAssertTrue(self.sut.fileNo == 0);
    XCTAssertEqualObjects(self.sut.recordingPath, expectedPath);
    
    XCTAssertEqualObjects(error.domain, @"RECORDER_ERROR_DOMAIN");
    XCTAssertTrue(error.code == SWHttpTrafficRecorderErrorPathFailedToCreate);
    XCTAssertEqualObjects(error.userInfo[NSLocalizedDescriptionKey], @"Path 'expectedPath' does not exist and error while creating it.");
    XCTAssertEqual(error.userInfo[NSUnderlyingErrorKey], stubError);
    
    VERIFY_ALL
}

- (void)test_startRecordingAtPath_whenNotRecording_andPathGivenButNotDoesNotExist_createsDirectoryWithError_noErrorGiven {
    
    // given
    self.sut.isRecording = NO;
    
    id expectedPath = @"expectedPath";
    [OCMExpect([self.mockFileManager fileExistsAtPath:expectedPath]) andReturnValue:@NO];
    
    NSError* stubError = OCMClassMock([NSError class]);
    
    [OCMExpect([self.mockFileManager createDirectoryAtPath:expectedPath
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:[OCMArg setTo:stubError]]) andReturnValue:@NO];
    
    // when
    BOOL result = [self.sut startRecordingAtPath:expectedPath
                         forSessionConfiguration:nil
                                           error:nil
                   ];
    
    // then
    XCTAssertFalse(result);
    XCTAssertFalse(self.sut.isRecording);
    
    XCTAssertTrue(self.sut.fileNo == 0);
    XCTAssertEqualObjects(self.sut.recordingPath, expectedPath);
    
    VERIFY_ALL
}

@end
