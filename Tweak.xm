#import "Libra.h"

CGRect bottomDismiss;
CGRect topDimiss;

long long getCurrentPage() {
    SBRootFolderController *sbr = [[%c(SBIconController) sharedInstance] _rootFolderController];
    return [sbr currentPageIndex];
}

long long getMaxPage() {
    SBRootFolderController *sbr = [[%c(SBIconController) sharedInstance] _rootFolderController];
    return [sbr maximumPageIndex];
}

void showAlert(NSString *title, NSString *message) {
    UIAlertController * alert = [UIAlertController
                                    alertControllerWithTitle:title
                                    message:message
                                    preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* ok = [UIAlertAction
            actionWithTitle:@"Ok"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction * action) {
        return;
    }];		
    UIAlertAction* cancel = [UIAlertAction
            actionWithTitle:@"Cancel"
            style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction * action) {
        return;
    }];	
    [alert addAction:ok];
    [alert addAction:cancel];
    [[%c(SBIconController) sharedInstance] presentViewController:alert animated:YES completion:nil]; 
}

int mod (int a, int b) {
   if (b < 0) //you can check for b == 0 separately and do what you want
    return -mod(-a, -b);   
   int ret = a % b;
   if(ret < 0)
     ret+=b;
   return ret;
}

NSInteger genreTypesCount() {
    NSInteger genreTypes = [[%c(SBIconController) sharedInstance] genres].count;
    if (genreTypes == 1 || genreTypes == 2) {
        return 1;
    }
    if (genreTypes >= 3) {
        return mod(genreTypes, 2);
    }
	return genreTypes / 2;
}

%hook SBIconController
%property (strong, nonatomic) UIWindow *appWindow;
%property (strong, nonatomic) UIWindow *stackWindow;
%property (strong, nonatomic) NSMutableArray *genres;
%property (strong, nonatomic) NSMutableDictionary *genreKeys;
%property (strong, nonatomic) UITableView *libraTableView;
%property (strong, nonatomic) UILabel *genreLabelOne;
%property (strong, nonatomic) UICollectionView *libraView;

- (void)viewDidLoad {
    %orig;
    if (self.appWindow != nil) {
        [self removeView];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    [self removeView];
}

- (void)viewDidDisappear {
    %orig;
    [self removeView];
}

%new

- (UIImage *)iconImageForIdentifier:(NSString *)identifier {
	SBIconController *iconController = [NSClassFromString(@"SBIconController") sharedInstance];
	SBIcon *icon = [iconController.model expectedIconForDisplayIdentifier:identifier];
	struct CGSize imageSize;
	imageSize.height = 60;
	imageSize.width = 60;
	struct SBIconImageInfo imageInfo;
	imageInfo.size = imageSize;
	imageInfo.scale = [UIScreen mainScreen].scale;
	imageInfo.continuousCornerRadius = 12;
	return [icon generateIconImageWithInfo:imageInfo];
}

%new 
- (NSArray *)getAppsForGenreName:(NSString *)name {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:name inDomain:domainString]) {
        NSMutableArray *returnItems = [[NSMutableArray alloc] init];
        NSDictionary *apps = [[ALApplicationList sharedApplicationList] applications];
        for (NSString *key in [apps allKeys]) {
            if (key != nil) {
                LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:[NSString stringWithFormat:@"%@", key]];
                NSString *genre = [proxy genre];
                if (genre != NULL) {
                    if ([genre isEqualToString:name]) {
                        [returnItems addObject:key];
                    }
                }
            }
        }
        NSLog(@"LIBRA DEBUG: Genre -> %@: %@", name, returnItems);
        [[NSUserDefaults standardUserDefaults] setObject:[returnItems copy] forKey:name inDomain:domainString];
        return returnItems;
    }
    return [[NSUserDefaults standardUserDefaults] objectForKey:name inDomain:domainString];
}

%new

- (void)setupView {

    [self getGenres:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.appWindow) {
                self.appWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                self.appWindow.backgroundColor = [UIColor clearColor];
                self.appWindow.windowLevel = UIWindowLevelNormal;// UIWindowLevelAlert;
                
                UISwipeGestureRecognizer * swiperight = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(swiperight:)];
                swiperight.direction = UISwipeGestureRecognizerDirectionRight;
                [self.appWindow addGestureRecognizer:swiperight];
                
                _UIBackdropViewSettings *dropSettings = [_UIBackdropViewSettings settingsForStyle:2];
                _UIBackdropView *blurView = [[_UIBackdropView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT) autosizesToFitSuperview:YES settings:dropSettings];
                [self.appWindow addSubview:blurView];

                /*UIView *blurView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT)];
                UIVisualEffectView *wallVisualEffectView = [[UIVisualEffectView alloc] initWithFrame:blurView.bounds];
                wallVisualEffectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
                [blurView addSubview:wallVisualEffectView];
                [self.appWindow addSubview:blurView]; */
            
                UIView *searchView = [[UIView alloc] initWithFrame:CGRectMake(30, 50, DEVICE_WIDTH - 60, 50)];
                searchView.layer.masksToBounds = YES;
                searchView.layer.cornerRadius = 16;
                searchView.layer.continuousCorners = YES;
                searchView.backgroundColor = [UIColor clearColor];
                UIVisualEffectView *searchBlur = [[UIVisualEffectView alloc] initWithFrame:searchView.bounds];
                searchBlur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
                searchBlur.alpha = 0.75;
                
                UILabel *searchLabel = [[UILabel alloc] initWithFrame:searchView.bounds];
                searchLabel.textAlignment = NSTextAlignmentCenter;
                searchLabel.text = @"App Library";
                searchLabel.textColor = [UIColor whiteColor];
                searchLabel.font = [UIFont systemFontOfSize:20];
                [searchView addSubview:searchBlur];
                [searchView addSubview:searchLabel];
                searchLabel.layer.allowsGroupBlending = YES;
		        searchLabel.layer.allowsGroupOpacity = NO;
                searchLabel.layer.compositingFilter = kCAFilterDestOut;
                [self.appWindow addSubview:searchView];

                UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
                layout.minimumInteritemSpacing = 0;
                layout.minimumLineSpacing = 0;
                [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
                self.libraView = [[UICollectionView alloc] initWithFrame:CGRectMake(15, 115, DEVICE_WIDTH - 30, DEVICE_HEIGHT - 115) collectionViewLayout:layout]; // 115
                [self.libraView setDelegate:self];
                [self.libraView setDataSource:self];
                [self.libraView registerClass:[LibraCell class] forCellWithReuseIdentifier:@"cellIdentifier"];
                [self.libraView setBackgroundColor:[UIColor clearColor]];

                [self.appWindow addSubview:self.libraView];

                self.appWindow.alpha = 0.0;
                [self.appWindow makeKeyAndVisible];
                [UIView animateWithDuration:0.3 animations:^{
                    self.appWindow.alpha = 1.0;
                } completion:^(BOOL finished) {
                }];
            } else {
                self.appWindow.alpha = 0.0;
                [self.appWindow makeKeyAndVisible];
                [UIView animateWithDuration:0.3 animations:^{
                    self.appWindow.alpha = 1.0;
                } completion:^(BOOL finished) {
                }];
            }
        });
    }];

    /* UIWindow *appWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    appWindow.backgroundColor = [UIColor clearColor];
    appWindow.windowLevel = UIWindowLevelNormal;// UIWindowLevelAlert;
    UIView *blurView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT)];
    UIVisualEffectView *wallVisualEffectView = [[UIVisualEffectView alloc] initWithFrame:blurView.bounds];
    wallVisualEffectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    [blurView addSubview:wallVisualEffectView];
    [appWindow addSubview:blurView];
   
    UIView *searchView = [[UIView alloc] initWithFrame:CGRectMake(30, 50, DEVICE_WIDTH - 60, 50)];
    searchView.layer.masksToBounds = YES;
    searchView.layer.cornerRadius = 16;
    searchView.backgroundColor = [UIColor clearColor];
    UIVisualEffectView *searchBlur = [[UIVisualEffectView alloc] initWithFrame:searchView.bounds];
    searchBlur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    searchBlur.alpha = 0.75;
    
    UILabel *searchLabel = [[UILabel alloc] initWithFrame:searchView.bounds];
    searchLabel.textAlignment = NSTextAlignmentCenter;
    searchLabel.text = @"App Library";
    searchLabel.textColor = [UIColor lightGrayColor];
    searchLabel.font = [UIFont systemFontOfSize:20];
    [searchView addSubview:searchBlur];
    [searchView addSubview:searchLabel];
    [appWindow addSubview:searchView];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 0;
    layout.minimumLineSpacing = 0;
    [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
    self.libraView = [[UICollectionView alloc] initWithFrame:CGRectMake(15, 115, DEVICE_WIDTH - 30, DEVICE_HEIGHT - 140) collectionViewLayout:layout]; // 115
    [self.libraView setDelegate:self];
    [self.libraView setDataSource:self];
    [self.libraView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cellIdentifier"];
    [self.libraView setBackgroundColor:[UIColor clearColor]];

    [appWindow addSubview:self.libraView];

    appWindow.alpha = 0.0;
    self.appWindow = appWindow;
    [appWindow makeKeyAndVisible];
    [UIView animateWithDuration:0.3 animations:^{
        self.appWindow.alpha = 1.0;
    } completion:^(BOOL finished) {
	}]; */
}

%new

- (void)swiperight:(id)sender {
    [self removeView];
}

%new

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSArray *genres = [[NSUserDefaults standardUserDefaults] objectForKey:@"genres" inDomain:domainString];
    return genres.count / 2;
}

%new 

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

%new

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    LibraCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cellIdentifier" forIndexPath:indexPath] ?: [[LibraCell alloc] initWithFrame:CGRectMake(0, 0, self.libraView.bounds.size.width / 2, self.libraView.bounds.size.width / 2)];
    if (cell) {
        UIView *blurredBackground = [[UIView alloc] init];
        UILabel *genreLabel = [[UILabel alloc] init];
        blurredBackground.frame = CGRectMake(10, 10, cell.contentView.bounds.size.width - 20, cell.contentView.bounds.size.width - 20);
        blurredBackground.tag = 1;
        genreLabel.tag = 2;
        UIVisualEffectView *wallVisualEffectView = [[UIVisualEffectView alloc] initWithFrame:blurredBackground.bounds];
	    wallVisualEffectView.tag = 3;
        LibraButtonView *launcherOne = [[LibraButtonView alloc] initWithFrame:CGRectMake(10, 10, (blurredBackground.bounds.size.width - 30) / 2, (blurredBackground.bounds.size.width - 30) / 2)];
        launcherOne.backgroundColor = [UIColor clearColor];
        launcherOne.tag = 4;
        LibraButtonView *launcherTwo = [[LibraButtonView alloc] initWithFrame:CGRectMake(20 + (blurredBackground.bounds.size.width - 30) / 2, 10, (blurredBackground.bounds.size.width - 30) / 2, (blurredBackground.bounds.size.width - 30) / 2)];
        launcherTwo.backgroundColor = [UIColor clearColor];
        launcherTwo.tag = 5;
        LibraButtonView *launcherThree = [[LibraButtonView alloc] initWithFrame:CGRectMake(10, 20 + (blurredBackground.bounds.size.width - 30) / 2, (blurredBackground.bounds.size.width - 30) / 2, (blurredBackground.bounds.size.width - 30) / 2)];
        launcherThree.backgroundColor = [UIColor clearColor];
        launcherThree.tag = 6; 
        LibraAppView *appView = [[LibraAppView alloc] initWithFrame:CGRectMake(20 + (blurredBackground.bounds.size.width - 30) / 2, 20 + (blurredBackground.bounds.size.width - 30) / 2, (blurredBackground.bounds.size.width - 30) / 2, (blurredBackground.bounds.size.width - 30) / 2)];
        appView.tag = 7;
        LibraTapGestureRecognizer *tapGesture = [[LibraTapGestureRecognizer alloc] initWithTarget:self action:@selector(openStack:)];
	    tapGesture.numberOfTapsRequired = 1;
        tapGesture.identifier = [[[NSUserDefaults standardUserDefaults] objectForKey:@"genres" inDomain:domainString] objectAtIndex:indexPath.row];
        [appView addGestureRecognizer:tapGesture];
        [blurredBackground addSubview:wallVisualEffectView];
        [blurredBackground addSubview:launcherOne];
        [blurredBackground addSubview:launcherTwo];
        [blurredBackground addSubview:launcherThree];
        [blurredBackground addSubview:appView];
        [cell.contentView addSubview:blurredBackground];
        [cell.contentView addSubview:genreLabel];
    }

    UIView *blurredBackground = (UIView *)[cell.contentView viewWithTag:1];
    blurredBackground.layer.masksToBounds = YES;
    blurredBackground.layer.cornerRadius = 20;
    blurredBackground.layer.continuousCorners = YES;
    blurredBackground.backgroundColor = [UIColor clearColor];
    
    UIVisualEffectView *wallVisualEffectView = (UIVisualEffectView *)[cell.contentView viewWithTag:3];
    wallVisualEffectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]; // UIBlurEffectStyleSystemUltraThinMaterial
    
    UILabel *genreLabel = (UILabel *)[cell.contentView viewWithTag:2];
    genreLabel.font = [UIFont boldSystemFontOfSize:14];
    genreLabel.textAlignment = NSTextAlignmentCenter;
    genreLabel.text = [[[NSUserDefaults standardUserDefaults] objectForKey:@"genres" inDomain:domainString] objectAtIndex:indexPath.row]; // [NSString stringWithFormat:@"%ld, %ld, %@, %@", indexPath.row, indexPath.section, self.genres[[self getGenreIndex:indexPath.row:indexPath.section]], [self getAppsForGenreName:self.genres[[self getGenreIndex:indexPath.row:indexPath.section]]]];
    genreLabel.textColor = [UIColor whiteColor];
    genreLabel.translatesAutoresizingMaskIntoConstraints = false;
    [genreLabel.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:0].active = YES;
    [genreLabel.leftAnchor constraintEqualToAnchor:cell.contentView.leftAnchor constant:0].active = YES;
    [genreLabel.rightAnchor constraintEqualToAnchor:cell.contentView.rightAnchor constant:0].active = YES;
    // [genreLabel.topAnchor constraintEqualToAnchor:blurredBackground.topAnchor constant:0].active = YES;
    
    LibraButtonView *launcherOne = (LibraButtonView *)[cell.contentView viewWithTag:4];
    LibraButtonView *launcherTwo = (LibraButtonView *)[cell.contentView viewWithTag:5];
    LibraButtonView *launcherThree = (LibraButtonView *)[cell.contentView viewWithTag:6];
    LibraAppView *appView = (LibraAppView *)[cell.contentView viewWithTag:7];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *launcherOneID = [[self getAppsForGenreName:[[defaults objectForKey:@"genres" inDomain:domainString] objectAtIndex:indexPath.row]] objectAtIndex:0];
    if (launcherOneID) {
        [launcherOne setImage:[self iconImageForIdentifier:launcherOneID] forState:UIControlStateNormal];
        launcherOne.identifier = launcherOneID;
        [launcherOne addTarget:self action:@selector(openApp:) forControlEvents:UIControlEventTouchUpInside];
    }
    NSString *launcherTwoID = [[defaults objectForKey:[[defaults objectForKey:@"genres" inDomain:domainString] objectAtIndex:indexPath.row] inDomain:domainString] objectAtIndex:1]; //   [[self getAppsForGenreName:[self.genres objectAtIndex:indexPath.row]] objectAtIndex:0];
    if (launcherTwoID) {
        [launcherTwo setImage:[self iconImageForIdentifier:launcherTwoID] forState:UIControlStateNormal];
        launcherTwo.identifier = launcherTwoID;
        [launcherTwo addTarget:self action:@selector(openApp:) forControlEvents:UIControlEventTouchUpInside];
    }
    NSString *launcherThreeID = [[defaults objectForKey:[[defaults objectForKey:@"genres" inDomain:domainString] objectAtIndex:indexPath.row] inDomain:domainString] objectAtIndex:2]; //   [[self getAppsForGenreName:[self.genres objectAtIndex:indexPath.row]] objectAtIndex:0];
    if (launcherThreeID) {
        [launcherThree setImage:[self iconImageForIdentifier:launcherThreeID] forState:UIControlStateNormal];
        launcherThree.identifier = launcherThreeID;
        [launcherThree addTarget:self action:@selector(openApp:) forControlEvents:UIControlEventTouchUpInside];
    }
    NSArray *appsForIndexPath = [defaults objectForKey:[[defaults objectForKey:@"genres" inDomain:domainString] objectAtIndex:indexPath.row] inDomain:domainString]; //   [self getAppsForGenreName:[self.genres objectAtIndex:indexPath.row]];
    if (!([appsForIndexPath count] <= 3)) {
        appView.identifier = [[defaults objectForKey:@"genres" inDomain:domainString] objectAtIndex:indexPath.row];
        if ([appsForIndexPath count] >= 4) {
            UIImageView *libraViewOne = [[UIImageView alloc] initWithFrame:CGRectMake(5, 5, (appView.bounds.size.width - 15) / 2, (appView.bounds.size.height - 15) / 2)];
            [libraViewOne setImage:[self iconImageForIdentifier:[appsForIndexPath objectAtIndex:3]]];
            [appView addSubview:libraViewOne];
        }
        if ([appsForIndexPath count] >= 5) {
            UIImageView *libraViewTwo = [[UIImageView alloc] initWithFrame:CGRectMake(((appView.bounds.size.width - 15) / 2) + 10, 5, (appView.bounds.size.width - 15) / 2, (appView.bounds.size.height - 15) / 2)];
            [libraViewTwo setImage:[self iconImageForIdentifier:[appsForIndexPath objectAtIndex:4]]];
            [appView addSubview:libraViewTwo];
        }
        if ([appsForIndexPath count] >= 6) {
            UIImageView *libraViewThree = [[UIImageView alloc] initWithFrame:CGRectMake(5, ((appView.bounds.size.width - 15) / 2) + 10, (appView.bounds.size.width - 15) / 2, (appView.bounds.size.height - 15) / 2)];
            [libraViewThree setImage:[self iconImageForIdentifier:[appsForIndexPath objectAtIndex:5]]];
            [appView addSubview:libraViewThree];
        }
        if ([appsForIndexPath count] >= 7) {
            UIImageView *libraViewFour = [[UIImageView alloc] initWithFrame:CGRectMake(((appView.bounds.size.width - 15) / 2) + 10, ((appView.bounds.size.width - 15) / 2) + 10, (appView.bounds.size.width - 15) / 2, (appView.bounds.size.height - 15) / 2)];
            [libraViewFour setImage:[self iconImageForIdentifier:[appsForIndexPath objectAtIndex:6]]];
            [appView addSubview:libraViewFour];
        }
    }
    return cell;
}

%new

- (void)openApp:(LibraButtonView *)sender {
    [[UIApplication sharedApplication] launchApplicationWithIdentifier:sender.identifier suspended:0];
}

%new 

- (void)openStack:(LibraTapGestureRecognizer *)sender {
    NSLog(@"LIBRA DEBUG: %@", sender.identifier);
    if (!self.stackWindow) {
        self.stackWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.stackWindow.backgroundColor = [UIColor clearColor];
        self.stackWindow.windowLevel = UIWindowLevelNormal;
        self.stackWindow.userInteractionEnabled = 1;

        _UIBackdropViewSettings *dropSettings = [_UIBackdropViewSettings settingsForStyle:2];
        _UIBackdropView *blurView = [[_UIBackdropView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT) autosizesToFitSuperview:YES settings:dropSettings];
        [self.stackWindow addSubview:blurView];

        /* UIView *blurView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT)];
        UIVisualEffectView *wallVisualEffectView = [[UIVisualEffectView alloc] initWithFrame:blurView.bounds];
        wallVisualEffectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        [blurView addSubview:wallVisualEffectView];
        [self.stackWindow addSubview:blurView]; */

        

        UIView *dismissView = [[UIView alloc] initWithFrame:CGRectMake(0, DEVICE_HEIGHT - (DEVICE_WIDTH / 2), DEVICE_WIDTH, DEVICE_HEIGHT - (DEVICE_WIDTH / 2))];
        dismissView.backgroundColor = [UIColor clearColor];
        UITapGestureRecognizer *dismiss = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissStack:)];
        dismiss.numberOfTapsRequired = 1;
        [dismissView addGestureRecognizer:dismiss];
        [self.stackWindow addSubview:dismissView];

        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.minimumInteritemSpacing = 0;
        layout.minimumLineSpacing = 20;
        [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
        NSArray *apps = [[NSUserDefaults standardUserDefaults] objectForKey:sender.identifier inDomain:domainString];
        LibraStackView *appStack = [[LibraStackView alloc] initWithApps:apps];
        UICollectionView *stack = [[UICollectionView alloc] initWithFrame:CGRectMake(0, ([UIScreen mainScreen].bounds.size.height / 2) - ([UIScreen mainScreen].bounds.size.width / 2), [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width) collectionViewLayout:layout];
        [stack setDelegate:appStack];
        [stack setDataSource:appStack];
        [stack reloadData];
        [stack setBackgroundColor:[UIColor clearColor]];
        stack.tag = 2;
        [self.stackWindow addSubview:stack];
        
        /* appStack.tag = 2;
        appStack.userInteractionEnabled = YES;
        appStack.layer.zPosition = 10001;
        [appStack.stackView reloadData];
        [self.stackWindow addSubview:appStack]; */

        UILabel *genreLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, (DEVICE_HEIGHT / 2 ) - (DEVICE_WIDTH / 2) - 80, DEVICE_WIDTH - 20, 80)];
        genreLabel.textAlignment = NSTextAlignmentLeft;
        genreLabel.tag = 1;
        genreLabel.textColor = [UIColor whiteColor];
        genreLabel.font = [UIFont boldSystemFontOfSize:40];
        [self.stackWindow addSubview:genreLabel];

    } 
    UILabel *genreLabel = (UILabel *)[self.stackWindow viewWithTag:1];
    genreLabel.text = sender.identifier;
    UICollectionView *stack = (UICollectionView *)[self.stackWindow viewWithTag:2];
    // appStack = [[LibraStackView alloc] init];
    // [appStack setApps:[[NSUserDefaults standardUserDefaults] objectForKey:sender.identifier inDomain:domainString]];//   [self getAppsForGenreName:sender.identifier]];
    [stack reloadData];
    
    self.stackWindow.alpha = 0.0;
    self.libraView.alpha = 1.0;
    
    [self.stackWindow makeKeyAndVisible];
    [UIView animateWithDuration:0.3 animations:^{
        self.stackWindow.alpha = 1.0;
        self.libraView.alpha = 0.0;
    } completion:^(BOOL finished) {
    }];
}

%new

- (void)dismissStack:(UITapGestureRecognizer *)sender {
    self.libraView.alpha = 0.0;
    [UIView animateWithDuration:0.3 animations:^{
        self.libraView.alpha = 1.0;
        self.libraView.userInteractionEnabled = YES;
    } completion:^(BOOL finished) {
    }];
    self.stackWindow.hidden = YES;
}

%new

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake((DEVICE_WIDTH - 50) / 2, ((DEVICE_WIDTH - 50) / 2) + 20);
}

%new
- (UIEdgeInsets)collectionView:(UICollectionView *) collectionView layout:(UICollectionViewLayout *) collectionViewLayout insetForSectionAtIndex:(NSInteger) section {
    return UIEdgeInsetsMake(0, 5, 5, 5); // top, left, bottom, right
}

%new
- (UIVisualEffect *)getBlurStyle:(NSInteger)style {
	switch (style) {
		case 0:
		return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
		break;

	// Ultra Thin - Dark
		case 1:
		return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
		break;

	// Thin - Light
		case 2:
		return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight];
		break;

	// Thin - Dark
		case 3:
		// return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
		return [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        break;

	// Normal - Light
		case 4:
		return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialLight];
		break;

	// Normal - Dark
		case 5:
		return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
		break;

	// Thick - Light
		case 6:
		return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialLight];
		break;

	// Thick - Dark
		case 7:
		return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark];
		break;

	// Chrome - Light
		case 8:
		return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialLight];
		break;

	// Chrome - Dark
		case 9:
		return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
		break;

		case 10:
        return nil;
        break;

		default:
		return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
		break;
    }

}

%new

- (void)removeView {
    [UIView animateWithDuration:0.5 animations:^{
        self.appWindow.alpha = 0.0;
    } completion:^(BOOL finished) {
		[self.appWindow setHidden:YES];
	}];
}

%new

- (void)getGenres:(void (^)(void))completion {
    NSMutableArray *genresList = [[NSMutableArray alloc] init];
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"genres" inDomain:domainString]) {
        NSDictionary *apps = [[ALApplicationList sharedApplicationList] applications];
        // NSLog(@"LIBRA DEBUG: %@", apps);
        for (NSString *key in [apps allKeys]) {
            if (key != nil) {
                LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:[NSString stringWithFormat:@"%@", key]];
                NSString *genre = [proxy genre];
                if (genre != NULL) {
                    [genresList addObject:[proxy genre]];
                }
            }
        }
        NSOrderedSet *set = [[NSOrderedSet alloc] initWithArray:genresList];
        NSArray *genresFinal = [set array];
        self.genres = [genresFinal copy];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:[genresFinal copy] forKey:@"genres" inDomain:domainString];
        NSLog(@"LIBRA DEBUG: Genres -> %@", [defaults objectForKey:@"genres" inDomain:domainString]);
    }
    completion();
}
%end

%hook SBIconScrollView
- (void)_didEndDraggingNotification:(id)arg1 {
    %orig;
    if (getCurrentPage() == getMaxPage()) {
        [[%c(SBIconController) sharedInstance] setupView];
    }
}
%end

%hook SBMainSwitcherViewController
- (void)viewWillAppear:(BOOL)arg1 {
	%orig;
	UIWindow *appWindow = [[%c(SBIconController) sharedInstance] appWindow];
	if (appWindow != nil) {
        [UIView animateWithDuration:0.5 animations:^{
            appWindow.alpha = 0.0;
        } completion:^(BOOL finished) {
		    [appWindow setHidden:YES];
	    }];
		//appWindow.hidden = YES;
		// appWindow = nil;
	}
}
%end

%hook UITableViewCell
- (void)layoutSubviews {
	%orig;
	NSString *procName = [NSProcessInfo processInfo].processName;
	if ([procName isEqualToString:@"SpringBoard"]) {
		self.backgroundColor = [UIColor clearColor];
		self.selectionStyle = 0;
	}
}
%end