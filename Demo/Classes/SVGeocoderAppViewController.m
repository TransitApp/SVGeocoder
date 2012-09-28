//
//  SVGeocoderAppViewController.m
//  SVGeocoderApp
//
//  Created by Sam Vermette on 11.02.11.
//  Copyright 2011 Sam Vermette. All rights reserved.
//

#import "SVGeocoderAppViewController.h"


@implementation SVGeocoderAppViewController


- (void)reverseGeocode {
    [SVGeocoder reverseGeocode:CLLocationCoordinate2DMake(latField.text.floatValue, lngField.text.floatValue)
                    completion:^(NSArray *placemarks, NSHTTPURLResponse *urlResponse, NSError *error) {
                        NSLog(@"placemarks = %@", placemarks);
                    }];
}

- (void)geocode {
    [SVGeocoder geocode:addressField.text
             completion:^(NSArray *placemarks, NSHTTPURLResponse *urlResponse, NSError *error) {
                 NSLog(@"placemarks = %@", placemarks);
             }];
}

@end
