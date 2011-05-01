//
//  SVGeocoder.h
//
//  Created by Sam Vermette on 07.02.11.
//  Copyright 2011 Sam Vermette. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

#import "SVPlacemark.h"

@protocol SVGeocoderDelegate;

@interface SVGeocoder : NSObject {

}

@property (nonatomic, assign) id<SVGeocoderDelegate> delegate;

- (SVGeocoder*)initWithCoordinate:(CLLocationCoordinate2D)coordinate;
- (SVGeocoder*)initWithAddress:(NSString *)address inRegion:(MKCoordinateRegion)region;
- (SVGeocoder*)initWithAddress:(NSString *)address;

- (void)startAsynchronous;

@end


@protocol SVGeocoderDelegate

- (void)geocoder:(SVGeocoder *)geocoder didFindPlacemark:(SVPlacemark *)placemark;
- (void)geocoder:(SVGeocoder *)geocoder didFailWithError:(NSError *)error;

@end