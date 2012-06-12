//
//  PDBrowseAllPoemsViewController.m
//  Poetry-Daily
//
//  Created by David Sklenar on 6/4/12.
//  Copyright (c) 2012 ELC Technologies. All rights reserved.
//

#import "PDBrowseAllPoemsViewController.h"
#import "PDFavoritesCoverFlowViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface PDBrowseAllPoemsViewController ()
- (void)orientationChanged:(NSNotification *)notification;

@end

@implementation PDBrowseAllPoemsViewController

#pragma mark - Properties
@synthesize isShowingLandscapeView = _isShowingLandscapeView;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if (self) 
    {
        self.title = NSLocalizedString(@"Archive", @"");
        self.tabBarItem.image = [UIImage imageNamed:@"33-cabinet"];
        
        NSDictionary *titleTextAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                       [UIFont boldSystemFontOfSize:10.0f], UITextAttributeFont,
                                                       [UIColor darkGrayColor], UITextAttributeTextColor,
                                                       nil];
        
        NSDictionary *titleTextHighlightedAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                  [UIFont boldSystemFontOfSize:10.0f], UITextAttributeFont,
                                                                  [UIColor blackColor], UITextAttributeTextColor,
                                                                  nil];
        
        [self.tabBarItem setTitleTextAttributes:titleTextAttributesDictionary forState:UIControlStateNormal];
        [self.tabBarItem setTitleTextAttributes:titleTextHighlightedAttributesDictionary forState:UIControlStateSelected];
    
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:.8819 green:.84212 blue:.7480 alpha:1.0];
    
    self.isShowingLandscapeView = NO;
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];

}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)orientationChanged:(NSNotification *)notification
{
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (UIDeviceOrientationIsLandscape(deviceOrientation) && !self.isShowingLandscapeView)
    {
        PDFavoritesCoverFlowViewController *favoriteFlow = [[PDFavoritesCoverFlowViewController alloc] initWithNibName:@"PDFavoritesCoverFlowViewController" bundle:nil];
        favoriteFlow.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        
        [self presentModalViewController:favoriteFlow animated:YES];
        self.isShowingLandscapeView = YES;
    }
    else if (UIDeviceOrientationIsPortrait(deviceOrientation) && self.isShowingLandscapeView)
    {
        [UIView animateWithDuration:0.5f animations:^{
            
        } completion:^(BOOL finished) {
            [self dismissModalViewControllerAnimated:YES];
            self.isShowingLandscapeView = NO;
        }];
    }
}


#pragma mark - UITableView Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    return 100.0f;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
{
    
}


#pragma mark - UITableView Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    return 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if ( cell == nil) 
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        
        UIImageView *thumbnailImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10.0f, 10.0f, 60.0f, 80.0f)];
        thumbnailImageView.tag = 99;
        thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
        thumbnailImageView.image = [UIImage imageNamed:@"plumlystanley.jpeg"];;
        thumbnailImageView.clipsToBounds = YES;
        thumbnailImageView.backgroundColor = [UIColor lightGrayColor];
        thumbnailImageView.clipsToBounds = NO;
        thumbnailImageView.layer.shadowColor = [UIColor blackColor].CGColor;
        thumbnailImageView.layer.shadowOffset = CGSizeMake( 0.0f, 1.0f );
        thumbnailImageView.layer.shadowRadius = 2.0f;
        thumbnailImageView.layer.shadowOpacity = 0.5f;       
        thumbnailImageView.layer.shouldRasterize = YES;
        thumbnailImageView.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        [cell.contentView addSubview:thumbnailImageView];
        
        UILabel *poemTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(80.0f, 10.0f, 230.0f, 20.0f)];
        poemTitleLabel.text = @"Poem Title Goes Here";
        poemTitleLabel.tag = 100;
        poemTitleLabel.font = [UIFont boldSystemFontOfSize:14.0f];
        poemTitleLabel.textAlignment = UITextAlignmentLeft;
        poemTitleLabel.textColor = [UIColor darkGrayColor];
        poemTitleLabel.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:poemTitleLabel];
        
        UILabel *authorNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(80.0f, 30.0f, 230.0f, 20.0f)];
        authorNameLabel.text = @"By David Sklenar";
        authorNameLabel.tag = 101;
        authorNameLabel.textAlignment = UITextAlignmentLeft;
        authorNameLabel.font = [UIFont systemFontOfSize:12.0f];
        authorNameLabel.textColor = [UIColor darkGrayColor];
        authorNameLabel.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:authorNameLabel];
        
        UILabel *publishedDateLabel = [[UILabel alloc] initWithFrame:CGRectMake(80.0f, 30.0f, 230.0f, 20.0f)];
        publishedDateLabel.text = @"By David Sklenar";
        publishedDateLabel.tag = 101;
        publishedDateLabel.textAlignment = UITextAlignmentLeft;
        publishedDateLabel.font = [UIFont systemFontOfSize:12.0f];
        publishedDateLabel.textColor = [UIColor darkGrayColor];
        publishedDateLabel.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:authorNameLabel];      
        
        UIButton *lockUnlockButton = [UIButton buttonWithType:UIButtonTypeCustom];
        lockUnlockButton.tag = 104;
        lockUnlockButton.frame = CGRectMake(490, 0.0f, 40.0f, 100.0f);
        [lockUnlockButton setImage:[UIImage imageNamed:@"dvr_unlocked_icon"] forState:UIControlStateNormal];
        [lockUnlockButton addTarget:self action:@selector(batchLockOrUnlockAiring:) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:lockUnlockButton];
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

@end
