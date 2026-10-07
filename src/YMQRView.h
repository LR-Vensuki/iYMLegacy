/**
 * File              : YMQRView.h
 * QR code drawn with Core Graphics (iOS 6 has no CIQRCodeGenerator).
 */

#import <UIKit/UIKit.h>

@interface YMQRView : UIView
@property (copy, nonatomic) NSString *text;
@property (strong, nonatomic) UIColor *moduleColor;
@end

// vim:ft=objc
