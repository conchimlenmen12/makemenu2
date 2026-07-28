//
//  lara-Bridging-Header.h
//  lara
//

@import UIKit;
#import <Foundation/Foundation.h>

#import "darksword.h"
#import "offsets.h"
#import "utils.h"
#import "vnode.h"
// #import "apfs.h"             // Disabled for game cheat mode
// #import "vfs.h"              // VFS redirect disabled for game cheat mode
// #import "sbx.h"              // Sandbox escape disabled for game cheat mode
#import "IconServices.h"
// #import "rc.h"               // RemoteCall disabled for game cheat mode
// #import "RemoteCall.h"       // RemoteCall disabled for game cheat mode

#import <zlib.h>

long findcachedataoff(const char *mgkey);
void LaraClearIconCache(void);

@interface UIDevice(Private)
+ (BOOL)_hasHomeButton;
@end

void test(NSString *path);

NS_ASSUME_NONNULL_BEGIN

@interface VarCleanBridge : NSObject

+ (NSDictionary *)loadRulesNamed:(NSString *)resourceName
                        inBundle:(NSBundle *)bundle
                           error:(NSError * _Nullable * _Nullable)error;

+ (BOOL)probePathExists:(NSString *)path
            isDirectory:(BOOL *)isDirectory
              isSymlink:(BOOL *)isSymlink;

@end

NS_ASSUME_NONNULL_END
