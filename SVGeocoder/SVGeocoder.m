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

#define kSVGeocoderTimeoutInterval 20

enum {
    SVGeocoderStateReady = 0,
    SVGeocoderStateExecuting,
    SVGeocoderStateFinished
};

typedef NSUInteger SVGeocoderState;


@interface NSString (URLEncoding)
- (NSString*)encodedURLParameterString;
@end


@interface SVGeocoder ()

@property (nonatomic, strong) NSMutableURLRequest *operationRequest;
@property (nonatomic, strong) NSMutableData *operationData;
@property (nonatomic, strong) NSURLConnection *operationConnection;
@property (nonatomic, strong) NSHTTPURLResponse *operationURLResponse;

@property (nonatomic, copy) SVGeocoderCompletionHandler operationCompletionBlock;
@property (nonatomic, readwrite) SVGeocoderState state;
@property (nonatomic, strong) NSString *requestPath;
@property (nonatomic, strong) NSTimer *timeoutTimer; // see http://stackoverflow.com/questions/2736967

- (SVGeocoder*)initWithParameters:(NSMutableDictionary*)parameters completion:(SVGeocoderCompletionHandler)block;

- (void)addParametersToRequest:(NSMutableDictionary*)parameters;
- (void)finish;

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)callCompletionBlockWithResponse:(id)response error:(NSError *)error;

@end

@implementation SVGeocoder

// private properties
@synthesize operationRequest, operationData, operationConnection, operationURLResponse, state;
@synthesize operationCompletionBlock, timeoutTimer;

#pragma mark -

- (void)dealloc {
    [operationConnection cancel];
#if TARGET_OS_MAC && !TARGET_OS_IPHONE && !TARGET_OS_EMBEDDED && !TARGET_IPHONE_SIMULATOR
    [super dealloc];
#endif

}

#pragma mark - Convenience Initializers

+ (SVGeocoder *)geocode:(NSString *)address completion:(SVGeocoderCompletionHandler)block {
    SVGeocoder *geocoder = [[self alloc] initWithAddress:address completion:block];
    [geocoder start];
    return geocoder;
}

+ (SVGeocoder *)geocode:(NSString *)address bounds:(MKCoordinateRegion)bounds completion:(SVGeocoderCompletionHandler)block {
    SVGeocoder *geocoder = [[self alloc] initWithAddress:address bounds:bounds completion:block];
    [geocoder start];
    return geocoder;
}

+ (SVGeocoder *)geocode:(NSString *)address region:(NSString *)region completion:(SVGeocoderCompletionHandler)block {
    SVGeocoder *geocoder = [[self alloc] initWithAddress:address region:region completion:block];
    [geocoder start];
    return geocoder;
}

+ (SVGeocoder *)reverseGeocode:(CLLocationCoordinate2D)coordinate completion:(SVGeocoderCompletionHandler)block {
    SVGeocoder *geocoder = [[self alloc] initWithCoordinate:coordinate completion:block];
    [geocoder start];
    return geocoder;
}

#pragma mark - Public Initializers

- (SVGeocoder*)initWithCoordinate:(CLLocationCoordinate2D)coordinate completion:(SVGeocoderCompletionHandler)block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       [NSString stringWithFormat:@"%f,%f", coordinate.latitude, coordinate.longitude], @"latlng", nil];
    
    return [self initWithParameters:parameters completion:block];
}


- (SVGeocoder*)initWithAddress:(NSString*)address completion:(SVGeocoderCompletionHandler)block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", nil];
    
    return [self initWithParameters:parameters completion:block];
}


- (SVGeocoder*)initWithAddress:(NSString *)address bounds:(MKCoordinateRegion)region completion:(SVGeocoderCompletionHandler)block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", 
                                       [NSString stringWithFormat:@"%f,%f|%f,%f", 
                                            region.center.latitude-(region.span.latitudeDelta/2.0),
                                            region.center.longitude-(region.span.longitudeDelta/2.0),
                                            region.center.latitude+(region.span.latitudeDelta/2.0),
                                            region.center.longitude+(region.span.longitudeDelta/2.0)], @"bounds", nil];
    
    return [self initWithParameters:parameters completion:block];
}


- (SVGeocoder*)initWithAddress:(NSString *)address region:(NSString *)regionString completion:(SVGeocoderCompletionHandler)block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", 
                                       regionString, @"region", nil];
    
    return [self initWithParameters:parameters completion:block];
}


#pragma mark - Private Utility Methods

- (SVGeocoder*)initWithParameters:(NSMutableDictionary*)parameters completion:(SVGeocoderCompletionHandler)block {
    self = [super init];
    self.operationCompletionBlock = block;
    self.operationRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://maps.googleapis.com/maps/api/geocode/json"]];
    [self.operationRequest setTimeoutInterval:kSVGeocoderTimeoutInterval];

    [parameters setValue:@"true" forKey:@"sensor"];
    [parameters setValue:[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] forKey:@"language"];
    [self addParametersToRequest:parameters];
        
    self.state = SVGeocoderStateReady;
    
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
    NSString *baseAddress = self.operationRequest.URL.absoluteString;
    baseAddress = [baseAddress stringByAppendingFormat:@"?%@", paramsString];
    [self.operationRequest setURL:[NSURL URLWithString:baseAddress]];
}

- (void)setTimeoutTimer:(NSTimer *)newTimer {
    
    if(timeoutTimer)
        [timeoutTimer invalidate], timeoutTimer = nil;
    
    if(newTimer)
        timeoutTimer = newTimer;
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
    self.state = SVGeocoderStateExecuting;
    [self didChangeValueForKey:@"isExecuting"];
    
    self.operationData = [[NSMutableData alloc] init];
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:kSVGeocoderTimeoutInterval target:self selector:@selector(requestTimeout) userInfo:nil repeats:NO];
    
    self.operationConnection = [[NSURLConnection alloc] initWithRequest:self.operationRequest delegate:self startImmediately:NO];
    [self.operationConnection start];
    
#if !(defined SVHTTPREQUEST_DISABLE_LOGGING)
    NSLog(@"[%@] %@", self.operationRequest.HTTPMethod, self.operationRequest.URL.absoluteString);
#endif
}

- (void)finish {
    [self.operationConnection cancel];
    operationConnection = nil;
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    self.state = SVGeocoderStateFinished;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)cancel {
    if([self isFinished])
        return;
    
    [super cancel];
    [self callCompletionBlockWithResponse:nil error:nil];
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isFinished {
    return self.state == SVGeocoderStateFinished;
}

- (BOOL)isExecuting {
    return self.state == SVGeocoderStateExecuting;
}

- (SVGeocoderState)state {
    @synchronized(self) {
        return state;
    }
}

- (void)setState:(SVGeocoderState)newState {
    @synchronized(self) {
        [self willChangeValueForKey:@"state"];
        state = newState;
        [self didChangeValueForKey:@"state"];
    }
}


#pragma mark -
#pragma mark NSURLConnectionDelegate

- (void)requestTimeout {
    NSURL *failingURL = self.operationRequest.URL;
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"The operation timed out.", NSLocalizedDescriptionKey,
                              failingURL, NSURLErrorFailingURLErrorKey,
                              failingURL.absoluteString, NSURLErrorFailingURLStringErrorKey, nil];
    
    NSError *timeoutError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:userInfo];
    [self connection:nil didFailWithError:timeoutError];
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.operationURLResponse = (NSHTTPURLResponse*)response;
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[self.operationData appendData:data];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    id response = [NSData dataWithData:self.operationData];
    NSMutableArray *placemarks = nil;
    NSError *error = nil;
    
    if ([[operationURLResponse MIMEType] isEqualToString:@"application/json"]) {
        if(self.operationData && self.operationData.length > 0) {
            response = [NSData dataWithData:self.operationData];
            NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingAllowFragments error:&error];
            NSArray *results = [jsonObject objectForKey:@"results"];
            NSString *status = [jsonObject valueForKey:@"status"];
            
            if(results)
                placemarks = [NSMutableArray arrayWithCapacity:results.count];
            
            if(results.count > 0) {
                [results enumerateObjectsUsingBlock:^(NSDictionary *result, NSUInteger idx, BOOL *stop) {
                    SVPlacemark *placemark = [[SVPlacemark alloc] init];
                    placemark.formattedAddress = [result objectForKey:@"formatted_address"];
                    
                    NSArray *addressComponents = [result objectForKey:@"address_components"];
                    
                    [addressComponents enumerateObjectsUsingBlock:^(NSDictionary *component, NSUInteger idx, BOOL *stop) {
                        NSArray *types = [component objectForKey:@"types"];
                        
                        if([types containsObject:@"street_number"])
                            placemark.subThoroughfare = [component objectForKey:@"long_name"];
                        
                        if([types containsObject:@"route"])
                            placemark.thoroughfare = [component objectForKey:@"long_name"];
                        
                        if([types containsObject:@"administrative_area_level_3"] || [types containsObject:@"sublocality"] || [types containsObject:@"neighborhood"])
                            placemark.subLocality = [component objectForKey:@"long_name"];
                        
                        if([types containsObject:@"locality"])
                            placemark.locality = [component objectForKey:@"long_name"];
                        
                        if([types containsObject:@"administrative_area_level_2"])
                            placemark.subAdministrativeArea = [component objectForKey:@"long_name"];
                        
                        if([types containsObject:@"administrative_area_level_1"]) {
                            placemark.administrativeArea = [component objectForKey:@"long_name"];
                            placemark.administrativeAreaCode = [component objectForKey:@"short_name"];
                        }
                        
                        if([types containsObject:@"country"]) {
                            placemark.country = [component objectForKey:@"long_name"];
                            placemark.ISOcountryCode = [component objectForKey:@"short_name"];
                        }
                        
                        if([types containsObject:@"postal_code"])
                            placemark.postalCode = [component objectForKey:@"long_name"];
                        
                    }];
                    
                    NSDictionary *locationDict = [[result objectForKey:@"geometry"] objectForKey:@"location"];
                    NSDictionary *boundsDict = [[result objectForKey:@"geometry"] objectForKey:@"bounds"];
                    
                    CLLocationDegrees lat = [[locationDict objectForKey:@"lat"] doubleValue];
                    CLLocationDegrees lng = [[locationDict objectForKey:@"lng"] doubleValue];
                    placemark.coordinate = CLLocationCoordinate2DMake(lat, lng);
                    placemark.location = [[CLLocation alloc] initWithLatitude:lat longitude:lng];
                    
                    NSDictionary *northEastDict = [boundsDict objectForKey:@"northeast"];
                    NSDictionary *southWestDict = [boundsDict objectForKey:@"southwest"];
                    CLLocationDegrees northEastLatitude = [[northEastDict objectForKey:@"lat"] doubleValue];
                    CLLocationDegrees southWestLatitude = [[southWestDict objectForKey:@"lat"] doubleValue];
                    CLLocationDegrees latitudeDelta = fabs(northEastLatitude - southWestLatitude);
                    CLLocationDegrees northEastLongitude = [[northEastDict objectForKey:@"lng"] doubleValue];
                    CLLocationDegrees southWestLongitude = [[southWestDict objectForKey:@"lng"] doubleValue];
                    CLLocationDegrees longitudeDelta = fabs(northEastLongitude - southWestLongitude);
                    MKCoordinateSpan span = MKCoordinateSpanMake(latitudeDelta, longitudeDelta);
                    placemark.region = MKCoordinateRegionMake(placemark.location.coordinate, span);
                    
                    [placemarks addObject:placemark];
                }];
            }
            else {
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
            }
        }
    }
    
    [self callCompletionBlockWithResponse:placemarks error:error];
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self callCompletionBlockWithResponse:nil error:error];
}

- (void)callCompletionBlockWithResponse:(id)response error:(NSError *)error {
    self.timeoutTimer = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *serverError = error;
        
        if(!serverError && self.operationURLResponse.statusCode == 500) {
            serverError = [NSError errorWithDomain:NSURLErrorDomain
                                              code:NSURLErrorBadServerResponse
                                          userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                    @"Bad Server Response.", NSLocalizedDescriptionKey,
                                                    self.operationRequest.URL, NSURLErrorFailingURLErrorKey,
                                                    self.operationRequest.URL.absoluteString, NSURLErrorFailingURLStringErrorKey, nil]];
        }
        
        if(self.operationCompletionBlock && !self.isCancelled)
            self.operationCompletionBlock([response copy], self.operationURLResponse, serverError);
        
        [self finish];
    });
}


@end


#pragma mark -

@implementation NSString (URLEncoding)

- (NSString*)encodedURLParameterString {
    NSString *result = (NSString*)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                          (__bridge CFStringRef)self,
                                                                          NULL,
                                                                          CFSTR(":/=,!$&'()*+;[]@#?|"),
                                                                          kCFStringEncodingUTF8));
	return result;
}

@end
