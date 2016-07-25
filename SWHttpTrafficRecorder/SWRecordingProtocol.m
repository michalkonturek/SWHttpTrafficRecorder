//
//  SWRecordingProtocol.m
//  SWHttpTrafficRecorder
//
//  Created by Michal Konturek on 25/07/2016.
//  Copyright © 2016 CapitalOne. All rights reserved.
//

#import "SWRecordingProtocol.h"

#import "SWHttpTrafficRecorder.h"


static NSString * const SWRecordingLProtocolHandledKey = @"SWRecordingLProtocolHandledKey";

@interface SWRecordingProtocol () <NSURLConnectionDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *mutableData;
@property (nonatomic, strong) NSURLResponse *response;

@end


@implementation SWRecordingProtocol

#pragma mark - NSURLProtocol overrides

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    BOOL isHTTP = [request.URL.scheme isEqualToString:@"https"] || [request.URL.scheme isEqualToString:@"http"];
    if ([NSURLProtocol propertyForKey:SWRecordingLProtocolHandledKey inRequest:request] || !isHTTP) {
        return NO;
    }
    
    [self updateRecorderProgressDelegate:SWHTTPTrafficRecordingProgressReceived userInfo:@{SWHTTPTrafficRecordingProgressRequestKey: request}];
    
    BOOL(^testBlock)(NSURLRequest *request) = [SWHttpTrafficRecorder sharedRecorder].recordingTestBlock;
    BOOL canInit = YES;
    if(testBlock){
        canInit = testBlock(request);
    }
    if(!canInit){
        [self updateRecorderProgressDelegate:SWHTTPTrafficRecordingProgressSkipped userInfo:@{SWHTTPTrafficRecordingProgressRequestKey: request}];
    }
    return canInit;
}

+ (NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void) startLoading {
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:SWRecordingLProtocolHandledKey inRequest:newRequest];
    
    [self.class updateRecorderProgressDelegate:SWHTTPTrafficRecordingProgressStarted userInfo:@{SWHTTPTrafficRecordingProgressRequestKey: self.request}];
    
    self.connection = [NSURLConnection connectionWithRequest:newRequest delegate:self];
}

- (void) stopLoading {
    
    [self.connection cancel];
    self.mutableData = nil;
}

#pragma mark - NSURLConnectionDelegate

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    
    self.response = response;
    self.mutableData = [[NSMutableData alloc] init];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
    
    [self.mutableData appendData:data];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
    
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)self.response;
    NSURLRequest *request = (NSURLRequest*)connection.currentRequest;
    
    [self.class updateRecorderProgressDelegate:SWHTTPTrafficRecordingProgressLoaded
                                      userInfo:@{SWHTTPTrafficRecordingProgressRequestKey: self.request,
                                                 SWHTTPTrafficRecordingProgressResponseKey: self.response,
                                                 SWHTTPTrafficRecordingProgressBodyDataKey: self.mutableData
                                                 }];
    
    NSString *path = [self getFilePath:request response:response];
    SWHTTPTrafficRecordingFormat format = [SWHttpTrafficRecorder sharedRecorder].recordingFormat;
    if(format == SWHTTPTrafficRecordingFormatBodyOnly){
        [self createBodyOnlyFileWithRequest:request response:response data:self.mutableData atFilePath:path];
    } else if(format == SWHTTPTrafficRecordingFormatMocktail){
        [self createMocktailFileWithRequest:request response:response data:self.mutableData atFilePath:path];
    } else if(format == SWHTTPTrafficRecordingFormatHTTPMessage){
        [self createHTTPMessageFileWithRequest:request response:response data:self.mutableData atFilePath:path];
    } else if(format == SWHTTPTrafficRecordingFormatCustom && [SWHttpTrafficRecorder sharedRecorder].createFileInCustomFormatBlock != nil){
        [SWHttpTrafficRecorder sharedRecorder].createFileInCustomFormatBlock(request, response, self.mutableData, path);
    } else {
        NSLog(@"File format: %ld is not supported.", (long)format);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
    
    [self.class updateRecorderProgressDelegate:SWHTTPTrafficRecordingProgressFailedToLoad
                                      userInfo:@{SWHTTPTrafficRecordingProgressRequestKey: self.request,
                                                 SWHTTPTrafficRecordingProgressErrorKey: error
                                                 }];
}


- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self.client URLProtocol:self didReceiveAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self.client URLProtocol:self didCancelAuthenticationChallenge:challenge];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    if (response != nil) {
        [[self client] URLProtocol:self wasRedirectedToRequest:request redirectResponse:response];
    }
    return request;
}


#pragma mark - File Creation Utility Methods

-(NSString *)getFileName:(NSURLRequest *)request response:(NSHTTPURLResponse *)response{
    NSString *fileName = [request.URL lastPathComponent];
    
    if(!fileName || [self isNotValidFileName: fileName]){
        fileName = @"Mocktail";
    }
    
    fileName = [NSString stringWithFormat:@"%@_%lu_%d", fileName, (unsigned long)[SWHttpTrafficRecorder sharedRecorder].runTimeStamp, [[SWHttpTrafficRecorder sharedRecorder] increaseFileNo]];
    
    fileName = [fileName stringByAppendingPathExtension:[self getFileExtension:request response:response]];
    
    NSString *(^fileNamingBlock)(NSURLRequest *request, NSURLResponse *response, NSString *defaultName) = [SWHttpTrafficRecorder sharedRecorder].fileNamingBlock;
    
    if(fileNamingBlock){
        fileName = fileNamingBlock(request, response, fileName);
    }
    return fileName;
}

-(BOOL)isNotValidFileName:(NSString*) fileName{
    return NO;
}

-(NSString *)getFilePath:(NSURLRequest *)request response:(NSHTTPURLResponse *)response{
    NSString *recordingPath = [SWHttpTrafficRecorder sharedRecorder].recordingPath;
    NSString *filePath = [recordingPath stringByAppendingPathComponent:[self getFileName:request response:response]];
    
    return filePath;
}

-(NSString *)getFileExtension:(NSURLRequest *)request response:(NSHTTPURLResponse *)response{
    SWHTTPTrafficRecordingFormat format = [SWHttpTrafficRecorder sharedRecorder].recordingFormat;
    if(format == SWHTTPTrafficRecordingFormatBodyOnly){
        /* Based on http://blog.ablepear.com/2010/08/how-to-get-file-extension-for-mime-type.html, we may be able to get the file extension from mime type. Use a fixed mapping for simpilicity for now unless there is a need later on */
        return [SWHttpTrafficRecorder sharedRecorder].fileExtensionMapping[response.MIMEType] ?: @"unknown";
    } else if(format == SWHTTPTrafficRecordingFormatMocktail){
        return @"tail";
    } else if(format == SWHTTPTrafficRecordingFormatHTTPMessage){
        return @"response";
    }
    
    return @"unknown";
}

-(BOOL)toBase64Body:(NSURLRequest *)request andResponse:(NSHTTPURLResponse *)response{
    if([SWHttpTrafficRecorder sharedRecorder].base64TestBlock){
        return [SWHttpTrafficRecorder sharedRecorder].base64TestBlock(request, response);
    }
    return [response.MIMEType hasPrefix:@"image"];
}

-(NSData *)doBase64:(NSData *)bodyData request: (NSURLRequest*)request response:(NSHTTPURLResponse*)response{
    BOOL toBase64 = [self toBase64Body:request andResponse:response];
    if(toBase64 && bodyData){
        return [bodyData base64EncodedDataWithOptions:0];
    } else {
        return bodyData;
    }
}

-(NSData *)doJSONPrettyPrint:(NSData *)bodyData request: (NSURLRequest*)request response:(NSHTTPURLResponse*)response{
    if([response.MIMEType isEqualToString:@"application/json"] && bodyData)
    {
        NSError *error;
        id json = [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:&error];
        if(json && !error){
            bodyData = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&error];
            if(error){
                NSLog(@"Somehow the content is not a json though the mime type is json: %@", error);
            }
        } else {
            NSLog(@"Somehow the content is not a json though the mime type is json: %@", error);
        }
    }
    return bodyData;
}

-(void)createFileAt:(NSString *)filePath usingData:(NSData *)data completionHandler:(void(^)(BOOL created))completionHandler{
    __block BOOL created = NO;
    NSBlockOperation* creationOp = [NSBlockOperation blockOperationWithBlock: ^{
        created = [NSFileManager.defaultManager createFileAtPath:filePath contents:data attributes:[NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey]];
    }];
    creationOp.completionBlock = ^{
        completionHandler(created);
    };
    [[SWHttpTrafficRecorder sharedRecorder].fileCreationQueue addOperation:creationOp];
}

#pragma mark - BodyOnly File Creation

-(void)createBodyOnlyFileWithRequest:(NSURLRequest*)request response:(NSHTTPURLResponse*)response data:(NSData*)data atFilePath:(NSString *)filePath
{
    data = [self doJSONPrettyPrint:data request:request response:response];
    
    NSDictionary *userInfo = @{SWHTTPTrafficRecordingProgressRequestKey: self.request,
                               SWHTTPTrafficRecordingProgressResponseKey: self.response,
                               SWHTTPTrafficRecordingProgressBodyDataKey: self.mutableData,
                               SWHTTPTrafficRecordingProgressFileFormatKey: @(SWHTTPTrafficRecordingFormatBodyOnly),
                               SWHTTPTrafficRecordingProgressFilePathKey: filePath
                               };
    [self createFileAt:filePath usingData:data completionHandler:^(BOOL created) {
        [self.class updateRecorderProgressDelegate:(created ? SWHTTPTrafficRecordingProgressRecorded : SWHTTPTrafficRecordingProgressFailedToRecord) userInfo:userInfo];
    }];
}

#pragma mark - Mocktail File Creation

-(void)createMocktailFileWithRequest:(NSURLRequest*)request response:(NSHTTPURLResponse*)response data:(NSData*)data atFilePath:(NSString *)filePath
{
    NSMutableString *tail = NSMutableString.new;
    
    [tail appendFormat:@"%@\n", request.HTTPMethod];
    [tail appendFormat:@"%@\n", [self getURLRegexPattern:request]];
    [tail appendFormat:@"%ld\n", (long)response.statusCode];
    [tail appendFormat:@"%@%@\n\n", response.MIMEType, [self toBase64Body:request andResponse:response] ? @";base64": @""];
    
    data = [self doBase64:data request:request response:response];
    
    data = [self doJSONPrettyPrint:data request:request response:response];
    
    data = [self replaceRegexWithTokensInData:data];
    
    [tail appendFormat:@"%@", data ? [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding] : @""];
    
    NSDictionary *userInfo = @{SWHTTPTrafficRecordingProgressRequestKey: self.request,
                               SWHTTPTrafficRecordingProgressResponseKey: self.response,
                               SWHTTPTrafficRecordingProgressBodyDataKey: self.mutableData,
                               SWHTTPTrafficRecordingProgressFileFormatKey: @(SWHTTPTrafficRecordingFormatMocktail),
                               SWHTTPTrafficRecordingProgressFilePathKey: filePath
                               };
    [self createFileAt:filePath usingData:[tail dataUsingEncoding:NSUTF8StringEncoding] completionHandler:^(BOOL created) {
        [self.class updateRecorderProgressDelegate:(created ? SWHTTPTrafficRecordingProgressRecorded : SWHTTPTrafficRecordingProgressFailedToRecord) userInfo: userInfo];
    }];
}

-(NSData *)replaceRegexWithTokensInData: (NSData *) data {
    SWHttpTrafficRecorder *recorder = [SWHttpTrafficRecorder sharedRecorder];
    if(![recorder replacementDict]) {
        return data;
    }
    else {
        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        for(NSString *key in [recorder replacementDict]) {
            if([[[recorder replacementDict] objectForKey: key] isKindOfClass:[NSRegularExpression class]]) {
                dataString = [[[recorder replacementDict] objectForKey:key] stringByReplacingMatchesInString:dataString options:0 range:NSMakeRange(0, [dataString length]) withTemplate:key];
            }
        }
        data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
        return data;
    }
}

-(NSString *)getURLRegexPattern:(NSURLRequest *)request{
    NSString *urlPattern = request.URL.path;
    if(request.URL.query){
        NSArray *queryArray = [request.URL.query componentsSeparatedByString:@"&"];
        NSMutableArray *processedQueryArray = [[NSMutableArray alloc] initWithCapacity:queryArray.count];
        [queryArray enumerateObjectsUsingBlock:^(NSString *part, NSUInteger idx, BOOL *stop) {
            NSRegularExpression *urlRegex = [NSRegularExpression regularExpressionWithPattern:@"(.*)=(.*)" options:NSRegularExpressionCaseInsensitive error:nil];
            part = [urlRegex stringByReplacingMatchesInString:part options:0 range:NSMakeRange(0, part.length) withTemplate:@"$1=.*"];
            [processedQueryArray addObject:part];
        }];
        urlPattern = [NSString stringWithFormat:@"%@\\?%@", request.URL.path, [processedQueryArray componentsJoinedByString:@"&"]];
    }
    
    NSString *(^urlRegexPatternBlock)(NSURLRequest *request, NSString *defaultPattern) = [SWHttpTrafficRecorder sharedRecorder].urlRegexPatternBlock;
    
    if(urlRegexPatternBlock){
        urlPattern = urlRegexPatternBlock(request, urlPattern);
    }
    
    urlPattern = [urlPattern stringByAppendingString:@"$"];
    
    return urlPattern;
}

#pragma mark - HTTP Message File Creation

-(void)createHTTPMessageFileWithRequest:(NSURLRequest*)request response:(NSHTTPURLResponse*)response data:(NSData*)data atFilePath:(NSString *)filePath
{
    NSMutableString *dataString = NSMutableString.new;
    
    [dataString appendFormat:@"%@\n", [self statusLineFromResponse:response]];
    
    NSDictionary *headers = response.allHeaderFields;
    for(NSString *key in headers){
        [dataString appendFormat:@"%@: %@\n", key, headers[key]];
    }
    
    [dataString appendString:@"\n"];
    
    NSMutableData *responseData = [NSMutableData dataWithData:[dataString dataUsingEncoding:NSUTF8StringEncoding]];
    [responseData appendData:data];
    
    NSDictionary *userInfo = @{SWHTTPTrafficRecordingProgressRequestKey: self.request,
                               SWHTTPTrafficRecordingProgressResponseKey: self.response,
                               SWHTTPTrafficRecordingProgressBodyDataKey: self.mutableData,
                               SWHTTPTrafficRecordingProgressFileFormatKey: @(SWHTTPTrafficRecordingFormatHTTPMessage),
                               SWHTTPTrafficRecordingProgressFilePathKey: filePath
                               };
    
    [self createFileAt:filePath usingData:responseData completionHandler:^(BOOL created) {
        [self.class updateRecorderProgressDelegate:(created ? SWHTTPTrafficRecordingProgressRecorded : SWHTTPTrafficRecordingProgressFailedToRecord) userInfo:userInfo];
    }];
}

- (NSString *)statusLineFromResponse:(NSHTTPURLResponse*)response{
    CFHTTPMessageRef message = CFHTTPMessageCreateResponse(kCFAllocatorDefault, [response statusCode], NULL, kCFHTTPVersion1_1);
    NSString *statusLine = (__bridge_transfer NSString *)CFHTTPMessageCopyResponseStatusLine(message);
    CFRelease(message);
    return statusLine;
}

#pragma mark - Recording Progress

+ (void)updateRecorderProgressDelegate:(SWHTTPTrafficRecordingProgressKind)progress userInfo:(NSDictionary *)info{
    SWHttpTrafficRecorder *recorder = [SWHttpTrafficRecorder sharedRecorder];
    if(recorder.progressDelegate && [recorder.progressDelegate respondsToSelector:@selector(updateRecordingProgress:userInfo:)]){
        [recorder.progressDelegate updateRecordingProgress:progress userInfo:info];
    }
}

@end