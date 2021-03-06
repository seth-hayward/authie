//
//  PrivateKeyViewController.m
//  authie
//
//  Created by Seth Hayward on 1/10/14.
//  Copyright (c) 2014 bitwise. All rights reserved.
//

#import "PrivateKeyViewController.h"
#import "RODItemStore.h"
#import "RODAuthie.h"
#import "RODHandle.h"
#import "NavigationController.h"

@implementation PrivateKeyViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.navigationItem.titleView = [[RODItemStore sharedStore] generateHeaderView];
 

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    
    [[RODItemStore sharedStore] getPrivateKey];
    
    NSLog(@"Will appear: %@",[RODItemStore sharedStore].authie.privateKey);
    
    self.privateKey.text = [[RODItemStore sharedStore].authie.privateKey substringToIndex:5];

    UIFont *lz10f =[UIFont fontWithName:@"LucidaTypewriter" size:12.0f];
    UIFont *lz14f =[UIFont fontWithName:@"LucidaTypewriter" size:30.0f];
    [self.privateKey setFont:lz14f];
    [self.privateKeyHeaderLabel setFont:lz10f];
    [self.privateKeyTextLabel setFont:lz10f];
    
    self.screenName = @"PrivateKey";

    self.navigationItem.leftBarButtonItem = [[RODItemStore sharedStore] generateMenuItem:@"key-v3-white"];

}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)markRead:(id)sender {
    [[RODItemStore sharedStore] markRead];
}
@end
