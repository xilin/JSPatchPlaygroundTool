//
//  JPPlayground.m
//  JSPatchPlaygroundDemo
//
//  Created by Awhisper on 16/8/7.
//  Copyright © 2016年 baidu. All rights reserved.
//

#import "JPPlayground.h"
#import "JPKeyCommands.h"
#import "JPCleaner.h"
#import "JPDevErrorView.h"
#import "JPDevMenu.h"
#import "JPDevTipView.h"
#import "SGDirWatchdog.h"

@interface JPPlayground ()<UIActionSheetDelegate,JPDevMenuDelegate>

@property (nonatomic,strong) NSString *rootPath;

@property (nonatomic,strong) JPKeyCommands *keyManager;

@property (nonatomic,strong) UIView *errorView;

@property (nonatomic,strong) JPDevMenu *devMenu;

@property (nonatomic,assign) BOOL isAutoReloading;

@property (nonatomic,strong) NSMutableArray<SGDirWatchdog *> *watchDogs;

@end

static void (^_reloadCompleteHandler)(void) = ^void(void) {
   
};

@implementation JPPlayground

+ (instancetype)sharedInstance
{
    static JPPlayground *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [self new];
    });
    
    return sharedInstance;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _keyManager = [JPKeyCommands sharedInstance];
        _devMenu = [[JPDevMenu alloc]init];
        _devMenu.delegate = self;
        _isAutoReloading = NO;
        _watchDogs = [[NSMutableArray alloc] init];
    }
    return self;
}

+(void)setReloadCompleteHandler:(void (^)())complete
{
    _reloadCompleteHandler = [complete copy];
}

+(void)startPlaygroundWithJSPath:(NSString *)path
{
    [[JPPlayground sharedInstance] startPlaygroundWithJSPath:path];
}

-(void)startPlaygroundWithJSPath:(NSString *)mainScriptPath
{
    self.rootPath = mainScriptPath;
    
    NSString *scriptRootPath = [mainScriptPath stringByDeletingLastPathComponent];
    
    NSArray *contentOfFolder = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:scriptRootPath error:NULL];
    [self watchFolder:scriptRootPath mainScriptPath:mainScriptPath];
    
    if ([scriptRootPath rangeOfString:@".app"].location != NSNotFound) {
        NSString *apphomepath = [scriptRootPath stringByDeletingLastPathComponent];
        [self watchFolder:apphomepath mainScriptPath:mainScriptPath];
    }
    
    for (NSString *aPath in contentOfFolder) {
        NSString * fullPath = [scriptRootPath stringByAppendingPathComponent:aPath];
        BOOL isDir;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) {
            [self watchFolder:fullPath mainScriptPath:mainScriptPath];
        }
    }
    
    
    [JPEngine handleException:^(NSString *msg) {
        JPDevErrorView *errV = [[JPDevErrorView alloc]initError:msg];
        [[UIApplication sharedApplication].keyWindow addSubview:errV];
        self.errorView = errV;
        [self.devMenu toggle];
    }];
    
    [self.keyManager registerKeyCommandWithInput:@"x" modifierFlags:UIKeyModifierCommand action:^(UIKeyCommand *command) {
        [self.devMenu toggle];
    }];
    
    [self.keyManager registerKeyCommandWithInput:@"r" modifierFlags:UIKeyModifierCommand action:^(UIKeyCommand *command) {
        [self reload];
    }];
    
}

+(void)reload
{
    [[JPPlayground sharedInstance]reload];
}

-(void)reload
{
    [JPDevTipView showJPDevTip:@"JSPatch Reloading ..."];
    [self hideErrorView];
    [JPCleaner cleanAll];
    NSString *script = [NSString stringWithContentsOfFile:self.rootPath encoding:NSUTF8StringEncoding error:nil];
    [JPEngine evaluateScript:script];
    _reloadCompleteHandler();
    
}

-(void)openInFinder
{
    NSLog(@"%@\n",self.rootPath);
    
    NSLog(@"请打开以上路径的文件，事实编辑JS，事实刷新");
    
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Edit JS File" message:@"查看控制台，打开打印出来的路径下的JS文件，实时编辑，实时刷新" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [alert show];
    [UIPasteboard generalPasteboard].string = self.rootPath;
    
//    NSURL *fileUrl = [[NSURL alloc]initFileURLWithPath:self.rootPath];
//    [[UIApplication sharedApplication]openURL:fileUrl];
}

-(void)watchJSFile:(BOOL)watch
{
    for (SGDirWatchdog *dog in self.watchDogs) {
        if (watch) {
            [dog start];
        }else{
            [dog stop];
        }
    }

}

- (void)watchFolder:(NSString *)folderPath mainScriptPath:(NSString *)mainScriptPath
{
    SGDirWatchdog *watchDog = [[SGDirWatchdog alloc] initWithPath:folderPath update:^{
        [self reload];
    }];
    [self.watchDogs addObject:watchDog];
}

-(void)hideErrorView
{
    [self.errorView removeFromSuperview];
    self.errorView = nil;
}


-(void)devMenuDidAction:(JPDevMenuAction)action withValue:(id)value
{
    switch (action) {
        case JPDevMenuActionReload:{
            [self reload];
            break;
        }
        case JPDevMenuActionAutoReload:{
            BOOL select = [value boolValue];
            [self watchJSFile:select];
            break;
        }
        case JPDevMenuActionOpenJS:{
            [self openInFinder];
            break;
        }
        case JPDevMenuActionCancel:{
            
            break;
        }
            
            
        default:
            break;
    }
}
@end
