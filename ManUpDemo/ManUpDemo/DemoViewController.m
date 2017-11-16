//
//  DemoViewController.m
//  ManUpDemo
//
//  Created by Jeremy Day on 1/11/12.
//  Copyright (c) 2012 Burleigh Labs. All rights reserved.
//

#import "DemoViewController.h"
#import "ManUp.h"

@interface DemoViewController () <UITableViewDataSource, UITableViewDelegate, ManUpDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *testItems;

@property (nonatomic, strong) ManUp *manUp;
@property (nonatomic, strong) NSString *lastUsedFilename;

@end

@implementation DemoViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    NSError *error;
    NSArray *resources = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[NSBundle mainBundle] resourcePath] error:&error];
    NSMutableArray *testItems = [NSMutableArray array];
    for (NSString *fileName in resources) {
        if ([fileName hasSuffix:@".json"]) {
            [testItems addObject:fileName];
        }
    }
    
    self.testItems = testItems;
    
    self.manUp = [[ManUp alloc] init];
    self.manUp.delegate = self;
    self.manUp.enableConsoleLogging = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"ManUp Demo";

    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.opaque = YES;
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:238.0/255.0 green:65.0/255.0 blue:54.0/255.0 alpha:1.0];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    
    self.tableView = [[UITableView alloc] init];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    self.tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:self.tableView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.tableView.frame = self.view.bounds;
}

#pragma mark - Public

- (void)applicationDidBecomeActive {
    if (self.lastUsedFilename != nil) {
        [self runManUpWithFileName:self.lastUsedFilename];
    }
}

#pragma mark - Private

- (void)runManUpWithFileName:(NSString *)fileName {
    self.lastUsedFilename = fileName;
    
    NSString *serverPath = [@"https://github.com/NextFaze/ManUp/raw/develop/ManUpDemo/TestFiles/" stringByAppendingString:fileName];
    
    if ([fileName isEqualToString:@"TestCustomConfigKeys.json"]) {
        // Don't like the json keys used by ManUp? Specify your own with a custom mapping dictionary
        self.manUp.customConfigKeyMapping = @{
                                              kManUpConfigAppVersionCurrent: @"app_store_version_current",
                                              kManUpConfigAppVersionMin: @"minimum_allowed_version",
                                              kManUpConfigAppUpdateURL: @"app_update_url"
                                              };
        
    } else {
        self.manUp.customConfigKeyMapping = nil;
    }
    
    self.manUp.serverConfigURL = [NSURL URLWithString:serverPath];
    [self.manUp validate];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.testItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    cell.textLabel.text = self.testItems[indexPath.row];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *fileName = self.testItems[indexPath.item];
    [self runManUpWithFileName:fileName];
}

#pragma mark - ManUpDelegate

- (void)manUpConfigUpdateStarting {
    NSLog(@"manUpConfigUpdateStarting");
}

- (void)manUpConfigUpdateFailed:(NSError *)error {
    NSLog(@"manUpConfigUpdateFailed: %@", error);
}

- (void)manUpConfigUpdated:(NSDictionary *)newSettings {
    NSLog(@"manUpConfigUpdated: %@", newSettings);
}

@end
