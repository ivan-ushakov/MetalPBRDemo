//
//  TGAFile.m
//  MetalRobot
//
//  Created by  Ivan Ushakov on 18/01/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#import "TGAFile.h"

#include "targa.h"

@implementation TGAFile {
    tga_image _image;
}

- (NSInteger)width {
    return _image.width;
}

- (NSInteger)height {
    return _image.height;
}

- (const uint8_t *)data {
    return _image.image_data;
}

- (BOOL)load:(NSString *)path error:(NSError * _Nullable * _Nullable)error {
    if (tga_read(&_image, path.UTF8String) == TGA_NOERR) {
        if (_image.image_type == TGA_IMAGE_TYPE_COLORMAP) {
            if (tga_color_unmap(&_image) != TGA_NOERR) {
                *error = [NSError errorWithDomain:@"TGAFile" code:0 userInfo:nil];
                return NO;
            }
        }
        
        if (tga_convert_depth(&_image, 32) != TGA_NOERR) {
            *error = [NSError errorWithDomain:@"TGAFile" code:0 userInfo:nil];
            return NO;
        }
        
        return YES;
    }
    
    *error = [NSError errorWithDomain:@"TGAFile" code:0 userInfo:nil];
    return NO;
}

@end
