//
// SVGeocoder.h
//
// Created by Sam Vermette on 07.02.11.
// Copyright 2011 samvermette.com. All rights reserved.
//
// https://github.com/samvermette/SVGeocoder
// http://code.google.com/apis/maps/documentation/geocoding/
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

#import "SVPlacemark.h"

typedef enum {
	SVGeocoderZeroResultsError = 1,
	SVGeocoderOverQueryLimitError,
	SVGeocoderRequestDeniedError,
	SVGeocoderInvalidRequestError,
    SVGeocoderJSONParsingError
} SVGecoderError;

@protocol SVGeocoderDelegate;

@interface SVGeocoder : NSOperation

+ (SVGeocoder*)geocode:(NSString *)address completion:(void (^)(NSArray *placemarks, NSError *error))block;
+ (SVGeocoder*)geocode:(NSString *)address bounds:(MKCoordinateRegion)bounds completion:(void (^)(NSArray *placemarks, NSError *error))block;
+ (SVGeocoder*)geocode:(NSString *)address region:(NSString *)region completion:(void (^)(NSArray *placemarks, NSError *error))block;

+ (SVGeocoder*)reverseGeocode:(CLLocationCoordinate2D)coordinate completion:(void (^)(NSArray *placemarks, NSError *error))block;

- (void)cancel;

// old API; these methods will soon get deprecated

@property (nonatomic, assign) id<SVGeocoderDelegate> delegate;
@property (readonly, getter = isQuerying) BOOL querying;

// Reverse Geocoder
- (SVGeocoder*)initWithCoordinate:(CLLocationCoordinate2D)coordinate;

// (forward) Geocoder
- (SVGeocoder*)initWithAddress:(NSString *)address;
- (SVGeocoder*)initWithAddress:(NSString *)address inBounds:(MKCoordinateRegion)bounds;
- (SVGeocoder*)initWithAddress:(NSString *)address inRegion:(NSString *)regionString;

- (void)startAsynchronous;

@end


@protocol SVGeocoderDelegate

@optional
- (void)geocoder:(SVGeocoder *)geocoder didFindPlacemark:(SVPlacemark *)placemark; // SVPlacemark is an MKPlacemark subclass with a coordinate property
- (void)geocoder:(SVGeocoder *)geocoder didFindPlacemarks:(NSArray *)placemarks; // array of SVPlacemark objects
- (void)geocoder:(SVGeocoder *)geocoder didFailWithError:(NSError *)error;

@end