//
//  ATViewController.m
//  OpenCV
//
//  Created by Condy on 2021/2/8.
//

#import "ATViewController.h"
#import "UIView+KJFrame.h"

@interface ATViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UILabel *tipLabel;
@property (nonatomic, strong) NSArray *temps;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation ATViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupUI];
}

- (void)setupUI{
    self.title = @"OpenCV Case";
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * (UITraitCollection * train) {
            if ([train userInterfaceStyle] == UIUserInterfaceStyleLight) {
                return UIColor.whiteColor;
            } else {
                return UIColor.blackColor;
            }
        }];
    } else {
        self.view.backgroundColor = UIColor.whiteColor;
    }
    [self.view addSubview:self.tipLabel];
    [self.view addSubview:self.tableView];
}

#pragma mark - UITableViewDataSource, UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger )tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [self.temps count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    NSDictionary *dic = self.temps[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%ld. %@",indexPath.row + 1, dic[@"class"]];
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.detailTextLabel.text = dic[@"describeName"];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSDictionary *dic = self.temps[indexPath.row];
    UIViewController *vc = [NSClassFromString(dic[@"class"]) new];
    vc.title = dic[@"describeName"];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - lazy

- (UILabel *)tipLabel {
    if (!_tipLabel) {
        _tipLabel = [UILabel new];
        _tipLabel.frame = CGRectMake(20, kSTATUSBAR_NAVIGATION_HEIGHT, self.view.frame.size.width-40, 40);
        _tipLabel.numberOfLines = 0;
        _tipLabel.textColor = [UIColor redColor];
        _tipLabel.font = [UIFont systemFontOfSize:14];
        _tipLabel.textAlignment = NSTextAlignmentCenter;
        _tipLabel.text = @"Remarks: This module needs to import the OpenCV, please execute the `pod install` operation first";
    }
    return _tipLabel;
}

- (UITableView *)tableView {
    if (!_tableView) {
        CGFloat y = CGRectGetMaxY(self.tipLabel.frame);
        CGRect rect = CGRectMake(0, self.tipLabel.bottom, self.view.width, self.view.height-y);
        _tableView = [[UITableView alloc]initWithFrame:rect style:(UITableViewStylePlain)];
        _tableView.rowHeight = 50;
        _tableView.sectionHeaderHeight = 0.0001f;
        _tableView.dataSource = self;
        _tableView.delegate = self;
        [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
    }
    return _tableView;
}

- (NSArray *)temps {
    if (!_temps) {
        _temps = @[
            @{@"class": @"HoughViewController", @"describeName": @"Hough line detection and correction text"},
            @{@"class": @"SobelViewController", @"describeName": @"Feature Extraction Processing"},
            @{@"class": @"RepairViewController", @"describeName": @"Old photo repair"},
            @{@"class": @"InpaintViewController", @"describeName": @"Repair the picture to remove the watermark"},
            @{@"class": @"MaxCutViewController", @"describeName": @"Maximum Area Cut"},
            @{@"class": @"MorphologyViewController", @"describeName": @"Morphology Operation"},
            @{@"class": @"BlurViewController", @"describeName": @"Blurred skin whitening treatment"},
            @{@"class": @"WarpPerspectiveViewController", @"describeName": @"Picture Perspective"},
            @{@"class": @"ImageBlendViewController", @"describeName": @"Picture Blend"},
            @{@"class": @"LuminanceViewController", @"describeName": @"Modify brightness and contrast"},
            @{@"class": @"TiledViewController", @"describeName": @"Picture mosaic tile"},
        ];
    }
    return _temps;
}

@end
