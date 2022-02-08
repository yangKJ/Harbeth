//
//  RepairViewController.m
//  MetalQueen
//
//  Created by Condy on 2021/3/20.
//  https://github.com/YangKJ/MetalQueen


#import "RepairViewController.h"

@interface RepairViewController ()

@end

@implementation RepairViewController

#if __has_include(<opencv2/imgcodecs/ios.h>)

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    __block UIImage *oldImage = self.topImageView.image = [UIImage imageNamed:@"Repair.jpg"];
    _weakself;
    kGCD_async(^{
        UIImage *image = [oldImage kj_opencvRepairImage];
        kGCD_main(^{
            weakself.bottomImageView.image = image;
        });
    });
    self.kButtonAction = ^{
        weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvRepairImage];
    };
}

#endif

@end
