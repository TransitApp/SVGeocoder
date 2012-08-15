//
// SVPlacemark.h
// SVGeocoder
//
// Created by Sam Vermette on 01.05.11.
// Copyright 2011 samvermette.com. All rights reserved.
//
// https://github.com/samvermette/SVGeocoder
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface SVPlacemark : NSObject

@property (nonatomic, strong) NSString *formattedAddress;
@property (nonatomic, strong) NSString *subThoroughfare;
@property (nonatomic, strong) NSString *thoroughfare;
@property (nonatomic, strong) NSString *subLocality;
@property (nonatomic, strong) NSString *locality;
@property (nonatomic, strong) NSString *subAdministrativeArea;
@property (nonatomic, strong) NSString *administrativeArea;
@property (nonatomic, strong) NSString *administrativeAreaCode;
@property (nonatomic, strong) NSString *postalCode;
@property (nonatomic, strong) NSString *country;
@property (nonatomic, strong) NSString *ISOcountryCode;

@property (nonatomic, readwrite) CLLocationCoordinate2D coordinate;
@property (nonatomic, readwrite) MKCoordinateRegion region;
@property (nonatomic, strong) CLLocation *location;

@end
