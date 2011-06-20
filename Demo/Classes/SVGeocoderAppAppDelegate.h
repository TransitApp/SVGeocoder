//
//  SMGeocoderAppAppDelegate.h
//  SMGeocoderApp
//
//  Created by Sam Vermette on 11.02.11.
//  Copyright 2011 Sam Vermette. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SVGeocoderAppViewController;

@interface SVGeocoderAppAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    SVGeocoderAppViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet SVGeocoderAppViewController *viewController;

@end

