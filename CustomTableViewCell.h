//
//  CustomTableViewCell.h
//  XLAttributedLabel
//
//  Created by 先龙 廖 on 16/7/19.
//  Copyright © 2016年 先龙 廖. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XLRegexAttributedLabel.h"

@interface CustomTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet XLRegexAttributedLabel *attriubtedLabel;


@end
