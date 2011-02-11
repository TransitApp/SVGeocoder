//
//  SMGeocoderAppViewController.m
//  SMGeocoderApp
//
//  Created by Sam Vermette on 11.02.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SMGeocoderAppViewController.h"


@implementation SMGeocoderAppViewController


- (void)reverseGeocode {
	SMGeocoder *geocodeRequest = [[SMGeocoder alloc] initWithCoordinate:CLLocationCoordinate2DMake([latField.text floatValue], [lngField.text floatValue])];
	[geocodeRequest setDelegate:self];
	[geocodeRequest startAsynchronous];
}

- (void)geocode {
	SMGeocoder *geocodeRequest = [[SMGeocoder alloc] initWithAddress:addressField.text];
	[geocodeRequest setDelegate:self];
	[geocodeRequest startAsynchronous];
}

- (void)geocoder:(SMGeocoder *)geocoder didFindPlacemark:(MKPlacemark *)placemark {
	
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Placemark Found!" message:[[placemark addressDictionary] description] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alertView show];
	[alertView release];
}

- (void)geocoder:(SMGeocoder *)geocoder didFailWithError:(NSError *)error {
	
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:[error description] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alertView show];
	[alertView release];
	
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}

@end
