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

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) IBOutlet SVGeocoderAppViewController *viewController;

@end

