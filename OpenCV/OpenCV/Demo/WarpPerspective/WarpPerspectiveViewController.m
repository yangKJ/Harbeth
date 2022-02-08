//
//  WarpPerspectiveViewController.m
//  MetalQueen
//
//  Created by Condy on 2021/3/20.
//  https://github.com/YangKJ/MetalQueen


#import "WarpPerspectiveViewController.h"

@implementation WarpPerspectiveViewController

#if __has_include(<opencv2/imgcodecs/ios.h>)

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _weakself;
    CGFloat w = weakself.topImageView.width;
    CGFloat h = weakself.topImageView.height;
    self.bottomSlider.value = 0.5;
    weakself.bottomImageView.image =
    [weakself.topImageView.image kj_opencvWarpPerspectiveWithKnownPoints:KJKnownPointsMake(kPoint(0, 0), kPoint(w-50, 30), kPoint(w, h-20), kPoint(20, h)) size:CGSizeMake(w, h)];
    self.kButtonAction = ^{
        weakself.bottomImageView.image =
        [weakself.topImageView.image kj_opencvWarpPerspectiveWithKnownPoints:KJKnownPointsMake(kPoint(0, 0), kPoint(w-50, 30), kPoint(w, h-20), kPoint(20, h)) size:CGSizeMake(w, h)];
    };
    self.kSliderMoving = ^(CGFloat value) {
        CGFloat x = 100 * value;
        weakself.bottomImageView.image =
        [weakself.topImageView.image kj_opencvWarpPerspectiveWithKnownPoints:KJKnownPointsMake(kPoint(x, x), kPoint(w-50, 30+x/2), kPoint(w, h-20), kPoint(20, h)) size:CGSizeMake(w, h)];
    };
    self.kSlider2Moving = ^(CGFloat value) {
        CGFloat x = 100 * value;
        weakself.bottomImageView.image =
        [weakself.topImageView.image kj_opencvWarpPerspectiveWithKnownPoints:KJKnownPointsMake(kPoint(x, x), kPoint(w-x, x), kPoint(w, h), kPoint(0, h)) size:CGSizeMake(w, h)];
    };
}

#endif

@end
