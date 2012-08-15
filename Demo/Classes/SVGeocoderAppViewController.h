//
//  SVGeocoderAppViewController.h
//  SVGeocoderApp
//
//  Created by Sam Vermette on 11.02.11.
//  Copyright 2011 Sam Vermette. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SVGeocoder.h"

@interface SVGeocoderAppViewController : UIViewController {
	IBOutlet UITextField *latField, *lngField, *addressField;
}

- (IBAction)reverseGeocode;
- (IBAction)geocode;

@end

