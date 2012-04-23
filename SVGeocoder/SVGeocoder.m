//
// SVGeocoder.m
//
// Created by Sam Vermette on 07.02.11.
// Copyright 2011 samvermette.com. All rights reserved.
//
// https://github.com/samvermette/SVGeocoder
// http://code.google.com/apis/maps/documentation/geocoding/
//

#import "SVGeocoder.h" 
#import "JSONKit.h"

#define kSVGeocoderTimeoutInterval 20

enum {
    SVGeocoderRequestStateReady = 0,
    SVGeocoderRequestStateExecuting,
    SVGeocoderRequestStateFinished
};

typedef NSUInteger SVGeocoderRequestState;


@interface NSString (URLEncoding)
- (NSString*)encodedURLParameterString;
@end


@interface SVGeocoder ()

- (SVGeocoder*)initWithParameters:(NSMutableDictionary*)parameters completion:(void (^)(NSArray *, NSError*))block;
- (void)addParametersToRequest:(NSMutableDictionary*)parameters;
- (void)finish;

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;

@property (nonatomic, retain) NSString *requestString;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableURLRequest *request;
@property (nonatomic, readwrite) SVGeocoderRequestState state;

@property (nonatomic, retain) NSTimer *timeoutTimer; // see http://stackoverflow.com/questions/2736967
@property (nonatomic, copy) void (^completionBlock)(NSArray *placemarks, NSError *error);

@end

@implementation SVGeocoder

@synthesize delegate, requestString, responseData, connection, request, state, timeoutTimer, completionBlock;
@synthesize querying = _querying;

#pragma mark -

- (void)dealloc {
    [responseData release];
    [request release];
    [connection cancel];
    [connection release];
    
    self.timeoutTimer = nil;
    self.completionBlock = nil;

	[super dealloc];
}

#pragma mark - Convenience Initializers

+ (SVGeocoder *)geocode:(NSString *)address completion:(void (^)(NSArray *, NSError *))block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", nil];
    SVGeocoder *geocoder = [[self alloc] initWithParameters:parameters completion:block];
    [geocoder start];
    return [geocoder autorelease];
}

+ (SVGeocoder *)geocode:(NSString *)address bounds:(MKCoordinateRegion)bounds completion:(void (^)(NSArray *, NSError *))block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", 
                                       [NSString stringWithFormat:@"%f,%f|%f,%f", 
                                        bounds.center.latitude-(bounds.span.latitudeDelta/2.0),
                                        bounds.center.longitude-(bounds.span.longitudeDelta/2.0),
                                        bounds.center.latitude+(bounds.span.latitudeDelta/2.0),
                                        bounds.center.longitude+(bounds.span.longitudeDelta/2.0)], @"bounds", nil];
    SVGeocoder *geocoder = [[self alloc] initWithParameters:parameters completion:block];
    [geocoder start];
    return [geocoder autorelease];
}

+ (SVGeocoder *)geocode:(NSString *)address region:(NSString *)region completion:(void (^)(NSArray *, NSError *))block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", 
                                       region, @"region", nil];
    SVGeocoder *geocoder = [[self alloc] initWithParameters:parameters completion:block];
    [geocoder start];
    return [geocoder autorelease];
}

+ (SVGeocoder *)reverseGeocode:(CLLocationCoordinate2D)coordinate completion:(void (^)(NSArray *, NSError *))block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       [NSString stringWithFormat:@"%f,%f", coordinate.latitude, coordinate.longitude], @"latlng", nil];
    SVGeocoder *geocoder = [[self alloc] initWithParameters:parameters completion:block];
    [geocoder start];
    return [geocoder autorelease];
}

#pragma mark - Public Initializers

- (SVGeocoder*)initWithCoordinate:(CLLocationCoordinate2D)coordinate {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       [NSString stringWithFormat:@"%f,%f", coordinate.latitude, coordinate.longitude], @"latlng", nil];
    
    return [self initWithParameters:parameters completion:NULL];
}


- (SVGeocoder*)initWithAddress:(NSString*)address {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", nil];
    
    return [self initWithParameters:parameters completion:NULL];
}


- (SVGeocoder*)initWithAddress:(NSString *)address inBounds:(MKCoordinateRegion)region {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", 
                                       [NSString stringWithFormat:@"%f,%f|%f,%f", 
                                            region.center.latitude-(region.span.latitudeDelta/2.0),
                                            region.center.longitude-(region.span.longitudeDelta/2.0),
                                            region.center.latitude+(region.span.latitudeDelta/2.0),
                                            region.center.longitude+(region.span.longitudeDelta/2.0)], @"bounds", nil];
    
    return [self initWithParameters:parameters completion:NULL];
}


- (SVGeocoder*)initWithAddress:(NSString *)address inRegion:(NSString *)regionString {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", 
                                       regionString, @"region", nil];
    
    return [self initWithParameters:parameters completion:NULL];
}


#pragma mark - Private Utility Methods

- (SVGeocoder*)initWithParameters:(NSMutableDictionary*)parameters completion:(void (^)(NSArray *, NSError *))block {
    self = [super init];
    self.completionBlock = block;
    self.request = [[[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://maps.googleapis.com/maps/api/geocode/json"]] autorelease];
    [self.request setTimeoutInterval:kSVGeocoderTimeoutInterval];

    [parameters setValue:@"true" forKey:@"sensor"];
    [parameters setValue:[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] forKey:@"language"];
    [self addParametersToRequest:parameters];
        
    self.state = SVGeocoderRequestStateReady;
    
    return self;
}

- (void)addParametersToRequest:(NSMutableDictionary*)parameters {
    
    NSMutableArray *paramStringsArray = [NSMutableArray arrayWithCapacity:[[parameters allKeys] count]];
    
    for(NSString *key in [parameters allKeys]) {
        NSObject *paramValue = [parameters valueForKey:key];
		if ([paramValue isKindOfClass:[NSString class]]) {
			[paramStringsArray addObject:[NSString stringWithFormat:@"%@=%@", key, [(NSString *)paramValue encodedURLParameterString]]];			
		} else {
			[paramStringsArray addObject:[NSString stringWithFormat:@"%@=%@", key, paramValue]];
		}
    }
    
    NSString *paramsString = [paramStringsArray componentsJoinedByString:@"&"];
    NSString *baseAddress = request.URL.absoluteString;
    baseAddress = [baseAddress stringByAppendingFormat:@"?%@", paramsString];
    [self.request setURL:[NSURL URLWithString:baseAddress]];
}

- (void)setTimeoutTimer:(NSTimer *)newTimer {
    
    if(timeoutTimer)
        [timeoutTimer invalidate], [timeoutTimer release], timeoutTimer = nil;
    
    if(newTimer)
        timeoutTimer = [newTimer retain];
}

#pragma mark - NSOperation methods

- (void)start {
    
    if(self.isCancelled) {
        [self finish];
        return;
    }
    
    if(![NSThread isMainThread]) { // NSOperationQueue calls start from a bg thread (through GCD), but NSURLConnection already does that by itself
        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
        return;
    }
        
    [self willChangeValueForKey:@"isExecuting"];
    self.state = SVGeocoderRequestStateExecuting;    
    [self didChangeValueForKey:@"isExecuting"];
    
    self.responseData = [[[NSMutableData alloc] init] autorelease];
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:kSVGeocoderTimeoutInterval target:self selector:@selector(requestTimeout) userInfo:nil repeats:NO];
    
    self.connection = [[[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:YES] autorelease];
    NSLog(@"[%@] %@", self.request.HTTPMethod, self.request.URL.absoluteString);
}

// private method; not part of NSOperation
- (void)finish {
    [connection cancel];
    [connection release];
    connection = nil;
    
    [self willChangeValueForKey:@"isExecuting"];
//    [self willChangeValueForKey:@"isFinished"]; // no idea why but this makes it crash
    self.state = SVGeocoderRequestStateFinished;    
    [self didChangeValueForKey:@"isExecuting"];
//    [self didChangeValueForKey:@"isFinished"]; // no idea why but this makes it crash
    
    self.timeoutTimer = nil;
}

- (void)cancel {
    if([self isFinished])
        return;
    
    [super cancel];
    [self finish];
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isFinished {
    return self.state == SVGeocoderRequestStateFinished;
}

- (BOOL)isExecuting {
    return self.state == SVGeocoderRequestStateExecuting;
}

- (void)startAsynchronous {
	[self start];
}


#pragma mark -
#pragma mark NSURLConnectionDelegate

- (void)requestTimeout {
    NSError *timeoutError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [self connection:nil didFailWithError:timeoutError];
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[self.responseData appendData:data];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	_querying = NO;
	id response = nil;
    NSError *error = nil;
    
    if(self.responseData && self.responseData.length > 0) {
        response = [NSData dataWithData:self.responseData];
        NSDictionary *responseDict = [response objectFromJSONDataWithParseOptions:JKSerializeOptionNone error:&error];
        
        if(!error) {
            NSArray *resultsArray = [responseDict valueForKey:@"results"];
            NSString *status = [responseDict valueForKey:@"status"];
            // deal with error statuses by raising didFailWithError
            
            if ([status isEqualToString:@"ZERO_RESULTS"]) {
                NSDictionary *userinfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Zero results returned", NSLocalizedDescriptionKey, nil];
                error = [NSError errorWithDomain:@"SVGeocoderErrorDomain" code:SVGeocoderZeroResultsError userInfo:userinfo];
            }
            
            else if ([status isEqualToString:@"OVER_QUERY_LIMIT"]) {
                NSDictionary *userinfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Currently rate limited. Too many queries in a short time. (Over Quota)", NSLocalizedDescriptionKey, nil];
                error = [NSError errorWithDomain:@"SVGeocoderErrorDomain" code:SVGeocoderOverQueryLimitError userInfo:userinfo];
            }

            else if ([status isEqualToString:@"REQUEST_DENIED"]) {
                NSDictionary *userinfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Request was denied. Did you remember to add the \"sensor\" parameter?", NSLocalizedDescriptionKey, nil];
                error = [NSError errorWithDomain:@"SVGeocoderErrorDomain" code:SVGeocoderRequestDeniedError userInfo:userinfo];
            }    
            
            else if ([status isEqualToString:@"INVALID_REQUEST"]) {
                NSDictionary *userinfo = [NSDictionary dictionaryWithObjectsAndKeys:@"The request was invalid. Was the \"address\" or \"latlng\" missing?", NSLocalizedDescriptionKey, nil];
                error = [NSError errorWithDomain:@"SVGeocoderErrorDomain" code:SVGeocoderInvalidRequestError userInfo:userinfo];
            }
            
            else {
                NSMutableArray *placemarksArray = [NSMutableArray arrayWithCapacity:[resultsArray count]];
                
                for(NSDictionary *placemarkDict in resultsArray) {
                
                    NSDictionary *addressDict = [placemarkDict valueForKey:@"address_components"];
                    NSDictionary *coordinateDict = [[placemarkDict valueForKey:@"geometry"] valueForKey:@"location"];
                    NSDictionary *boundsDict = [[placemarkDict valueForKey:@"geometry"] valueForKey:@"bounds"];
                    
                    CLLocationDegrees lat = [[coordinateDict valueForKey:@"lat"] floatValue];
                    CLLocationDegrees lng = [[coordinateDict valueForKey:@"lng"] floatValue];
                    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat, lng);
                    
                    NSDictionary *northEastDict = [boundsDict objectForKey:@"northeast"];
                    NSDictionary *southWestDict = [boundsDict objectForKey:@"southwest"];
                    CLLocationDegrees northEastLatitude = [[northEastDict objectForKey:@"lat"] floatValue];
                    CLLocationDegrees southWestLatitude = [[southWestDict objectForKey:@"lat"] floatValue];
                    CLLocationDegrees latitudeDelta = fabs(northEastLatitude - southWestLatitude);
                    CLLocationDegrees northEastLongitude = [[northEastDict objectForKey:@"lng"] floatValue];
                    CLLocationDegrees southWestLongitude = [[southWestDict objectForKey:@"lng"] floatValue];
                    CLLocationDegrees longitudeDelta = fabs(northEastLongitude - southWestLongitude);
                    MKCoordinateSpan span = MKCoordinateSpanMake(latitudeDelta, longitudeDelta);
                    MKCoordinateRegion region = MKCoordinateRegionMake(coordinate, span);
                    
                    NSMutableDictionary *formattedAddressDict = [[NSMutableDictionary alloc] init];
                    NSMutableArray *streetAddressComponents = [NSMutableArray arrayWithCapacity:2];
                    
                    for(NSDictionary *component in addressDict) {
                        
                        NSArray *types = [component valueForKey:@"types"];
                        
                        if([types containsObject:@"street_number"])
                            [streetAddressComponents addObject:[component valueForKey:@"long_name"]];
                        
                        if([types containsObject:@"route"])
                            [streetAddressComponents addObject:[component valueForKey:@"long_name"]];
                        
                        if([types containsObject:@"locality"])
                            [formattedAddressDict setValue:[component valueForKey:@"long_name"] forKey:(NSString*)kABPersonAddressCityKey];
                        else if([types containsObject:@"natural_feature"])
                            [formattedAddressDict setValue:[component valueForKey:@"long_name"] forKey:(NSString*)kABPersonAddressCityKey];
                        
                        if([types containsObject:@"administrative_area_level_1"])
                            [formattedAddressDict setValue:[component valueForKey:@"long_name"] forKey:(NSString*)kABPersonAddressStateKey];
                        
                        if([types containsObject:@"postal_code"])
                            [formattedAddressDict setValue:[component valueForKey:@"long_name"] forKey:(NSString*)kABPersonAddressZIPKey];
                        
                        if([types containsObject:@"country"]) {
                            [formattedAddressDict setValue:[component valueForKey:@"long_name"] forKey:(NSString*)kABPersonAddressCountryKey];
                            [formattedAddressDict setValue:[component valueForKey:@"short_name"] forKey:(NSString*)kABPersonAddressCountryCodeKey];
                        }
                    }
                    
                    if([streetAddressComponents count] > 0)
                        [formattedAddressDict setValue:[streetAddressComponents componentsJoinedByString:@" "] forKey:(NSString*)kABPersonAddressStreetKey];
                    
                    SVPlacemark *placemark = [[SVPlacemark alloc] initWithRegion:region addressDictionary:formattedAddressDict];
                    [formattedAddressDict release];
                    
                    placemark.formattedAddress = [placemarkDict objectForKey:@"formatted_address"];
                    
                    [placemarksArray addObject:placemark];
                    [placemark release];
                }
                
                response = placemarksArray;
            }
        }
    }
    
    if(self.completionBlock) {
        if(error)
            self.completionBlock(nil, error);
        else
            self.completionBlock(response, error);
    } 
    
    else {
        if(error && [(NSObject*)self.delegate respondsToSelector:@selector(geocoder:didFailWithError:)])
            [self.delegate geocoder:self didFailWithError:error];
        else if(!error && [(NSObject*)self.delegate respondsToSelector:@selector(geocoder:didFindPlacemark:)])
            [self.delegate geocoder:self didFindPlacemark:[response objectAtIndex:0]];
        else if(!error && [(NSObject*)self.delegate respondsToSelector:@selector(geocoder:didFindPlacemarks:)])
            [self.delegate geocoder:self didFindPlacemarks:response];
    }
    
    [self finish];
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    _querying = NO;
	
    if(self.completionBlock)
        self.completionBlock(nil, error);
    else
        [self.delegate geocoder:self didFailWithError:error];
    
    [self finish];
}


@end


#pragma mark -

@implementation NSString (URLEncoding)

- (NSString*)encodedURLParameterString {
    NSString *result = (NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                          (CFStringRef)self,
                                                                          NULL,
                                                                          CFSTR(":/=,!$&'()*+;[]@#?|"),
                                                                          kCFStringEncodingUTF8);
	return [result autorelease];
}

@end
