//
//  SMGeocoderAppViewController.h
//  SMGeocoderApp
//
//  Created by Sam Vermette on 11.02.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SMGeocoder.h"

@interface SMGeocoderAppViewController : UIViewController <SMGeocoderDelegate> {
	IBOutlet UITextField *latField, *lngField, *addressField;
}

- (IBAction)reverseGeocode;
- (IBAction)geocode;

@end

