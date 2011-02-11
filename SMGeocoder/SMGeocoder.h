//
//  SMGeocoder.h
//
//  Created by Sam Vermette on 07.02.11.
//  Copyright 2011 Sam Vermette. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@protocol SMGeocoderDelegate;

@interface SMGeocoder : NSObject {
    NSMutableData *responseData;
	NSURLConnection *rConnection;
	NSURLRequest *request;
}

@property (nonatomic, assign) id<SMGeocoderDelegate> delegate;

- (SMGeocoder*)initWithCoordinate:(CLLocationCoordinate2D)coordinate;
- (SMGeocoder*)initWithAddress:(NSString*)address;

- (void)startAsynchronous;

@end


@protocol SMGeocoderDelegate

- (void)geocoder:(SMGeocoder *)geocoder didFindPlacemark:(MKPlacemark *)placemark;
- (void)geocoder:(SMGeocoder *)geocoder didFailWithError:(NSError *)error;

@end