//
//  ImageBlendViewController.m
//  MetalQueen
//
//  Created by Condy on 2021/3/20.
//  https://github.com/YangKJ/MetalQueen


#import "ImageBlendViewController.h"

@interface ImageBlendViewController ()

@end

@implementation ImageBlendViewController

#if __has_include(<opencv2/imgcodecs/ios.h>)

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    UIImage *image = [UIImage imageNamed:@"ImageBlend"];
    if (!CGSizeEqualToSize(self.topImageView.image.size, image.size)) {
        image = [image kj_BitmapChangeImageSize:self.topImageView.image.size];
    }
    self.topSlider.value = 0.5;
    _weakself;
    weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvBlendImage:image alpha:0.5];
    self.kButtonAction = ^{
        weakself.bottomImageView.image = [weakself.topImageView.image kj_opencvBlendImage:image alpha:0.5];
    };
    self.kSliderMoving = ^(CGFloat value) {
        __block UIImage *img = weakself.topImageView.image;
        kGCD_async(^{
            CGFloat x = 1 * value;
            img = [img kj_opencvBlendImage:image alpha:x];
            kGCD_main(^{
                weakself.bottomImageView.image = img;                
            });
        });
    };
}

#endif

@end
