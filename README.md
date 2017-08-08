# QRCodeScanner

包含 UI 界面的轻量级二维码扫描及生成框架

## 功能

* 提供一个导航控制器，扫描 `二维码 / 条形码`
* 能够生成指定 `字符串` + `avatar(可选)` 的二维码名片
* 能够识别相册图片中的二维码(iOS 64 位设备)

## 系统支持

* iOS 8.0+
* Xcode 7.0

## 使用

* 在 `Info.plist` 中添加两个 `值对` 以授权访问 `相机` 和 `相册`

* `NSCameraUsageDescription`
* `NSPhotoLibraryUsageDescription`


### Objective-C

* 导入框架

```objc
@import HMQRCodeScanner;
```

* 打开扫描控制器，扫描及完成回调

```objc
NSString *cardName = @"扶我起来，我还能再浪一波";
UIImage *avatar = [UIImage imageNamed:@"avatar"];

// 实例化扫描控制器
HMScannerController *scanner = [HMScannerController scannerWithCardName:cardName avatar:avatar completion:^(NSString *stringValue) {

self.scanResultLabel.text = stringValue;
}];

// 设置导航栏样式
[scanner setTitleColor:[UIColor whiteColor] tintColor:[UIColor greenColor]];

// 展现扫描控制器
[self showDetailViewController:scanner sender:nil];
```

* 生成二维码名片

```objc
NSString *cardName = @"扶我起来，我还能再浪一波";
UIImage *avatar = [UIImage imageNamed:@"avatar"];

[HMScannerController cardImageWithCardName:cardName avatar:avatar scale:0.2 completion:^(UIImage *image) {
self.imageView.image = image;
}];
```

### Swift

* 导入框架

```swift
import HMQRCodeScanner
```

* 打开扫描控制器，扫描及完成回调

```swift
let cardName = "扶我起来，我还能再浪一波"
let avatar = UIImage(named: "avatar")

let scanner = HMScannerController.scannerWithCardName(cardName, avatar: avatar) { (stringValue) -> Void in
self.scanResultLabel.text = stringValue
}

self.showDetailViewController(scanner, sender: nil)
```

* 生成二维码名片

```swift
let cardName = "扶我起来，我还能再浪一波"
let avatar = UIImage(named: "avatar")

HMScannerController.cardImageWithCardName(cardName, avatar: avatar, scale: 0.2) { (image) -> Void in
self.imageView.image = image
}
```

