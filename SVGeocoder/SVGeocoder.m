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

@interface NSString (URLEncoding)
- (NSString*)encodedURLParameterString;
@end


@interface SVGeocoder ()

- (SVGeocoder*)initWithParameters:(NSMutableDictionary*)parameters completion:(void (^)(id, NSError*))block;
- (void)addParametersToRequest:(NSMutableDictionary*)parameters;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;

@property (nonatomic, retain) NSString *requestString;
@property (nonatomic, assign) NSMutableData *responseData;
@property (nonatomic, assign) NSURLConnection *connection;
@property (nonatomic, assign) NSMutableURLRequest *request;

@property (nonatomic, copy) void (^completionBlock)(id placemarks, NSError *error);
@property (nonatomic, retain) NSTimer *timeoutTimer; // see http://stackoverflow.com/questions/2736967

@end

@implementation SVGeocoder

@synthesize delegate, requestString, responseData, connection, request, timeoutTimer, completionBlock;
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

+ (SVGeocoder *)geocode:(NSString *)address completion:(void (^)(id, NSError *))block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", nil];
    SVGeocoder *geocoder = [[self alloc] initWithParameters:parameters completion:block];
    [geocoder startAsynchronous];
    return [geocoder autorelease];
}

+ (SVGeocoder *)geocode:(NSString *)address bounds:(MKCoordinateRegion)bounds completion:(void (^)(id, NSError *))block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", 
                                       [NSString stringWithFormat:@"%f,%f|%f,%f", 
                                        bounds.center.latitude-(bounds.span.latitudeDelta/2.0),
                                        bounds.center.longitude-(bounds.span.longitudeDelta/2.0),
                                        bounds.center.latitude+(bounds.span.latitudeDelta/2.0),
                                        bounds.center.longitude+(bounds.span.longitudeDelta/2.0)], @"bounds", nil];
    SVGeocoder *geocoder = [[self alloc] initWithParameters:parameters completion:block];
    [geocoder startAsynchronous];
    return [geocoder autorelease];
}

+ (SVGeocoder *)geocode:(NSString *)address region:(NSString *)region completion:(void (^)(id, NSError *))block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       address, @"address", 
                                       region, @"region", nil];
    SVGeocoder *geocoder = [[self alloc] initWithParameters:parameters completion:block];
    [geocoder startAsynchronous];
    return [geocoder autorelease];
}

+ (SVGeocoder *)reverseGeocode:(CLLocationCoordinate2D)coordinate completion:(void (^)(id, NSError *))block {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       [NSString stringWithFormat:@"%f,%f", coordinate.latitude, coordinate.longitude], @"latlng", nil];
    SVGeocoder *geocoder = [[self alloc] initWithParameters:parameters completion:block];
    [geocoder startAsynchronous];
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

- (SVGeocoder*)initWithParameters:(NSMutableDictionary*)parameters completion:(void (^)(id, NSError *))block {
    
    self.completionBlock = block;
    self.request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://maps.googleapis.com/maps/api/geocode/json"]];
    [self.request setTimeoutInterval:kSVGeocoderTimeoutInterval];

    [parameters setValue:@"true" forKey:@"sensor"];
    [parameters setValue:[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] forKey:@"language"];
    [self addParametersToRequest:parameters];
    
    NSLog(@"[GET] %@", request.URL.absoluteString);
    
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

#pragma mark - Public Utility Methods

- (void)cancel {
	_querying = NO;
	
    [self.connection cancel];
    [self.connection release];
    connection = nil;
}


- (void)startAsynchronous {
	_querying = YES;
	responseData = [[NSMutableData alloc] init];
	self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:kSVGeocoderTimeoutInterval target:self selector:@selector(requestTimeout) userInfo:nil repeats:NO];
}


#pragma mark -
#pragma mark NSURLConnectionDelegate

- (void)requestTimeout {
    NSError *timeoutError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [self connection:nil didFailWithError:timeoutError];
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[responseData appendData:data];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	
	_querying = NO;
	
	NSDictionary *responseDict = [responseData objectFromJSONData];
	NSError *error = nil;
    
    NSArray *resultsArray = [responseDict valueForKey:@"results"];    
 	NSMutableArray *placemarksArray = [NSMutableArray arrayWithCapacity:[resultsArray count]];
    
	if(responseDict == nil || resultsArray == nil) {
        NSDictionary *userinfo = [NSDictionary dictionaryWithObjectsAndKeys:@"JSON couldn't be parsed", NSLocalizedDescriptionKey, nil];
		error = [NSError errorWithDomain:@"SVGeocoderErrorDomain" code:SVGeocoderJSONParsingError userInfo:userinfo];
	}
	
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
        for(NSDictionary *placemarkDict in resultsArray) {
        
            NSDictionary *addressDict = [placemarkDict valueForKey:@"address_components"];
            NSDictionary *coordinateDict = [[placemarkDict valueForKey:@"geometry"] valueForKey:@"location"];
            
            float lat = [[coordinateDict valueForKey:@"lat"] floatValue];
            float lng = [[coordinateDict valueForKey:@"lng"] floatValue];
            
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
            
            SVPlacemark *placemark = [[SVPlacemark alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lng) addressDictionary:formattedAddressDict];
            [formattedAddressDict release];
            
            placemark.formattedAddress = [placemarkDict objectForKey:@"formatted_address"];
            
            [placemarksArray addObject:placemark];
            [placemark release];
        }
    }
    
    if(self.completionBlock) {
        if(error)
            self.completionBlock(nil, error);
        else
            self.completionBlock(placemarksArray, error);
    } 
    
    else {
        if([(NSObject*)self.delegate respondsToSelector:@selector(geocoder:didFindPlacemark:)])
            [self.delegate geocoder:self didFindPlacemark:[placemarksArray objectAtIndex:0]];
        
        else if([(NSObject*)self.delegate respondsToSelector:@selector(geocoder:didFindPlacemarks:)])
            [self.delegate geocoder:self didFindPlacemarks:placemarksArray];
    }
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	
	_querying = NO;
	
    self.timeoutTimer = nil;
	
    if(self.completionBlock)
        self.completionBlock(nil, error);
    else
        [self.delegate geocoder:self didFailWithError:error];
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
