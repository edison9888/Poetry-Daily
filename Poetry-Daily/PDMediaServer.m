//
//  PDMediaServer.m
//  Poetry-Daily
//
//  Created by David Sklenar on 5/31/12.
//  Copyright (c) 2012 ELC Technologies. All rights reserved.
//

#import "PDMediaServer.h"

#define DEFAULT_TIMEOUT 60.0


@interface PDMediaServer ()

- (NSString *)poemIDFromDate:(NSDate *)date;
- (NSString *)poemIDForToday;
@end


@implementation PDMediaServer


#pragma mark Properties

@synthesize operationQueue = _operationQueue;
@synthesize username = _username;
@synthesize password = _password;


#pragma mark - Public API

/*
 * TO DO: Add methods to hit PD endpoints.
 * e.g.
 
 - (void)fetchPoemWithID:(NSString *)poemID block:(TVFetchBlock)block;
 {
     NSBlockOperation *fetch = [NSBlockOperation blockOperationWithBlock:^{
     
     NSError *error = nil;
     NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
     
     [params setObject:[NSString stringWithFormat:@"favorite:%@", higherID] forKey:@"1"];
     [params setObject:[NSString stringWithFormat:@"favorite:%@", lowerID]  forKey:@"2"];
     
     NSDictionary *JSON = [self JSONForCommand:@"CreateFavoritePriority" parameters:params error:&error];
     
     dispatch_async( dispatch_get_main_queue(), ^{
     
     if ( JSON == nil && error != nil )
        block( nil, error );
     else
        block( [NSArray arrayWithObject:JSON], nil );
        });
     }];
     
     [self.operationQueue addOperation:fetch];
 }

 */

- (NSDictionary *)JSONForCommand:(NSString *)command parameters:(NSDictionary *)parameters timeout:(NSTimeInterval)timeout error:(NSError *__autoreleasing *)error;
{
    NSParameterAssert( timeout > 0 );
    NSParameterAssert( [command length] > 0 );
    
    NSMutableDictionary *mutableParams = [NSMutableDictionary dictionaryWithDictionary:parameters];
    
    [mutableParams setObject:@"json" forKey:@"encoder"];
    
    NSMutableString *URLString = [NSMutableString stringWithString:@"http://poems.com/"];
    
    [URLString appendFormat:@"/api?c=%@", command];
    [mutableParams enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) { [URLString appendFormat:@"&%@=%@", key, obj]; }];
    
    NSURL *URL = [NSURL URLWithString:URLString];
    NSLog(@"%@", URLString);
    NSURLRequest *request = [NSURLRequest requestWithURL:URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:timeout];
    NSHTTPURLResponse *response = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:error];
    
    if ( [data length] == 0 && error != NULL && *error == nil )
        *error = [[NSError alloc] initWithDomain:@"Connect Error" code:1000 userInfo:nil];
    
    if ( [data length] == 0 )
        return nil;
    
    NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    
    if ( [JSON count] == 0 && error != NULL && *error == nil )
        *error = [[NSError alloc] initWithDomain:@"Connect Error" code:1000 userInfo:nil];
    
    return JSON;
}

- (NSDictionary *)JSONForCommand:(NSString *)command parameters:(NSDictionary *)parameters error:(NSError *__autoreleasing *)error;
{
    return [self JSONForCommand:command parameters:parameters timeout:DEFAULT_TIMEOUT error:error];
}


#pragma mark - Private API

- (NSString *)poemIDFromDate:(NSDate *)date;
{
    NSDate *referenceDate = [NSDate dateWithTimeIntervalSince1970:1269881100.0f];
    
    int difference = (int)[date timeIntervalSinceDate:referenceDate];
    int poemIDInt = difference / 60 /60 /24 + 14698;
        
    return [NSString stringWithFormat:@"%i", poemIDInt];
}

- (NSString *)poemIDForToday;
{
    return [self poemIDFromDate:[NSDate date]];
}

#pragma mark NSObject

- (id)init;
{
    if ( ( self = [super init] ) )
    {
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 4;
                
        _username = [NSString stringWithFormat:@"poems"];
        _password = [NSString stringWithFormat:@"all_day"];
        
        if ([_username length] == 0 || [_password length] == 0) {
            NSError *error = [NSError errorWithDomain:@"No server login credentials" code:401 userInfo:nil];
            NSLog(@"%@", error);
        }
    }
    
    return self;
}


@end