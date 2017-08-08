//
//  ViewController.m
//  QRCodeScanner
//
//  Created by xby on 2017/8/8.
//  Copyright © 2017年 xby. All rights reserved.
//

#import "ViewController.h"
#import "HMScannerController.h"

#define kScreenHeight [[UIScreen mainScreen] bounds].size.height
#define kScreenWidth [[UIScreen mainScreen] bounds].size.width

@interface ViewController ()

@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UILabel *scanResultLabel;
@end

@implementation ViewController

- (void)clickScanButton:(UIBarButtonItem *)sender {
    
    NSString *cardName = @"扶我起来，我还能再浪一波";
    UIImage *avatar = [UIImage imageNamed:@"avatar"];
    
    HMScannerController *scanner = [HMScannerController scannerWithCardName:cardName avatar:avatar completion:^(NSString *stringValue) {
        
        self.scanResultLabel.text = stringValue;
    }];
    
    [scanner setTitleColor:[UIColor whiteColor] tintColor:[UIColor greenColor]];
    
    [self showDetailViewController:scanner sender:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view addSubview:self.imageView];
    [self.view addSubview:self.scanResultLabel];
    
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"扫描" style:UIBarButtonItemStylePlain target:self action:@selector(clickScanButton:)];
    self.navigationItem.rightBarButtonItem = item;
    
    NSString *cardName = @"扶我起来，我还能再浪一波";
    UIImage *avatar = [UIImage imageNamed:@"avatar"];
    
    [HMScannerController cardImageWithCardName:cardName avatar:avatar scale:0.2 completion:^(UIImage *image) {
        self.imageView.image = image;
    }];
}

-(UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake((kScreenWidth-280)*0.5, (kScreenHeight-280)*0.5, 280, 280)];
    }
    
    return _imageView;
}

-(UILabel *)scanResultLabel {
    if (!_scanResultLabel) {
        _scanResultLabel = [[UILabel alloc] initWithFrame:CGRectMake((kScreenWidth-120)*0.5, (kScreenHeight+280)*0.5, 120, 30)];
        _scanResultLabel.text = @"扫描结果";
        _scanResultLabel.textAlignment = NSTextAlignmentCenter;
    }
    
    return _scanResultLabel;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
