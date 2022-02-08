//
//  LuminanceViewController.m
//  MetalQueen
//
//  Created by Condy on 2021/3/20.
//  https://github.com/YangKJ/MetalQueen


#import "LuminanceViewController.h"

@interface LuminanceViewController ()

@end

@implementation LuminanceViewController

#if __has_include(<opencv2/imgcodecs/ios.h>)

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
//    self.orignalImageView.image = [UIImage imageNamed:@"banana"];
    self.topSlider.value = 0;
    self.bottomSlider.value = 0.5;
    _weakself;
    weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvChangeContrast:0 luminance:1];
    self.kButtonAction = ^{
        weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvChangeContrast:0 luminance:1];
    };
    self.kSliderMoveEnd = ^(CGFloat value) {
        CGFloat x = 100 * value;
        CGFloat y = 2 * weakself.bottomSlider.value;
        weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvChangeContrast:x luminance:y];
    };
    self.kSlider2MoveEnd = ^(CGFloat value) {
        CGFloat x = 100 * weakself.topSlider.value;
        CGFloat y = 2 * value;
        weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvChangeContrast:x luminance:y];
    };
}

#endif

@end
