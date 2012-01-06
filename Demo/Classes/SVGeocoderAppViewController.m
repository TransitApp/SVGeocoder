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
                    completion:^(NSArray *placemarks, NSError *error) {
                        UIAlertView *alertView;
                        
                        if(!error && placemarks) {
                            SVPlacemark *placemark = [placemarks objectAtIndex:0];
                            alertView = [[UIAlertView alloc] initWithTitle:@"Placemark Found!" message:[placemark description] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                        } else {
                            alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:[error description] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                        }
                        
                        [alertView show];
                        [alertView release];
                    }];
}

- (void)geocode {
    [SVGeocoder geocode:addressField.text
             completion:^(NSArray *placemarks, NSError *error) {
                 UIAlertView *alertView;
                 
                 if(!error && placemarks) {
                     SVPlacemark *placemark = [placemarks objectAtIndex:0];
                     alertView = [[UIAlertView alloc] initWithTitle:@"Placemark Found!" message:[placemark description] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                 } else {
                     alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:[error description] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                 }
                 
                 [alertView show];
                 [alertView release];
             }];
}

@end
