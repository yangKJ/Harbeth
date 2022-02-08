//
//  ChangeColorViewController.m
//  MetalQueen
//
//  Created by Condy on 2021/3/20.
//  https://github.com/YangKJ/MetalQueen

#import "ChangeColorViewController.h"

@interface ChangeColorViewController ()

@end

@implementation ChangeColorViewController

#if __has_include(<opencv2/imgcodecs/ios.h>)

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _weakself;
    weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvChangeR:-1 g:-1 b:-1];
    self.kButtonAction = ^{
        weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvChangeR:-1 g:-1 b:-1];
    };
    self.kSliderMoveEnd = ^(CGFloat value) {
        CGFloat x = 255 * value;
        CGFloat y = 255 * weakself.bottomSlider.value;
        weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvChangeR:x g:y b:-1];
    };
    self.kSlider2MoveEnd = ^(CGFloat value) {
        CGFloat x = 255 * weakself.topSlider.value;
        CGFloat y = 255 * value;
        weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvChangeR:y g:-1 b:x];
    };
}

#endif

@end
