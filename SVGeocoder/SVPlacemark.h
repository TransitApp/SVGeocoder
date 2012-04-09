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

@interface SVPlacemark : MKPlacemark {

}

@property (nonatomic, readwrite) CLLocationCoordinate2D coordinate;
@property (nonatomic, copy) CLRegion *region;
@property (nonatomic, retain) NSString * formattedAddress;

- (id)initWithRegion:(CLRegion *)region addressDictionary:(NSDictionary *)addressDictionary;

@end
