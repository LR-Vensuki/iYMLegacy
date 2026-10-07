/**
 * File              : YMQRView.m
 * QR code drawn with Core Graphics (iOS 6 has no CIQRCodeGenerator).
 */

#import "YMQRView.h"
#import "YMDraw.h"
#include "../qrcodegen/qrcodegen.h"

@implementation YMQRView {
	uint8_t _qr[qrcodegen_BUFFER_LEN_FOR_VERSION(10)];
	BOOL _valid;
}

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		self.opaque = NO;
		self.contentMode = UIViewContentModeRedraw;
		self.moduleColor = YMRGB(20, 20, 20);
	}
	return self;
}

- (void)setText:(NSString *)text
{
	_text = [text copy];
	_valid = NO;
	if (text.length) {
		uint8_t temp[qrcodegen_BUFFER_LEN_FOR_VERSION(10)];
		_valid = qrcodegen_encodeText([text UTF8String], temp, _qr, qrcodegen_Ecc_MEDIUM,
				1, 10, qrcodegen_Mask_AUTO, true);
	}
	[self setNeedsDisplay];
}

- (void)setModuleColor:(UIColor *)moduleColor
{
	_moduleColor = moduleColor;
	[self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGRect plate = CGRectInset(self.bounds, 2, 2);
	UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:plate cornerRadius:10];
	CGContextSaveGState(ctx);
	CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 2, YMRGBA(0, 0, 0, 0.35).CGColor);
	[[UIColor whiteColor] setFill];
	[p fill];
	CGContextRestoreGState(ctx);

	if (!_valid)
		return;

	int size = qrcodegen_getSize(_qr);
	int quiet = 2;
	CGFloat side = MIN(plate.size.width, plate.size.height) - 12;
	CGFloat cell = floor(side / (size + quiet * 2) * 2) / 2;
	CGFloat total = cell * (size + quiet * 2);
	CGFloat ox = floor(CGRectGetMidX(plate) - total / 2 + cell * quiet);
	CGFloat oy = floor(CGRectGetMidY(plate) - total / 2 + cell * quiet);

	[self.moduleColor setFill];
	for (int y = 0; y < size; ++y)
		for (int x = 0; x < size; ++x)
			if (qrcodegen_getModule(_qr, x, y))
				CGContextFillRect(ctx, CGRectMake(ox + x * cell, oy + y * cell, cell + 0.1, cell + 0.1));
}

@end

// vim:ft=objc
