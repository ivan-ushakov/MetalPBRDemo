//
//  TGAFile.h
//  MetalRobot
//
//  Created by  Ivan Ushakov on 18/01/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TGAFile : NSObject

@property (nonatomic, readonly) NSInteger width;

@property (nonatomic, readonly) NSInteger height;

@property (nonatomic, readonly) const uint8 *data;

- (BOOL)load:(NSString *)path error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
