//
//  PDTwitterViewController.h
//  Poetry-Daily
//
//  Created by David Sklenar on 6/5/12.
//  Copyright (c) 2012 ELC Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PDTwitterViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate>

@property (strong, nonatomic) UIImage *pdLogoImage;
@property (strong, nonatomic) NSArray *tweetsArray;

@property (strong, nonatomic) IBOutlet UITableView *tweetsTableView;

@end
