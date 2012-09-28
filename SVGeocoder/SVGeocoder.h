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
#import <CoreLocation/CoreLocation.h>

#import "SVPlacemark.h"

typedef enum {
	SVGeocoderZeroResultsError = 1,
	SVGeocoderOverQueryLimitError,
	SVGeocoderRequestDeniedError,
	SVGeocoderInvalidRequestError,
    SVGeocoderJSONParsingError
} SVGecoderError;


typedef void (^SVGeocoderCompletionHandler)(NSArray *placemarks, NSHTTPURLResponse *urlResponse, NSError *error);

@interface SVGeocoder : NSOperation

+ (SVGeocoder*)geocode:(NSString *)address completion:(SVGeocoderCompletionHandler)block;
+ (SVGeocoder*)geocode:(NSString *)address region:(CLRegion *)region completion:(SVGeocoderCompletionHandler)block;

+ (SVGeocoder*)reverseGeocode:(CLLocationCoordinate2D)coordinate completion:(SVGeocoderCompletionHandler)block;

- (SVGeocoder*)initWithAddress:(NSString *)address completion:(SVGeocoderCompletionHandler)block;
- (SVGeocoder*)initWithAddress:(NSString *)address region:(CLRegion *)region completion:(SVGeocoderCompletionHandler)block;

- (SVGeocoder*)initWithCoordinate:(CLLocationCoordinate2D)coordinate completion:(SVGeocoderCompletionHandler)block;

- (void)start;
- (void)cancel;

@end