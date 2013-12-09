//
//  MNTileOverlay.h
//
//  Created by Dennis Oberhoff on 08/12/13.
//  Copyright (c) 2013 Dennis Oberhoff. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

@interface MNTileOverlay : MKTileOverlay

@property (strong, nonatomic) NSString *style;
@property (strong, nonatomic) NSOperationQueue *mapOperationQueue;

-(id)initWithStyle: (NSURL*)styleFile;

@end
