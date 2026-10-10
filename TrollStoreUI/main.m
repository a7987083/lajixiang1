#import <UIKit/UIKit.h>

@interface TSPreviewController : UIViewController <UITableViewDataSource,UITableViewDelegate,UISearchBarDelegate>
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) UISearchBar *searchBar;
@property(nonatomic,strong) NSArray<NSDictionary *> *entries;
@property(nonatomic,strong) NSArray<NSDictionary *> *visibleEntries;
@property(nonatomic,copy) NSString *pageName;
@end

@implementation TSPreviewController
- (instancetype)initWithPage:(NSString *)page {
    if ((self=[super init])) { _pageName=[page copy]; self.title=page; }
    return self;
}
- (NSDictionary *)entry:(NSString *)title detail:(NSString *)detail icon:(NSString *)icon {
    return @{@"title":title,@"detail":detail,@"icon":icon};
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=[UIColor systemGroupedBackgroundColor];
    if ([_pageName isEqualToString:@"Apps"]) {
        self.entries=@[
            [self entry:@"Installed Applications" detail:@"App Store · TrollStore" icon:@"square.stack.3d.up"],
            [self entry:@"Import IPA" detail:@"Open an IPA from Files" icon:@"square.and.arrow.down"],
            [self entry:@"App Management" detail:@"App details and installation source" icon:@"app.badge"]];
        self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTapped)];
        self.searchBar=[UISearchBar new]; self.searchBar.placeholder=@"Search Applications"; self.searchBar.delegate=self;
    } else if ([_pageName isEqualToString:@"Packages"]) {
        self.entries=@[
            [self entry:@"IPA Packages" detail:@"Local IPA packages" icon:@"shippingbox"],
            [self entry:@"Repositories" detail:@"Sources and package feeds" icon:@"tray.full"],
            [self entry:@"Downloads" detail:@"Download history" icon:@"arrow.down.circle"]];
    } else if ([_pageName isEqualToString:@"Plugins"]) {
        self.entries=@[
            [self entry:@"Installed Plugins" detail:@"Plugin management" icon:@"puzzlepiece.extension"],
            [self entry:@"Files" detail:@"Browse local documents" icon:@"folder"],
            [self entry:@"Code Signing" detail:@"Signing tools" icon:@"signature"],
            [self entry:@"Decrypt" detail:@"App decryption tools" icon:@"lock.open"],
            [self entry:@"IPA Repackage" detail:@"Package utilities" icon:@"archivebox"]];
    } else {
        self.entries=@[
            [self entry:@"Appearance" detail:@"Theme and backgrounds" icon:@"paintbrush"],
            [self entry:@"Tab Bar Style" detail:@"Standard · Floating · Notched" icon:@"rectangle.bottomthird.inset.filled"],
            [self entry:@"Persistence Helper" detail:@"System integration" icon:@"checkmark.shield"],
            [self entry:@"Rebuild Icon Cache" detail:@"Refresh SpringBoard icons" icon:@"arrow.clockwise"],
            [self entry:@"About" detail:@"TrollStore-style UI preview" icon:@"info.circle"]];
    }
    self.visibleEntries=self.entries;
    self.table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.translatesAutoresizingMaskIntoConstraints=NO;
    self.table.backgroundColor=[UIColor systemGroupedBackgroundColor];
    self.table.rowHeight=78;
    self.table.dataSource=self; self.table.delegate=self;
    [self.view addSubview:self.table];
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]]];
    if (self.searchBar) self.table.tableHeaderView=self.searchBar;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.visibleEntries.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier=@"AppRow";
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    NSDictionary *item=self.visibleEntries[indexPath.row];
    cell.textLabel.text=item[@"title"]; cell.textLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text=item[@"detail"];
    cell.detailTextLabel.textColor=[UIColor secondaryLabelColor];
    cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    if (@available(iOS 13.0,*)) {
        cell.imageView.image=[UIImage systemImageNamed:item[@"icon"]];
        cell.imageView.tintColor=[UIColor systemBlueColor];
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *name=self.visibleEntries[indexPath.row][@"title"];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:name message:@"UI preview only. This action is not connected to TrollStore system services." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
    if (!text.length) self.visibleEntries=self.entries;
    else self.visibleEntries=[self.entries filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        return [item[@"title"] localizedCaseInsensitiveContainsString:text] || [item[@"detail"] localizedCaseInsensitiveContainsString:text];
    }]];
    [self.table reloadData];
}
- (void)addTapped {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Import IPA" message:@"UI preview only; importer not yet integrated." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    UITabBarController *tabs=[UITabBarController new];
    NSArray *pages=@[@"Apps",@"Packages",@"Plugins",@"Settings"];
    NSArray *icons=@[@"square.grid.2x2",@"shippingbox",@"puzzlepiece.extension",@"gearshape"];
    NSMutableArray *items=[NSMutableArray array];
    for (NSUInteger i=0;i<pages.count;i++) {
        TSPreviewController *controller=[[TSPreviewController alloc] initWithPage:pages[i]];
        UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:controller];
        nav.navigationBar.prefersLargeTitles=YES;
        controller.navigationItem.largeTitleDisplayMode=UINavigationItemLargeTitleDisplayModeAlways;
        nav.tabBarItem=[[UITabBarItem alloc] initWithTitle:pages[i] image:[UIImage systemImageNamed:icons[i]] tag:i];
        [items addObject:nav];
    }
    tabs.viewControllers=items;
    tabs.tabBar.tintColor=[UIColor systemBlueColor];
    self.window=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController=tabs;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc,char **argv) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass([AppDelegate class])); } }
