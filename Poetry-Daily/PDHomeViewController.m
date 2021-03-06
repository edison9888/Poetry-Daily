//
//  PDHomeViewController.m
//  Poetry-Daily
//
//  Created by David Sklenar on 5/24/12.
//  Copyright (c) 2012 ELC Technologies. All rights reserved.
//

#import "PDHomeViewController.h"
#import "PDMainPoemViewController.h"
#import "PDCachedDataController.h"
#import "PDMediaServer.h"
#import "PDPoem.h"
#import <QuartzCore/QuartzCore.h>
#import "SVProgressHUD.h"
#import "PDConstants.h"
#import "PDFeatureViewController.h"
#import "NSDate+PDAdditions.h"
#import "SVWebViewController.h"
#import "PDBrowseAllPoemsViewController.h"
#import "iCarousel.h"
#import "PDSponsor.h"

#define REFRESH_HEADER_HEIGHT 52.0f

@interface PDHomeViewController ()

- (void)swipePreviousDay:(UISwipeGestureRecognizer *)swipeGesture;
- (void)swipeNextDay:(UISwipeGestureRecognizer *)swipeGesture;
- (void)updatePoemInformationForPoem:(PDPoem *)poem animated:(BOOL)animated;
- (IBAction)showToday:(id)sender;

@property (strong, nonatomic) NSURL *publicationURL;

@property (nonatomic, strong) UIView *readPoemNowContainerView;

@property (nonatomic, strong) UIView *refreshHeaderView;
@property (nonatomic, strong) UILabel *refreshLabel;
@property (nonatomic, strong) UIImageView *refreshArrow;
@property (nonatomic, strong) UIActivityIndicatorView *refreshSpinner;
@property (nonatomic, strong) UILabel *refreshLogoActivityLabel;
@property (nonatomic, strong) NSString *textPull;
@property (nonatomic, strong) NSString *textRelease;
@property (nonatomic, strong) NSString *textLoading;
@property (nonatomic, readwrite) BOOL isDragging;
@property (nonatomic, readwrite) BOOL isLoading;

@property (strong, nonatomic) UIPopoverController *sharedPopoverController;

- (void)setupStrings;
- (void)addPullToRefreshHeader;
- (void)startLoading;
- (void)stopLoading;
- (void)refresh;


@end

@implementation PDHomeViewController


#pragma mark - Properties

@synthesize currentPoem = _currentPoem;
@synthesize poemPublishedDateLabel = _poemPublishedDateLabel;
@synthesize poemTitleLabel = poemTitleLabel;
@synthesize poemAuthorLabel = _poemAuthorLabel;
@synthesize poemAuthorImageView = _poemAuthorImageView;
@synthesize readPoemButton = _readPoemButton;
@synthesize showPreviousDayButton = _showPreviousDayButton;
@synthesize showNextDayButton = _showNextDayButton;


#pragma mark - API

- (IBAction)showMainPoemView:(id)sender;
{
    PDMainPoemViewController *mainViewController = [[PDMainPoemViewController alloc] initWithNibName:@"PDMainPoemViewController" bundle:nil];
     
    [self.navigationController pushViewController:mainViewController animated:YES];

    [mainViewController setCurrentPoem:self.currentPoem];
}


#pragma mark - Private API

- (IBAction)showFeatureInformation:(id)sender;
{
    PDFeatureViewController *feature = [[PDFeatureViewController alloc] initWithNibName:@"PDFeatureViewController" bundle:nil];
    
    [feature setPoemID:self.currentPoem.poemID];
    
    [self.navigationController pushViewController:feature animated:YES];
}

- (IBAction)showArchiveInPopover:(id)sender;
{
    PDBrowseAllPoemsViewController *browse = [[PDBrowseAllPoemsViewController alloc] initWithNibName:@"PDBrowseAllPoemsViewController" bundle:nil];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:browse];
    
    UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:nav];
    self.sharedPopoverController = popover;
    [self.sharedPopoverController presentPopoverFromRect:[(UIButton *)sender frame] inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void)showPoemForDay:(NSDate *)date;
{
    PDMediaServer *server = [[PDMediaServer alloc] init];
    NSString *poemID = [server poemIDFromDate:date];

    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Poem"];
    
    NSMutableDictionary *serverInfo = [[NSMutableDictionary alloc] initWithCapacity:2];
    [serverInfo setObject:poemID forKey:PDPoemKey];
    [serverInfo setObject:[NSNumber numberWithInteger:PDServerCommandPoem] forKey:PDServerCommandKey];
    
    request.predicate = [NSPredicate predicateWithFormat:@"SELF.poemID == %@", poemID];
    request.fetchLimit = 1;
    
    NSArray *items = [[PDCachedDataController sharedDataController] fetchObjects:request serverInfo:serverInfo cacheUpdateBlock:^(NSArray *newResults, NSError *error) {
        
        
        if ( !newResults && error )
        {
            [SVProgressHUD show];
            [SVProgressHUD dismissWithError:@"Failed To Load"];
            [self.poemAuthorImageActivityView stopAnimating];
            self.readPoemButton.enabled = ( self.currentPoem != nil) ;
            return;
        }
                PDPoem *poem = [newResults lastObject];
        
                if ( poem && [poemID isEqualToString:poem.poemID] )
                {
                    [self updatePoemInformationForPoem:poem animated:NO];
                    
                    _currentPoem = poem;
                    
                    self.readPoemButton.enabled = YES;
                    
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
                    [dateFormatter setDateStyle:NSDateFormatterLongStyle];
                    
                    [UIView animateWithDuration:0.15f animations:^{
                        
                        self.poemPublishedDateLabel.alpha = 0.0f;
                        
                    } completion:^(BOOL finished) {
                        
                        self.poemPublishedDateLabel.text = [dateFormatter stringFromDate:poem.publishedDate];

                        [UIView animateWithDuration:0.4f animations:^{ self.poemPublishedDateLabel.alpha = 1.0f; } completion:NULL];
                    }];
                
                    
                    if ( self.currentPoem.isFavorite.boolValue )
                        [self.favoriteBarButtonItem setTitle:@"★"];
                    else
                        [self.favoriteBarButtonItem setTitle:@"☆"];

                    
                    if ( poem.authorImageURLString.length > 0 && poem.authorImageData.length == 0 && !poem.hasAttemptedDownload)
                    {
                        PDMediaServer *server = [[PDMediaServer alloc] init];
                        
                        [server fetchPoetImagesWithStrings:@[poem.authorImageURLString] isJournalImage:poem.isJournalImage block:^(NSArray *items, NSError *error) {
                            
                            if ( items && !error )
                            {
                                NSLog(@"Found Image.");
                                
                                
                                dispatch_async( dispatch_get_main_queue(), ^{
                                    
                                    NSData *newImageData = items[0];
                                    poem.authorImageData  = newImageData;
                                    
                                    [UIView animateWithDuration:0.0f animations:^{
                                        
                                        self.poemAuthorImageView.alpha = 0.0f;
                                        
                                    } completion:^(BOOL finished) {
                                        
                                        [self.poemAuthorImageActivityView stopAnimating];
                                        
                                        self.poemAuthorImageView.image = poem.authorImage;
                                        
                                        CGRect newFrame = self.poemAuthorImageView.frame;
                                        newFrame.size.height = poem.authorImage.size.height;
                                        self.poemAuthorImageView.frame = newFrame;
                                        
                                        [self.tableView beginUpdates];
                                        [self.tableView endUpdates];
//                                        [self.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
                                        
                                        [UIView animateWithDuration:0.2f animations:^{
                                            
                                            self.poemAuthorImageView.alpha = 1.0f;
                                            
                                        } completion:NULL];
                                    }];
                                    
                                    poem.hasAttemptedDownload = YES;
                                });
                                
                            }
                            else
                            {
                                poem.hasAttemptedDownload = NO;
                            }
                            
                        }];
                    }   
                    BOOL isToday = ( [date timeIntervalSinceDate:[NSDate charlottesvilleDate]] > -1000.0f  );
                    
                    self.showNextDayButton.hidden = isToday;         
                    self.todaysPoemLabel.hidden = !isToday;

                    self.textPull = isToday ? @"Pull down to refresh today's poem..." : @"Pull down to go to today's poem...";
                    self.textRelease = isToday ? @"Release to refresh today's poem..." : @"Release to go to today's poem...";

                    
                    [SVProgressHUD dismiss];
                }
         }];
    
    PDPoem *poem = [items lastObject];
    
    if ( poem )
    {
        [self updatePoemInformationForPoem:poem animated:YES];

        _currentPoem = poem;
        
        self.readPoemButton.enabled = YES;

        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        [dateFormatter setDateStyle:NSDateFormatterLongStyle];

        
        [UIView animateWithDuration:0.2f animations:^{
            
            self.poemPublishedDateLabel.alpha = 0.0f;
            
        } completion:^(BOOL finished) {
            
            self.poemPublishedDateLabel.text = [dateFormatter stringFromDate:poem.publishedDate];
            
            [UIView animateWithDuration:0.5f animations:^{
                
//                self.poemPublishedDateLabel.alpha = 1.0f;
                
            } completion:NULL];
        }];
        
        
        if ( poem.authorImage )
        {
            self.poemAuthorImageView.image = poem.authorImage;
                        
            CGRect newFrame = self.poemAuthorImageView.frame;
            newFrame.size.height = poem.authorImage.size.height;
            self.poemAuthorImageView.frame = newFrame;
            
            [self.tableView beginUpdates];
            [self.tableView endUpdates];

        }
        else
            [UIView animateWithDuration:0.1 animations:^{
                
                [self.poemAuthorImageActivityView startAnimating];
                
                self.poemAuthorImageView.alpha = 0.0f;
            }];
        
        BOOL isToday = ( [date timeIntervalSinceDate:[NSDate charlottesvilleDate]] > -1000.0f  );
        
        self.showNextDayButton.hidden = isToday;
        self.todaysPoemLabel.hidden = !isToday;
        
        self.textPull = isToday ? @"Pull down to refresh today's poem..." : @"Pull down to go to today's poem...";
        self.textRelease = isToday ? @"Release to refresh today' poem..." : @"Release to go to today's poem...";
        
        if ( poem.title.length > 0 && poem.author.length > 0  )
            [SVProgressHUD dismiss];
        else
            [SVProgressHUD showWithStatus:NSLocalizedString(@"Fetching Poem...", @"Fetching Poem...")];
    }
    else
    {
        self.readPoemButton.enabled = NO;
    }

    if ( YES )
    {
        [server fetchFeatureWithID:poemID block:^(NSArray *items, NSError *error) {
           
            if ( items && !error)
            {
                NSDictionary *featureAttributesDictionary = [items lastObject];

                NSString *poetInfo = [featureAttributesDictionary objectForKey:@"poetLT"];
                NSString *journalInfo = [featureAttributesDictionary objectForKey:@"jText"];

                
                self.publicationURL = [NSURL URLWithString:[featureAttributesDictionary objectForKey:@"puburl"]];
                
                NSString *publisherName = [featureAttributesDictionary objectForKey:@"publisher"];
                NSString *pubURLString = [featureAttributesDictionary objectForKey:@"puburl"];
                self.iPadVisitPublicationPageButton.hidden = ( [pubURLString length] == 0 );
                
                [self.iPadVisitPublicationPageButton setTitle:[NSString stringWithFormat:@"Visit %@ Site ⇗", ([publisherName length] == 0 ) ? @"Publisher" : publisherName] forState:UIControlStateNormal];
                
                if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                {                
                    NSMutableString *HTML = [[NSMutableString alloc] init];
                    
                    [HTML appendString:[NSString stringWithFormat:@"<html><head><style type=\"text/css\"> body {font-family:helvetica,sans-serif; font-size: 20px;  white-space:normal; padding:0px; margin:0px;}</style></head><body>"]];
                    NSString *combinedInfo = [NSString stringWithFormat:@"%@<br>%@", poetInfo, journalInfo];
                    
                    [HTML appendString:combinedInfo];
                    [HTML appendString:@"</body></html>"];

                    [self.tableView beginUpdates];
                    [self.iPadfeatureInformationWebView loadHTMLString:combinedInfo baseURL:nil];
                    
                    [self.iPadfeatureInformationWebView sizeToFit];
                    [self.tableView endUpdates];
                }
                else
                {
                    NSMutableString *HTML = [[NSMutableString alloc] init];
                    
                    [HTML appendString:[NSString stringWithFormat:@"<html><head><style type=\"text/css\"> body {font-family:helvetica,sans-serif; font-size: 16px;  white-space:normal; padding:0px; margin:0px;}</style></head><body>"]];
                    NSString *combinedInfo = [NSString stringWithFormat:@"%@<br>", poetInfo];
                    
                    [HTML appendString:combinedInfo];
                    [HTML appendString:@"</body></html>"];
                    
                    [self.tableView beginUpdates];
                    [self.poetInfoWebView loadHTMLString:HTML baseURL:nil];
                    self.poetInfoWebView.scrollView.scrollEnabled = NO;
                    [self.poetInfoWebView sizeToFit];
                    
                    NSMutableString *publicationHTML = [[NSMutableString alloc] init];
                    
                    [publicationHTML appendString:[NSString stringWithFormat:@"<html><head><style type=\"text/css\"> body {font-family:helvetica,sans-serif; font-size: 16px;  white-space:normal; padding:0px; margin:0px;}</style></head><body>"]];
                    NSString *combinedPublicationInfo = [NSString stringWithFormat:@"%@<br>", journalInfo];
                    
                    [publicationHTML appendString:combinedPublicationInfo];
                    [publicationHTML appendString:@"</body></html>"];
                    
                    [self.publicationInfoWebView loadHTMLString:publicationHTML baseURL:nil];
                    self.publicationInfoWebView.scrollView.scrollEnabled = NO;
                    [self.publicationInfoWebView sizeToFit];

                    [self.tableView endUpdates];
                }
            }
            
            [self stopLoading];
        }];
    }
}

- (IBAction)fetchRandomPoem:(id)sender;
{
    int randomInterval = arc4random() % 365 * 24 * 60 * 60 * -1;
    NSDate *randomDate = [NSDate dateWithTimeIntervalSinceNow:randomInterval];

    [self showPoemForDay:randomDate];
}

- (IBAction)showPreviousDay:(id)sender;
{
    NSDate *newDate = [self.currentPoem.publishedDate dateByAddingTimeInterval:-86400.0f];
    
    [self showPoemForDay:newDate];
}

- (void)swipePreviousDay:(UISwipeGestureRecognizer *)swipeGesture;
{
    NSDate *newDate = [self.currentPoem.publishedDate dateByAddingTimeInterval:-86400.0f];
    
    if ( [newDate timeIntervalSinceDate:[NSDate charlottesvilleDate]] > -1000.0f )
        return;
    
    [self showPoemForDay:newDate];
}

- (IBAction)showNextDay:(id)sender;
{
    NSDate *newDate = [self.currentPoem.publishedDate dateByAddingTimeInterval:86400.0f];
        
    [self showPoemForDay:newDate];
}

- (IBAction)showToday:(id)sender;
{
    PDMediaServer *server = [[PDMediaServer alloc] init];
    
    NSString *todaysPoemID = [server poemIDFromDate:[NSDate charlottesvilleDate]];
    
    if ( [self.currentPoem.poemID isEqualToString:todaysPoemID] )
        return;
    else
        [self showPoemForDay:[NSDate charlottesvilleDate]];
}

- (IBAction)showPublicationSite:(id)sender;
{
    SVModalWebViewController *webViewController = [[SVModalWebViewController alloc] initWithURL:self.publicationURL];
    
    webViewController.navigationBar.tintColor = [UIColor colorWithRed:.8819 green:.84212 blue:.7480 alpha:1.0];
    webViewController.navigationController.toolbar.tintColor = [UIColor colorWithRed:90.0f/255.0 green:33.0f/255.0 blue:40.0f/255.0 alpha:1.0];

    NSLog(@"Visiting external site at %@", [self.publicationURL absoluteString]);
    
//    webViewController.modalPresentationStyle = UIModalPresentationPageSheet;
//    webViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
//    
//    if ( [self respondsToSelector:@selector(presentViewController:animated:completion:)] )
//        [self presentModalViewController:webViewController animated:YES completion:^(BOOL completed){     webViewController.navigationController.toolbar.tintColor = [UIColor colorWithRed:90.0f/255.0 green:33.0f/255.0 blue:40.0f/255.0 alpha:1.0];}];
//    else
//        [self presentModalViewController:webViewController animated:YES];
//

    
    webViewController.navigationController.toolbar.tintColor = [UIColor colorWithRed:90.0f/255.0 green:33.0f/255.0 blue:40.0f/255.0 alpha:1.0];

    
    webViewController.navigationBar.tintColor = [UIColor colorWithRed:.8819 green:.84212 blue:.7480 alpha:1.0];

}

- (void)swipeNextDay:(UISwipeGestureRecognizer *)swipeGesture;
{
    NSDate *newDate = [self.currentPoem.publishedDate dateByAddingTimeInterval:86400.0f];
    
    if ( [newDate timeIntervalSinceDate:[NSDate charlottesvilleDate]] > -1000.0f )
        return;
    
    [self showPoemForDay:newDate];
}

- (void)updatePoemInformationForPoem:(PDPoem *)poem animated:(BOOL)animated;
{
    NSMutableString *HTML = [[NSMutableString alloc ] init];
   
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        [HTML appendString:[NSString stringWithFormat:@"<html><head><style type=\"text/css\"> body {font-family:helvetica,sans-serif; font-size: 16px;  white-space:normal; padding:0px; margin:0px;}</style></head><body>"]];
    }
    else
    {
        [HTML appendString:[NSString stringWithFormat:@"<html><head><style type=\"text/css\"> body {font-family:helvetica,sans-serif; font-size: 24px;  white-space:normal; padding:0px; margin:0px;}</style></head><body>"]];

    }
    
    
    [HTML appendString:[NSString stringWithFormat:@"<h3>%@</h3>", poem.title]];
    [HTML appendString:[NSString stringWithFormat:@"By %@", poem.author]];
   
    if ( poem.journalTitle.length > 0 )
        [HTML appendString:[NSString stringWithFormat:@"<br>from <i>%@</i> ", poem.journalTitle]];
    
    [HTML appendString:@"</body></html>"];
    
    
//    NSString *oldHTML = [self.poemInformationWebView stringByEvaluatingJavaScriptFromString:@"document.body.innerHTML"];
    
    if ( poem.journalTitle.length == 0 )
    {
        [self.poemInformationWebView loadHTMLString:HTML baseURL:nil];

        return;
    }
    
    NSLog( @"animated: %@", animated ? @"YES" : @"NO");
    
    if ( NO ) //[oldHTML rangeOfString:poem.journalTitle].location != NSNotFound )
    {
        [UIView animateWithDuration:animated ? 0.2f : 0.0f animations:^{
          
            self.poemInformationWebView.alpha  = 1.0f;
            self.poemInformationWebView.alpha  = 0.0f;

        } completion:^(BOOL finished) {
         
            [self.poemInformationWebView loadHTMLString:HTML baseURL:nil];

            [UIView animateWithDuration:0.3f animations:^{
                
                self.poemInformationWebView.alpha  = 0.0f;
                self.poemInformationWebView.alpha  = 1.0f;
                
            } completion:^(BOOL finished) {
                
            }];
        }];
    }
    else
    {
        [self.poemInformationWebView loadHTMLString:HTML baseURL:nil];
    }

    NSString *resize = [NSString stringWithFormat:@"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust = auto';"]; //  '%d%%';", 3000];
    [self.poemInformationWebView stringByEvaluatingJavaScriptFromString:resize];
}

- (IBAction)favoriteOrUnfavorite:(id)sender;
{
    if ( self.currentPoem.isFavorite.boolValue )
    {
        self.currentPoem.isFavorite = [NSNumber numberWithBool:NO];
        
        [SVProgressHUD show];
        [SVProgressHUD dismissWithError:NSLocalizedString( @"Unfavorited", @"" ) ];
        
        [self.favoriteBarButtonItem setTitle:@"☆"];

    }
    else
    {
        self.currentPoem.isFavorite = [NSNumber numberWithBool:YES];
        
        [SVProgressHUD showSuccessWithStatus:NSLocalizedString( @"Favorited", @"" )];

        [self.favoriteBarButtonItem setTitle:@"★"];
    }
}



#pragma mark - View Lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.title = NSLocalizedString(@"Home", @"");
        self.tabBarItem.image = [UIImage imageNamed:@"53-house"];
        
        NSDictionary *titleTextAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                       [UIFont boldSystemFontOfSize:10.0f], UITextAttributeFont,
                                                       [UIColor darkGrayColor], UITextAttributeTextColor,
                                                       nil];
        
        NSDictionary *titleTextHighlightedAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                  [UIFont boldSystemFontOfSize:10.0f], UITextAttributeFont,
                                                                  [UIColor whiteColor], UITextAttributeTextColor,
                                                                  nil];
        
        [self.tabBarItem setTitleTextAttributes:titleTextAttributesDictionary forState:UIControlStateNormal];
        [self.tabBarItem setTitleTextAttributes:titleTextHighlightedAttributesDictionary forState:UIControlStateSelected];
        
        self.sponsors = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupStrings];
    [self addPullToRefreshHeader];
    [self.refreshLabel setTextColor:[UIColor colorWithRed:90.0f/255.0 green:33.0f/255.0 blue:40.0f/255.0 alpha:1.0]];
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"paper_new"]];
    
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:.8819 green:.84212 blue:.7480 alpha:1.0];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Random" style:UIBarButtonItemStyleBordered target:self action:@selector(fetchRandomPoem:)];
    
    [self.navigationItem.leftBarButtonItem setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                              [UIColor colorWithRed:90.0f/255.0 green:33.0f/255.0 blue:40.0f/255.0 alpha:1.0], UITextAttributeTextColor,
                                              [UIColor whiteColor], UITextAttributeTextShadowColor,
                                              [NSValue valueWithUIOffset:UIOffsetMake(0, 1)], UITextAttributeTextShadowOffset,
                                              [UIFont boldSystemFontOfSize:13.0f], UITextAttributeFont,
                                              nil] forState:UIControlStateNormal];
    


    
    self.navigationItem.leftBarButtonItem.tintColor = [UIColor colorWithRed:1.0f green:.9921f blue:.9252f alpha:0.6f];
    


    
    
    
    
    self.favoriteBarButtonItem = [[UIBarButtonItem alloc] initWithImage:nil style:UIBarButtonItemStylePlain target:self action:@selector(favoriteOrUnfavorite:)];
    
    self.navigationItem.rightBarButtonItem = self.favoriteBarButtonItem;

    
    [self.navigationItem.rightBarButtonItem setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                    [UIColor colorWithRed:90.0f/255.0 green:33.0f/255.0 blue:40.0f/255.0 alpha:1.0], UITextAttributeTextColor,
                                                                    [UIColor clearColor], UITextAttributeTextShadowColor,
                                                                    [NSValue valueWithUIOffset:UIOffsetMake(0, 0)], UITextAttributeTextShadowOffset,
                                                                    [UIFont boldSystemFontOfSize:16.0f], UITextAttributeFont,
                                                                    nil] forState:UIControlStateNormal];
    self.navigationItem.rightBarButtonItem.tintColor = [UIColor colorWithRed:1.0f green:.9921f blue:.9252f alpha:0.6f];

    if ( self.currentPoem.isFavorite.boolValue )
        [self.favoriteBarButtonItem setTitle:@"★"];
    else
        [self.favoriteBarButtonItem setTitle:@"☆"];

    
    UIButton *logoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    logoButton.frame = CGRectZero;
    [logoButton setImage:[UIImage imageNamed:@"title"] forState:UIControlStateNormal];
    logoButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    logoButton.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    
    CGRect newFrame = logoButton.frame;
    newFrame.size.height = 39.0f;
    logoButton.frame = newFrame;
    
    [logoButton addTarget:self action:@selector(showToday:) forControlEvents:UIControlEventTouchUpInside];

    self.navigationItem.titleView = logoButton;
    
    
    self.poemAuthorImageView.image = [UIImage imageNamed:nil];
    self.poemAuthorImageView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.poemAuthorImageView.layer.shadowOffset = CGSizeMake( 0.0f, 1.0f );
    self.poemAuthorImageView.layer.shadowRadius = 2.0f;
    self.poemAuthorImageView.layer.shadowOpacity = 0.5f;
    self.poemPublishedDateLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    self.poemPublishedDateLabel.layer.shadowOffset = CGSizeMake( 0.0f, 1.0f );
    self.poemPublishedDateLabel.layer.shadowRadius = 2.0f;
    self.poemPublishedDateLabel.layer.shadowOpacity = 0.5f;
    
    self.readPoemButton.backgroundColor = [UIColor clearColor];
    
    self.readPoemButton.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.readPoemButton.layer.shadowOffset = CGSizeMake( 0.0f, 1.0f );
    self.readPoemButton.layer.shadowOpacity = 0.5;
    self.readPoemButton.layer.shadowRadius = 2.0f;
    self.readPoemButton.enabled = NO;
    
    if ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] &&
        ([UIScreen mainScreen].scale == 2.0)) {
        
        [self.readPoemButton setBackgroundImage:[[UIImage imageNamed:@"red-read"] resizableImageWithCapInsets:UIEdgeInsetsMake( 22.0f, 8.0f, 22.0f, 8.0f)] forState:UIControlStateNormal];
        
        [self.readPoemButton setBackgroundImage:[[UIImage imageNamed:@"dark-read"] resizableImageWithCapInsets:UIEdgeInsetsMake( 21.0f, 8.0f, 22.0f, 8.0f)] forState:UIControlStateSelected];
    
    } else {
        
        [self.readPoemButton setBackgroundImage:[[UIImage imageNamed:@"red-read"] resizableImageWithCapInsets:UIEdgeInsetsMake( 23.0f, 12.0f, 23.0f, 12.0f)] forState:UIControlStateNormal];
        
        [self.readPoemButton setBackgroundImage:[[UIImage imageNamed:@"dark-read"] resizableImageWithCapInsets:UIEdgeInsetsMake( 8.0f, 8.0f, 8.0f, 8.0f)] forState:UIControlStateSelected];
    }
    

    [self showPoemForDay:[NSDate charlottesvilleDate]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(fetchRandomPoem:) 
                                                 name:@"DeviceShaken"
                                               object:nil];
    
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeNextDay:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.poemPublishedDateLabel addGestureRecognizer:swipeLeft];
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipePreviousDay:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.poemPublishedDateLabel addGestureRecognizer:swipeRight];
        
    self.mainPoemTableViewCell.contentView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"paper_new"]];
    self.readPoemButtonTableViewCell.contentView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"paper_new"]];
    self.poetInformationTableViewCell.contentView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"paper_new"]];
    self.publicationInformationTableViewCell.contentView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"paper_new"]];

    self.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"paper_new"]];

    if ([self.navigationController.parentViewController respondsToSelector:@selector(revealGesture:)] && [self.navigationController.parentViewController respondsToSelector:@selector(revealToggle:)])
	{
		UIPanGestureRecognizer *navigationBarPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self.navigationController.parentViewController action:@selector(revealGesture:)];
		[self.navigationController.navigationBar addGestureRecognizer:navigationBarPanGestureRecognizer];
        
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"reveal-btn"] style:UIBarButtonItemStylePlain target:self.navigationController.parentViewController action:@selector(revealToggle:)];
    }

    if ( [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad )
    {
        self.carousel.type = iCarouselTypeLinear;
        self.carousel.vertical = YES;
        self.carousel.decelerationRate = 0.85;

        self.carousel.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"black-Linen"]];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Sponsor"];
        request.fetchLimit = 10;
        
        NSMutableDictionary *serverInfo = [[NSMutableDictionary alloc] initWithCapacity:10];
        [serverInfo setObject:[NSNumber numberWithInteger:PDServerCommandSponsors] forKey:PDServerCommandKey];
        
        NSArray *items = [[PDCachedDataController sharedDataController] fetchObjects:request serverInfo:serverInfo cacheUpdateBlock:^(NSArray *newResults, NSError *error) {
            
            if ( newResults && !error )
            {
                NSLog(@"%@", newResults);
                
                self.sponsors = [newResults mutableCopy];
                
                NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:NO];
                [self.sponsors sortUsingDescriptors:[NSArray arrayWithObjects:descriptor,nil]];
                
                [self.carousel reloadData];
                
                [SVProgressHUD dismiss];
            }
            else
            {
                [SVProgressHUD dismissWithError:@"Failed To Load"];
            }
            
        }];
        
        self.sponsors = [items mutableCopy];
        
        NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:NO];
        [self.sponsors sortUsingDescriptors:[NSArray arrayWithObjects:descriptor,nil]];
        
        if ( [self.sponsors count] == 0 )
            [SVProgressHUD showWithStatus:NSLocalizedString( @"Loading Sponsors...", @"" )];
        
        
        [self.carousel reloadData];
    }

}

- (void)viewWillAppear:(BOOL)animated;
{
    self.navigationController.navigationBarHidden = NO;
    
    [super viewWillAppear:animated];
}

- (void)viewDidUnload
{
    [self setPoemPublishedDateLabel:nil];
    [self setPoemTitleLabel:nil];
    [self setPoemAuthorLabel:nil];
    [self setPoemAuthorImageView:nil];
    [self setReadPoemButton:nil];
    [self setShowPreviousDayButton:nil];
    [self setShowNextDayButton:nil];
    [self setTodaysPoemLabel:nil];
    [self setPoemInformationWebView:nil];
    [self setIPadfeatureInformationWebView:nil];
    [self setIPadVisitPublicationPageButton:nil];    
    [self setPoetInfoWebView:nil];
    [self setPublicationInfoWebView:nil];
    [self setPoemAuthorImageActivityView:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DeviceShaken" object:nil];

    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (BOOL)shouldAutorotate;
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations;
{
    return UIInterfaceOrientationMaskAll;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
//    static NSString *CellIdentifier = @"Cell";
//    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    if ( indexPath.section == 0) return self.mainPoemTableViewCell;
    if ( indexPath.section == 1)
    {
        return self.poetInformationTableViewCell;
    }
    if ( indexPath.section == 2)
    {
        return self.publicationInformationTableViewCell;
    }
    return nil;
//    return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    if ( indexPath.section == 0)
    {
        return fmaxf( self.poemAuthorImageView.frame.size.height + 40.0f, 210.0f );
    }
    
    if ( indexPath.section == 1)
    {
        self.poetInfoWebView.scrollView.scrollEnabled = NO;    // Property available in iOS 5.0 and later
        CGRect frame = self.poetInfoWebView.frame;
        
//        frame.size.width = 300.0f;       // Your desired width here.
        frame.size.height = 1.0f;        // Set the height to a small one.
        
        self.poetInfoWebView.frame = frame;       // Set webView's Frame, forcing the Layout of its embedded scrollView with current Frame's constraints (Width set above).
        
        frame.size.height = self.poetInfoWebView.scrollView.contentSize.height;  // Get the corresponding height from the webView's embedded scrollView.
        
        self.poetInfoWebView.frame = frame;
        
        return fmaxf( frame.size.height + 24.0f, 30.0f );
    }
    if ( indexPath.section == 2)
    {
        self.publicationInfoWebView.scrollView.scrollEnabled = NO;    // Property available in iOS 5.0 and later
        CGRect frame = self.publicationInfoWebView.frame;
        
//        frame.size.width = 300;       // Your desired width here.
        frame.size.height = 1;        // Set the height to a small one.
        
        self.publicationInfoWebView.frame = frame;       // Set webView's Frame, forcing the Layout of its embedded scrollView with current Frame's constraints (Width set above).
        
        frame.size.height = self.publicationInfoWebView.scrollView.contentSize.height;  // Get the corresponding height from the webView's embedded scrollView.
        
        self.publicationInfoWebView.frame = frame;
        
        return frame.size.height + 60.0f;
    }

    return 0.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
{
    if ( section == 0 )
    {
        return 0.0f;
    }
    if ( section == 1 )
    {
        return 63.0f;
    }
    
    return 4.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;
{
//    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake( 0.0f, 0.0f, 320.0f, CGFloat height)]
    
    if ( section == 1 )
    {
        UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake( 0.0f, 0.0f, 320.0f, 63.0f )];

        containerView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"paper_new"]];

        [containerView addSubview:self.readPoemButton];
        
        self.readPoemNowContainerView = containerView;
        
        self.readPoemButton.frame = CGRectMake( 11.0f, 11.0f, 298.0f, 44.0f );
        return containerView;
    }
    else if ( section == 2)
    {
        UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake( 0.0f, 0.0f, 320.0f, 9.0f )];
        containerView.backgroundColor = [UIColor colorWithRed:90.0f/255.0 green:33.0f/255.0 blue:40.0f/255.0 alpha:1.0];
        return containerView;
    }
    
    
    return nil;
}

/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
 {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 }
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

- (void)setupStrings{
    self.textPull = @"Pull down to refresh today's poem...";
    self.textRelease = @"Release to refresh today' poem...";
    self.textLoading = [NSString stringWithFormat:@"Loading %@...",( [self.currentPoem.title length] > 0 ) ? self.currentPoem.title : @""];
}

- (void)addPullToRefreshHeader {
    self.refreshHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0 - REFRESH_HEADER_HEIGHT, 320, REFRESH_HEADER_HEIGHT)];
    self.refreshHeaderView.backgroundColor = [UIColor clearColor];
    
    self.refreshLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, REFRESH_HEADER_HEIGHT)];
    self.refreshLabel.backgroundColor = [UIColor clearColor];
    self.refreshLabel.font = [UIFont boldSystemFontOfSize:12.0];
    self.refreshLabel.textAlignment = NSTextAlignmentCenter;
    
    self.refreshArrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"03-arrow-south"]];
    self.refreshArrow.frame = CGRectMake(floorf((REFRESH_HEADER_HEIGHT - 27) / 2),
                                    (floorf(REFRESH_HEADER_HEIGHT - 44) / 2),
                                    27, 44);
    
    self.refreshArrow.contentMode = UIViewContentModeCenter;
    
//    self.refreshSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
//    self.refreshSpinner.frame = CGRectMake(floorf(floorf(REFRESH_HEADER_HEIGHT - 20) / 2), floorf((REFRESH_HEADER_HEIGHT - 20) / 2), 20, 20);
//    self.refreshSpinner.hidesWhenStopped = YES;
    
    self.refreshLogoActivityLabel = [[UILabel alloc] initWithFrame:CGRectMake(floorf(floorf(REFRESH_HEADER_HEIGHT - 20) / 2), floorf((REFRESH_HEADER_HEIGHT - 20) / 2), 20, 20)];
    self.refreshLogoActivityLabel.text = @"PD";
    self.refreshLogoActivityLabel.textAlignment = UITextAlignmentCenter;
    [self.refreshLogoActivityLabel setFont:[UIFont boldSystemFontOfSize:13.0f]];
    self.refreshLogoActivityLabel.backgroundColor = [UIColor clearColor];
    [self.refreshLogoActivityLabel setTextColor:[UIColor colorWithRed:90.0f/255.0 green:33.0f/255.0 blue:40.0f/255.0 alpha:1.0]];
    self.refreshLogoActivityLabel.alpha = 0.0f;
        
    [self.refreshHeaderView addSubview:self.refreshLabel];
    [self.refreshHeaderView addSubview:self.refreshArrow];
    [self.refreshHeaderView addSubview:self.refreshLogoActivityLabel];
    [self.tableView addSubview:self.refreshHeaderView];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (self.isLoading) return;
    self.isDragging = YES;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.isLoading) {
        // Update the content inset, good for section headers
        if (scrollView.contentOffset.y > 0)
            self.tableView.contentInset = UIEdgeInsetsZero;
        else if (scrollView.contentOffset.y >= -REFRESH_HEADER_HEIGHT)
            self.tableView.contentInset = UIEdgeInsetsMake(-scrollView.contentOffset.y, 0, 0, 0);
    } else if (self.isDragging && scrollView.contentOffset.y < 0) {
        // Update the arrow direction and label
        [UIView animateWithDuration:0.25 animations:^{
            if (scrollView.contentOffset.y < -REFRESH_HEADER_HEIGHT) {
                // User is scrolling above the header
                self.refreshLabel.text = self.textRelease;
                [self.refreshArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
            } else {
                // User is scrolling somewhere within the header
                self.refreshLabel.text = self.textPull;
                [self.refreshArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
            }
        }];
    }
    
    
    if ( scrollView.contentOffset.y > self.mainPoemTableViewCell.frame.size.height + self.readPoemButtonTableViewCell.frame.size.height )
    {
        self.readPoemNowContainerView.backgroundColor = [UIColor clearColor];
    }
    else
    {
        self.readPoemNowContainerView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"paper_new"]];
    }
    
    
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (self.isLoading) return;
   self.isDragging = NO;
    if (scrollView.contentOffset.y <= -REFRESH_HEADER_HEIGHT) {
        // Released above the header
        [self startLoading];
    }
}

- (void)startLoading {
    self.isLoading = YES;
    
    // Show the header
    [UIView animateWithDuration:0.3 animations:^{
        self.tableView.contentInset = UIEdgeInsetsMake(REFRESH_HEADER_HEIGHT, 0, 0, 0);
        self.refreshLabel.text = self.textLoading;
        self.refreshArrow.hidden = YES;
        [self.refreshSpinner startAnimating];
        
        CABasicAnimation* rotationAnimation;
        rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0 /* full rotation*/ * 30 * 2.0f ];
        rotationAnimation.duration = 2.0f * 30;
        rotationAnimation.cumulative = YES;
        rotationAnimation.repeatCount = 30;
        
        [self.refreshLogoActivityLabel.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
        
        
        [UIView animateWithDuration:1.6 animations:^{
            
            self.refreshLogoActivityLabel.alpha = 1.0f;
        }];
        
//        [UIView animateWithDuration:0.4f delay:0.0f options:UIViewAnimationCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionRepeat animations:^{
//            
//            [UIView setAnimationRepeatCount:10000];
//            
//            self.refreshLogoActivityLabel.transform = CGAffineTransformRotate(self.refreshLogoActivityLabel.transform, 2 * M_PI);
//            
//            
//        } completion:^(BOOL finished) {
//            
//        }];
    }];
    
    // Refresh action!
    [self refresh];
}

- (void)stopLoading;
{
    self.isLoading = NO;
    
    // Hide the header
    [UIView animateWithDuration:0.3 animations:^{
        self.tableView.contentInset = UIEdgeInsetsZero;
        [self.refreshArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
    }
                     completion:^(BOOL finished) {
                         [self performSelector:@selector(stopLoadingComplete)];
                     }];
}

- (void)stopLoadingComplete;
{
    self.refreshLabel.text = self.textPull;
    self.refreshArrow.hidden = NO;
    [self.refreshSpinner stopAnimating];
    
    [UIView animateWithDuration:0.8 animations:^{
       
        self.refreshLogoActivityLabel.alpha = 0.0f;
    }];
}

- (void)refresh;
{
    [self showPoemForDay:[NSDate charlottesvilleDate]];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView;
{
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}


#pragma mark - Rotation

- (void)viewWillLayoutSubviews;
{
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    
    if ( [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad )
    {
        if ( UIInterfaceOrientationIsPortrait(interfaceOrientation) )
        {
            [(UIButton *)[self.view viewWithTag:1000] setFrame:CGRectMake( 252.0f, 395.0f, 265.0f, 54.0f )];
            [(UIWebView *)[self.view viewWithTag:1001] setFrame:CGRectMake( 127.0f, 594.0f, 515.0f, 291.0f )];
            [(UILabel *)[self.view viewWithTag:1002] setFrame:CGRectMake( 270.0f, 570.0f, 229.0f, 28.0f )];
        }
        else
        {
            [(UIButton *)[self.view viewWithTag:1000] setFrame:CGRectMake( 108.0f, 410.0f, 257.0f, 54.0f )];
            [(UIWebView *)[self.view viewWithTag:1001] setFrame:CGRectMake( 550.0f, 182.0f, 248.0f, 375.0f )];
            [(UILabel *)[self.view viewWithTag:1002] setFrame:CGRectMake( 550.0f, 137.0f, 227.0f, 28.0f )];
        }
    }
}


#pragma mark - iCarousel methods

- (NSUInteger)numberOfItemsInCarousel:(iCarousel *)carousel
{
    NSLog(@"%i", [self.sponsors count]);
    
    return [self.sponsors count];
}

- (UIView *)carousel:(iCarousel *)carousel viewForItemAtIndex:(NSUInteger)index reusingView:(UIView *)view
{
    UILabel *name = nil;
    UIWebView *description = nil;
    UIImageView *logo = nil;
    UIButton *linkButton = nil;
    
    //create new view if no view is available for recycling
    if ( view == nil )
    {
        view = [[UIView alloc] initWithFrame:CGRectMake( 0.0f, 0.0f, 150.0f, 150.0f )];
        //        view.layer.borderColor = [[UIColor colorWithRed:90.0f/255.0 green:33.0f/255.0 blue:40.0f/255.0 alpha:1.0] CGColor];
        view.layer.borderColor = [[UIColor whiteColor] CGColor];
        
        view.layer.borderWidth = 4.0f;
        view.layer.cornerRadius = 2.0f;
        view.backgroundColor = [UIColor lightGrayColor];
        view.tag = 100;
        view.contentMode = UIViewContentModeCenter;
        
        logo = [[UIImageView alloc] initWithFrame:CGRectMake(28.0f, 48.0f, 92.0f, 92.0f)];
        [view addSubview:logo];
        logo.tag = 2;
        
        name = [[UILabel alloc] initWithFrame:CGRectMake(4.0f, 0.0f, 142.0f, 54.0f)];
        name.backgroundColor = [UIColor clearColor];
        name.textColor = [UIColor darkGrayColor];
        name.textAlignment = UITextAlignmentCenter;
        name.font = [UIFont boldSystemFontOfSize:12.0f];
        name.numberOfLines = 0;
        name.tag = 1;
        [view addSubview:name];
                
        linkButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [linkButton setTitle:@"More ⇗" forState:UIControlStateNormal];
        [linkButton setTitleColor:[UIColor colorWithRed:50.0f/255.0f green:79.0f/255.0f blue:133.0f/255.0f alpha:1.0f] forState:UIControlStateNormal];
        [linkButton setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
        [linkButton.titleLabel setFont:[UIFont boldSystemFontOfSize:13.0f]];
        linkButton.frame = CGRectMake( 39.0f, 132.0f, 72.0f, 44.0f);
        //        [linkButton setImage:[UIImage imageNamed:@"fullscreen_alt_16x16"] forState:UIControlStateNormal];
        [linkButton addTarget:self action:@selector(showSponsorLink:) forControlEvents:UIControlEventTouchUpInside];
//        [view addSubview:linkButton];
    }
    else
    {
        //get a reference to the label in the recycled view
        name = (UILabel *)[view viewWithTag:1];
        description = (UIWebView *)[view viewWithTag:3];
        logo = (UIImageView *)[view viewWithTag:2];
    }
    
    PDSponsor *sponsor = [self.sponsors objectAtIndex:index];
    
    if (index % 2 == 0 )
    {
        view.backgroundColor = [UIColor colorWithRed:1.0f green:.9921f blue:.9252f alpha:1.0f];
	}
    else
	{
        view.backgroundColor = [UIColor colorWithRed:.8819f green:.84212f blue:.7480f alpha:1.0f];
    }
    
    name.text = sponsor.name;
    [logo setImage:sponsor.image];
    
    NSMutableString *HTMLString = [[NSMutableString alloc] init];
    [HTMLString appendString:@""];
    
    NSString *loadedHTML = [description stringByEvaluatingJavaScriptFromString:@"document.body.innerHTML"];
    
    if ( [loadedHTML rangeOfString:sponsor.text].location == NSNotFound  )
    {
        [description loadHTMLString:sponsor.text baseURL:nil];
        
        NSString *newHtml = [NSString stringWithFormat:@"document.style.webkitTextSizeAdjust = 'auto'"];
        [description stringByEvaluatingJavaScriptFromString:newHtml];
        
    }
    
    return view;
}

- (CGFloat)carousel:(iCarousel *)carousel valueForOption:(iCarouselOption)option withDefault:(CGFloat)value
{
    if (option == iCarouselOptionSpacing)
    {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
            return value * 1.05f;
        else
            return value * 1.15f;
    }
    if (option == iCarouselOptionWrap)
    {
        return YES;
    }
    
    return value;
}


@end
