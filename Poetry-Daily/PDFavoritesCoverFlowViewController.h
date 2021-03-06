//
//  PDFavoritesCoverFlowViewController.h
//  Poetry-Daily
//
//  Created by David Sklenar on 6/4/12.
//  Copyright (c) 2012 ELC Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iCarousel.h"
#import "PDConstants.h"

@interface PDFavoritesCoverFlowViewController : UIViewController <iCarouselDataSource, iCarouselDelegate>

@property(strong, nonatomic) IBOutlet iCarousel *carousel;
@property(strong, nonatomic) NSMutableArray *poems;


@end
