//
//  HoughViewController.m
//  MetalQueen
//
//  Created by Condy on 2021/3/21.
//

#import "HoughViewController.h"

@interface HoughViewController ()

@end

@implementation HoughViewController

#if __has_include(<opencv2/imgcodecs/ios.h>)

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.topImageView.image = [UIImage imageNamed:@"Hough"];
    _weakself;
    self.kButtonAction = ^{
        weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvHoughLinesCorrectTextImageFillColor:UIColorFromHEXA(0x292a30, 1)];
    };
    weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvHoughLinesCorrectTextImageFillColor:UIColorFromHEXA(0x292a30, 1)];
}

#endif

@end
