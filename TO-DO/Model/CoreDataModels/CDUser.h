//
//  CDUser.h
//  TO-DO
//
//  Created by Siegrain on 16/6/2.
//  Copyright © 2016年 com.siegrain. All rights reserved.
//

#import "CDSync.h"
#import <Foundation/Foundation.h>

@class CDTodo;
@class LCUser;

NS_ASSUME_NONNULL_BEGIN

@interface CDUser : CDSync

@property (nonatomic, readwrite, strong) UIImage* avatarPhoto;

/**
 *  根据LCUser获取CDUser实体
 */
+ (instancetype)userWithLCUser:(LCUser*)lcUser;
@end

NS_ASSUME_NONNULL_END

#import "CDUser+CoreDataProperties.h"