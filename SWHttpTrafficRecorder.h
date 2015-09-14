/***********************************************************************************
 *
 * Copyright (c) 2015 Jinlian (Sunny) Wang
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 ***********************************************************************************/


////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SWHTTPTrafficRecordingFormat) {
    SWHTTPTrafficRecordingFormatCustom = -1,
    SWHTTPTrafficRecordingFormatBodyOnly = 1,
    SWHTTPTrafficRecordingFormatMocktail = 2,
    SWHTTPTrafficRecordingFormatHTTPMessage = 3
};

@interface SWHttpTrafficRecorder : NSObject

+ (instancetype)sharedRecorder;
- (void)startRecordingAtPath:(NSString*)recordingPath error:(NSError **)error;
- (void)stopRecording;


@property(nonatomic, readonly, assign) BOOL isRecording;

@property(nonatomic, assign) SWHTTPTrafficRecordingFormat recordingFormat;

@property(nonatomic, copy) BOOL(^recordingTestBlock)(NSURLRequest *request);
@property(nonatomic, copy) BOOL(^base64TestBlock)(NSURLRequest *request, NSURLResponse *response);
@property(nonatomic, copy) NSString*(^fileNamingBlock)(NSURLRequest *request, NSString *defaultName);
@property(nonatomic, copy) NSString*(^urlRegexPatternBlock)(NSURLRequest *request, NSString *defaultPattern);
@property(nonatomic, copy) NSString*(^createFileInCustomFormatBlock)(NSURLRequest *request, NSURLResponse *response, NSData *bodyData, NSString *filePath);

@end
