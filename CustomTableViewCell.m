//
//  CustomTableViewCell.m
//  XLAttributedLabel
//
//  Created by 先龙 廖 on 16/7/19.
//  Copyright © 2016年 先龙 廖. All rights reserved.
//

#import "CustomTableViewCell.h"

@interface CustomTableViewCell () <XLRegexAttributedLabelDelegate>

@end

@implementation CustomTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.attriubtedLabel.numberOfLines = 0;
    self.attriubtedLabel.textAlignment = NSTextAlignmentLeft;
    self.attriubtedLabel.delegate = self;
//    [self.attriubtedLabel addRegex:@"0" withFont:[UIFont boldSystemFontOfSize:20] withColor:[UIColor redColor]];
    [self.attriubtedLabel addRegex:@"\\[#&\\d{0,3}\\]+" withEmojiPlist:@"expression.plist"];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)attributedLable:(XLRegexAttributedLabel *)attributedLabel didSelectedLink:(NSString *)link {
    NSLog(@"link---> %@", link);
}


- (void)attributedLabel:(TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url {
    
}

- (void)attributedLabel:(TTTAttributedLabel *)label
didLongPressLinkWithURL:(NSURL *)url
                atPoint:(CGPoint)point
{
    NSLog(@"aaa");
}
@end
