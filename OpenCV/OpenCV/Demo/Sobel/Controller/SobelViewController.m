//
//  SobelViewController.m
//  MetalQueen
//
//  Created by Condy on 2021/3/21.
//  https://github.com/YangKJ/MetalQueen

#import "SobelViewController.h"

@interface SobelViewController ()

@end

@implementation SobelViewController

#if __has_include(<opencv2/imgcodecs/ios.h>)

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.topImageView.image = [UIImage imageNamed:@"Sobel.jpeg"];
    _weakself;
    self.kButtonAction = ^{
        weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvFeatureExtractionFromSobel];
    };
    weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvFeatureExtractionFromSobel];
}

#endif

@end
