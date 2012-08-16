//
// SVPlacemark.m
// SVGeocoder
//
// Created by Sam Vermette on 01.05.11.
// Copyright 2011 samvermette.com. All rights reserved.
//
// https://github.com/samvermette/SVGeocoder
//

#import "SVPlacemark.h"


@implementation SVPlacemark

@synthesize formattedAddress, subThoroughfare, thoroughfare, subLocality, locality, subAdministrativeArea, administrativeArea, administrativeAreaCode, postalCode, country, ISOcountryCode, coordinate, location, region;

- (NSString*)description {	
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          formattedAddress, @"formattedAddress",
                          subThoroughfare?subThoroughfare:[NSNull null], @"subThoroughfare",
                          thoroughfare?thoroughfare:[NSNull null], @"thoroughfare",
                          subLocality?subLocality:[NSNull null], @"subLocality",
                          locality?locality:[NSNull null], @"locality",
                          subAdministrativeArea?subAdministrativeArea:[NSNull null], @"subAdministrativeArea",
                          administrativeArea?administrativeArea:[NSNull null], @"administrativeArea",
                          postalCode?postalCode:[NSNull null], @"postalCode",
                          country?country:[NSNull null], @"country",
                          ISOcountryCode?ISOcountryCode:[NSNull null], @"ISOcountryCode",
                          [NSString stringWithFormat:@"%f, %f", self.coordinate.latitude, self.coordinate.longitude], @"coordinate",
                          nil];
    
	return [dict description];
}

@end
