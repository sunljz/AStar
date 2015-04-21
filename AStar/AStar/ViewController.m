//
//  ViewController.m
//  AStar
//
//  Created by 李剑钊 on 15/4/14.
//  Copyright (c) 2015年 sunli. All rights reserved.
//

#import "ViewController.h"
#import "MapView.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor whiteColor];
    
    MapView *view = [[MapView alloc] initWithFrame:self.view.bounds];
    view.backgroundColor = [UIColor clearColor];
    [self.view addSubview:view];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
