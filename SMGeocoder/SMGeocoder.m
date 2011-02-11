//
//  SMGeocoder.m
//
//  Created by Sam Vermette on 07.02.11.
//  Copyright 2011 Sam Vermette. All rights reserved.
//

#import "SMGeocoder.h" 

#import "CJSONDeserializer.h"

@implementation SMGeocoder

@synthesize delegate;

#pragma mark -

- (SMGeocoder*)initWithCoordinate:(CLLocationCoordinate2D)coordinate {
	
	NSString *requestString = [NSString stringWithFormat:@"http://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=true", coordinate.latitude, coordinate.longitude];
	NSLog(@"SMGeocoder -> reverse geocoding: %f, %f", coordinate.latitude, coordinate.longitude);
	
	request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:requestString]];
	
	return self;
}

- (SMGeocoder*)initWithAddress:(NSString*)address {
	
	NSString *urlEncodedAddress = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)address, NULL, CFSTR("?=&+"), kCFStringEncodingUTF8);
	
	NSString *requestString = [NSString stringWithFormat:@"http://maps.googleapis.com/maps/api/geocode/json?address=%@&sensor=true", urlEncodedAddress];
	NSLog(@"SMGeocoder -> geocoding: %@", address);
	
	request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:requestString]];

	return self;
}

#pragma mark -

- (void)setDelegate:(id <SMGeocoderDelegate>)newDelegate {
	
	delegate = newDelegate;
}


- (void)startAsynchronous {
	
	responseData = [[NSMutableData alloc] init];
	
	rConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}

#pragma mark -
#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	
	[responseData appendData:data];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	
	NSError *jsonError = NULL;
	NSDictionary *responseDict = [[CJSONDeserializer deserializer] deserializeAsDictionary:responseData error:&jsonError];
	
	if(responseDict == nil || [responseDict valueForKey:@"results"] == nil || [[responseDict valueForKey:@"results"] count] == 0) {
		[self connection:connection didFailWithError:jsonError];
		return;
	}
	
	NSDictionary *addressDict = [[[responseDict valueForKey:@"results"] objectAtIndex:0] valueForKey:@"address_components"];
	NSDictionary *coordinateDict = [[[[responseDict valueForKey:@"results"] objectAtIndex:0] valueForKey:@"geometry"] valueForKey:@"location"];
	
	float lat = [[coordinateDict valueForKey:@"lat"] floatValue];
	float lng = [[coordinateDict valueForKey:@"lng"] floatValue];
	
	NSMutableDictionary *formattedAddressDict = [[NSMutableDictionary alloc] init];
	
	for(NSDictionary *component in addressDict) {
		
		NSArray *types = [component valueForKey:@"types"];
		
		if([types containsObject:@"street_number"])
			[formattedAddressDict setValue:[component valueForKey:@"long_name"] forKey:(NSString*)kABPersonAddressStreetKey];
		
		if([types containsObject:@"route"])
			[formattedAddressDict setValue:[[formattedAddressDict valueForKey:(NSString*)kABPersonAddressStreetKey] stringByAppendingFormat:@" %@",[component valueForKey:@"long_name"]] forKey:(NSString*)kABPersonAddressStreetKey];
		
		if([types containsObject:@"locality"])
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
	
	MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lng) addressDictionary:formattedAddressDict];
	[formattedAddressDict release];
	
	NSLog(@"SMGeocoder -> Found Placemark");
	[self.delegate geocoder:self didFindPlacemark:placemark];
	[placemark release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	
	NSLog(@"SMGeocoder -> Failed with error: %@", [error localizedDescription]);
	
	[self.delegate geocoder:self didFailWithError:error];
}

#pragma mark -

- (void)dealloc {
	
	[request release];
	[responseData release];
	[rConnection release];
	
	[super dealloc];
}

@end
