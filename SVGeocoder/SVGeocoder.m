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

@interface NSString (URLEncoding)
- (NSString*)encodedURLParameterString;
@end


@interface SVGeocoder ()

- (SVGeocoder*)initWithParameters:(NSMutableDictionary*)parameters;
- (void)addParametersToRequest:(NSMutableDictionary*)parameters;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;

@property (nonatomic, retain) NSString *requestString;
@property (nonatomic, assign) NSMutableData *responseData;
@property (nonatomic, assign) NSURLConnection *rConnection;
@property (nonatomic, retain) NSMutableURLRequest *request;

@end

@implementation SVGeocoder

@synthesize delegate, requestString, responseData, rConnection, request;
@synthesize querying = _querying;

#pragma mark -

- (void)dealloc {
    if (self.isQuerying)
        [self cancel];
	
	[super dealloc];
}

#pragma mark - Public Initializers

- (SVGeocoder*)initWithCoordinate:(CLLocationCoordinate2D)coordinate {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       [NSString stringWithFormat:@"%f,%f", coordinate.latitude, coordinate.longitude], @"latlng", nil];
    
    return [self initWithParameters:parameters];
}


- (SVGeocoder*)initWithAddress:(NSString*)address {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       [address encodedURLParameterString], @"address", nil];
    
    return [self initWithParameters:parameters];
}


- (SVGeocoder*)initWithAddress:(NSString *)address inBounds:(MKCoordinateRegion)region {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       [address encodedURLParameterString], @"address", 
                                       [NSString stringWithFormat:@"%f,%f|%f,%f", 
                                            region.center.latitude-(region.span.latitudeDelta/2.0),
                                            region.center.longitude-(region.span.longitudeDelta/2.0),
                                            region.center.latitude+(region.span.latitudeDelta/2.0),
                                            region.center.longitude+(region.span.longitudeDelta/2.0)], @"bounds", nil];
    
    return [self initWithParameters:parameters];
}


- (SVGeocoder*)initWithAddress:(NSString *)address inRegion:(NSString *)regionString {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                                       [address encodedURLParameterString], @"address", 
                                       regionString, @"region", nil];
    
    return [self initWithParameters:parameters];
}


#pragma mark - Private Utility Methods

- (SVGeocoder*)initWithParameters:(NSMutableDictionary*)parameters {
    
    self.request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://maps.googleapis.com/maps/api/geocode/json"]];
    
    [parameters setValue:@"true" forKey:@"sensor"];
    [parameters setValue:[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] forKey:@"language"];
    [self addParametersToRequest:parameters];
    
    NSLog(@"SVGeocoder -> %@", request.URL.absoluteString);
    
    return self;
}

- (void)addParametersToRequest:(NSMutableDictionary*)parameters {
    
    NSMutableArray *paramStringsArray = [NSMutableArray arrayWithCapacity:[[parameters allKeys] count]];
    
    for(NSString *key in [parameters allKeys]) {
        NSObject *paramValue = [parameters valueForKey:key];
        [paramStringsArray addObject:[NSString stringWithFormat:@"%@=%@", key, paramValue]];
    }
    
    NSString *paramsString = [paramStringsArray componentsJoinedByString:@"&"];
    NSString *baseAddress = request.URL.absoluteString;
    baseAddress = [baseAddress stringByAppendingFormat:@"?%@", paramsString];
    [self.request setURL:[NSURL URLWithString:baseAddress]];
}


#pragma mark - Public Utility Methods

- (void)cancel {
	_querying = NO;
	
    self.request = nil;
    self.delegate = nil;
	self.requestString = nil;
	
	[responseData release];
    [rConnection cancel];
	[rConnection release];
}


- (void)startAsynchronous {
	_querying = YES;
	responseData = [[NSMutableData alloc] init];
	rConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}


#pragma mark -
#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	
	[responseData appendData:data];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	
	_querying = NO;
	
	NSError *jsonError = NULL;
	NSDictionary *responseDict = [responseData objectFromJSONData];
	
    NSArray *resultsArray = [responseDict valueForKey:@"results"];    
 	NSMutableArray *placemarksArray = [NSMutableArray arrayWithCapacity:[resultsArray count]];
    
	if(responseDict == nil || resultsArray == nil || [resultsArray count] == 0) {
		[self connection:connection didFailWithError:jsonError];
		return;
	}
    
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
	
    if([(NSObject*)self.delegate respondsToSelector:@selector(geocoder:didFindPlacemark:)])
        [self.delegate geocoder:self didFindPlacemark:[placemarksArray objectAtIndex:0]];
    
    else if([(NSObject*)self.delegate respondsToSelector:@selector(geocoder:didFindPlacemarks:)])
        [self.delegate geocoder:self didFindPlacemarks:placemarksArray];
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	
	_querying = NO;
	
	NSLog(@"SVGeocoder -> Failed with error: %@, (%@)", [error localizedDescription], [[request URL] absoluteString]);
	
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
