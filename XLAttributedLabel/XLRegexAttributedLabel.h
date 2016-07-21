//
//  XLRegexAttributedLabel.h
//  XLAttributedLabel
//
//  Created by 先龙 廖 on 16/7/14.
//  Copyright © 2016年 先龙 廖. All rights reserved.
//

#import "TTTAttributedLabel.h"

@class XLRegexAttributedLabel;
@protocol XLRegexAttributedLabelDelegate <TTTAttributedLabelDelegate>

@optional
- (void)attributedLable:(XLRegexAttributedLabel *)attributedLabel didSelectedLink:(NSString *)link;

@end

@interface XLRegexAttributedLabel : TTTAttributedLabel

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-property-synthesis"
@property (nonatomic, weak) id<XLRegexAttributedLabelDelegate> delegate;
#pragma clang diagnostic pop

/**
 *  常规富文本正则
 *
 *  @param regex 正则表达式
 *  @param font  字体
 *  @param color 文字颜色
 */
- (void)addRegex:(NSString *)regex withFont:(UIFont *)font;
- (void)addRegex:(NSString *)regex withFont:(UIFont *)font withColor:(UIColor *)color;

/**
 *  添加表情正则表达式
 *
 *  @param regex     正则表达式
 *  @param plistName 表情文件名称列表 Format: XXXX.plist
 */

- (void)addRegex:(NSString *)regex withEmojiPlist:(NSString *)plistName;

/**
 *  自定义表情bundle名称，支持多套不同格式的表情，但是目前表情图片路径只支持一个，所以请把所有表情图片放进同一个xxxxx.bundle中
 */
@property (nonatomic, strong) NSString *emojiBundleName;

/**
 *  是否支持匹配HTML超链接，默认为YES
 *  @样例格式：<a class=\"default-tag-link\" href=\"http://app.icaikee.com/portfolio/732?name=SF塔式模式\">SF塔式模式</a>
 */
@property (nonatomic, assign) BOOL isMatchHtmlLink;

/**
 *  添加点击链接的正则表达式
 *
 *  @param regex       正则表达式
 *  @param attributeds 富文本属性
 */
//- (void)addLinkWithRegex:(NSString *)regex;
//- (void)addLinkWithRegex:(NSString *)regex withFont:(UIFont *)font;
//- (void)addLinkWithRegex:(NSString *)regex withFont:(UIFont *)font withColor:(UIColor *)color;

/**
 *  通过最大width来计算当前Label的高度
 *
 *  @param maxWidth 最大宽度
 *
 *  @return CGSize
 */
- (CGSize)preferredSizeWithMaxWidth:(CGFloat)maxWidth;

@end
