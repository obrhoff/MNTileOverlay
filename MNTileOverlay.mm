//
//  MNTileOverlay.mm
//
//  Created by Dennis Oberhoff on 08/12/13.
//  Copyright (c) 2013 Dennis Oberhoff. All rights reserved.
//

#import "MNTileOverlay.h"

#import <CoreLocation/CoreLocation.h>

#include <math.h>

#include <mapnik/graphics.hpp>
#include <mapnik/color.hpp>
#include <mapnik/image_util.hpp>
#include <mapnik/agg_renderer.hpp>
#include <mapnik/load_map.hpp>
#include <mapnik/datasource_cache.hpp>
#include <mapnik/datasource.hpp>

#include <mapnik/map.hpp>

#define CONVERT_SPHERE 0.149291
#define MERCATOR_RANGE 256;
#define degreesToRadians(x)    (x * M_PI / 180)
#define radiansToDegrees(x)    (x * 180 / M_PI)

using namespace mapnik;

@implementation MNTileOverlay

-(id)init{
    
    self = [super init];
    
    if (self) {
        
        self.geometryFlipped = NO;
        self.canReplaceMapContent = YES;
        self.maximumZ = 20;
        self.minimumZ = 8;
        self.style = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"style" ofType:@"xml"] encoding:NSUTF8StringEncoding error:nil];
        self.style = [self.style stringByReplacingOccurrencesOfString:@"RESOURCE_PATH" withString:[NSBundle mainBundle].resourcePath];

    }
    
    return self;
    
}

-(void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result{
    
    // should be probably wrapped into an NSOperation for better control furthermore implement something to cache tiles into this part
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *image = [self renderTileForPath:path];
        result(image, NULL);
        
    });

}

-(NSData*)renderTileForPath: (MKTileOverlayPath)path;{

    image_32 im(self.tileSize.width, self.tileSize.height);
    Map m(im.width(),im.height());
    
    load_map_string(m, std::string(self.style.UTF8String));
    m.zoom_to_box([self convertPathTo2dBox:path]);
    //  m.zoom_all();
    agg_renderer<mapnik::image_32> ren(m,im);
    ren.apply();
    
    size_t im_size = im.width() * im.height();
    size_t bitsPerComponent = 8;
    size_t bitsPerPixel = 32;
    size_t bytesPerRow = 4 * im.width();
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, im.raw_data(), im_size, NULL);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef iref = CGImageCreate(im.width(), im.height(), bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider,
                                    NULL, YES, renderingIntent);
    
    CGContextRef context = CGBitmapContextCreate(im.raw_data(), im.width(), im.height(),
                                                 bitsPerComponent, bytesPerRow, colorSpaceRef, bitmapInfo);
    
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, im.width(), im.height()), iref);
   
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *image = [UIImage imageWithCGImage:imageRef scale:path.contentScaleFactor orientation:UIDeviceOrientationPortrait];
    
    CGImageRelease(imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpaceRef);
    CGImageRelease(iref);
    CGDataProviderRelease(provider);
    
    return  UIImagePNGRepresentation(image);
}


-(box2d<double>)convertPathTo2dBox:(MKTileOverlayPath)path{
  
    CLLocationDegrees topLatitude = convertTileYPathToLatitude(path.y, path.z);
    CLLocationDegrees belowLatitude = convertTileYPathToLatitude(path.y + 1, path.z);
    CLLocationDegrees westLongitude = convertTileXPathToLongitude(path.x, path.z);
    CLLocationDegrees rightLongitude = convertTileXPathToLongitude(path.x + 1, path.z);
    
    return box2d<double>(westLongitude, belowLatitude, rightLongitude, topLatitude);
    
}


static CLLocationCoordinate2D getLatitudeLongitudeForPath(MKTileOverlayPath path) {
    
    CGFloat n = M_PI - 2 * M_PI * path.y / pow(2,path.z);
    CGFloat centerLatitude = path.x / pow(2, path.z) * 360 - 180;
    CGFloat centerLongitude = 180 / M_PI * atan(0.5 * (exp(n) - exp(-n)));

    return CLLocationCoordinate2DMake(centerLatitude, centerLongitude);

}

static CLLocationDegrees convertTileXPathToLongitude(NSInteger xPath, NSInteger zPath) {
   
    return (xPath / pow(2.0, zPath) * 360.0 - 180);

}

static CLLocationDegrees convertTileYPathToLatitude(NSInteger yPath, NSInteger zPath) {
    
    double n = M_PI - (2.0 * M_PI * yPath) / pow(2.0, zPath);
    return radiansToDegrees(atan(sinh(n)));
    
}

@end
