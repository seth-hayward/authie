//
//  ProfileViewController.h
//  authie
//
//  Created by Seth Hayward on 1/10/14.
//  Copyright (c) 2014 bitwise. All rights reserved.
//

@class RODHandle;
#import <UIKit/UIKit.h>

@interface ProfileViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIScrollView *scroll;
@property (weak, nonatomic) IBOutlet UILabel *handleLabel;
@property (weak, nonatomic) RODHandle *handle;

- (void)populateScrollView;

@end
