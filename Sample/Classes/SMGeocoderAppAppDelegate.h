//
//  SMGeocoderAppAppDelegate.h
//  SMGeocoderApp
//
//  Created by Sam Vermette on 11.02.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SMGeocoderAppViewController;

@interface SMGeocoderAppAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    SMGeocoderAppViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet SMGeocoderAppViewController *viewController;

@end

