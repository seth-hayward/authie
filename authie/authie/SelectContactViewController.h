//
//  SelectContactViewController.h
//  authie
//
//  Created by Seth Hayward on 1/10/14.
//  Copyright (c) 2014 bitwise. All rights reserved.
//

@class RODHandle;
#import <NBUImagePicker/NBUCameraViewController.h>
#import <UIKit/UIKit.h>
#import "GAITrackedViewController.h"

@interface SelectContactViewController : GAITrackedViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource>
@property (strong, nonatomic) RODHandle *selected;
@property (nonatomic, strong) IBOutlet UIView *addContactCell;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic) bool editingContacts;

- (void)showAuthorizationRequestImagePicker;
- (void)addContact:(id)sender;

@end
