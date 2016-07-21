//
//  ViewController.m
//  XLAttributedLabel
//
//  Created by 先龙 廖 on 16/7/14.
//  Copyright © 2016年 先龙 廖. All rights reserved.
//

#import "ViewController.h"
#import "XLRegexAttributedLabel.h"
#import "CustomTableViewCell.h"

#define kDemoText @"😄哈💋[#&3][#&3][#&3][#&11]<a class=\"default-tag-link\" href=\"http://app.icaikee.com/portfolio/732?name=SF塔式模式\">SF塔式模式</a> 东方市场(<a class=\"default-tag-link\" href=\"http://app.icaikee.com/stock/SZ000301?name=东方市场\">000301</a>) [#&14]DSADASDASDASDASDASDASDDASDASDASDASDASDASDASDDADSDSADSADASDAS《<a class=\"default-tag-link\" href=\"http://app.icaikee.com/article/724111?name=Dick复盘笔记0624：市场风格向主板倾斜\">Dick复盘笔记0624：市场风格向主板倾斜</a>》"

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerNib:[UINib nibWithNibName:@"CustomTableViewCell" bundle:nil]
         forCellReuseIdentifier:@"CustomTableViewCell"];
    // Do any additional setup after loading the view, typically from a nib.
    
//    XLRegexAttributedLabel *label = [[XLRegexAttributedLabel alloc] initWithFrame:CGRectMake(30, 50, 300, 300)];
//    label.numberOfLines = 0;
//    label.textAlignment = NSTextAlignmentLeft;
//    [self.view addSubview:label];
//    label.backgroundColor = [UIColor lightGrayColor];
//    [label addRegex:@"0" withFont:[UIFont boldSystemFontOfSize:20] withColor:[UIColor redColor]];
//    [label addRegex:@"\\[#&\\d{0,3}\\]+" withEmojiPlist:@"expression.plist"];
//    label.text = @"100 200 300 444 打 [#&12][#&13][#&13][#&13][#&13][#&13][#&13][#&13][#&13][#&13][#&13][#&13][#&13][#&13][#&13][#&13][#&13] dsd是大大说打的熬到打的撒旦大大大爱大飒飒打赏代码是看了都没事可拉倒看来是打开了萨克多岁的垃圾坑拉萨的接口拉萨的快乐撒打开时金坷垃圣诞节快拉上打开了";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDelegate, UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 100;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 120;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CustomTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CustomTableViewCell"
                                                                forIndexPath:indexPath];
    cell.attriubtedLabel.text = kDemoText;
    return cell;
}

@end
