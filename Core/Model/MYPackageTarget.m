//
//  MYPackageTarget.m
//  Package
//
//  Created by Whirlwind on 15/5/7.
//  Copyright (c) 2015年 taobao. All rights reserved.
//

#import "MYPackageTarget.h"
#import "MYPackageProject.h"

NSString *nameForTargetType(MYPackageTargetType type) {
    switch (type) {
        case MYPackageTargetTypeObjectFile:
            return @"Relocatable Object File";
        case MYPackageTargetTypeBundle:
            return @"Bundle";
        case MYPackageTargetTypeDynamicLibrary:
            return @"Dynamic Library";
        case MYPackageTargetTypeExecutable:
            return @"Executable";
        case MYPackageTargetTypeStaticLibrary:
            return @"Static Library";
        default:
            return @"Unknown";
    }
}

@interface MYPackageTarget ()

@end

@implementation MYPackageTarget

- (id)initWithName:(NSString *)name {
    if (self = [super init]) {
        _name = name;
    }
    return self;
}

#pragma mark - user configurations
/*
 {
 "Build Phases": [
 {
 "Check Pods Manifest.lock": [
 ]
 },
 {
 "SourcesBuildPhase": [
 "TBHDMain.m"
 ]
 },
 {
 "FrameworksBuildPhase": [
 ]
 },
 {
 "HeadersBuildPhase": [
 {
 "testFramework.h": {
 "ATTRIBUTES": [
 "Public"
 ]
 }
 },
 "TBHDMain.h"
 ]
 },
 {
 "ResourcesBuildPhase": [
 "Podfile.lock"
 ]
 }
 ],
 "Build Configurations": [
 {
 "Release": {
 "Build Settings": {
 "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks",
 "SDKROOT": "macosx",
 "VALID_ARCHS": "$(ARCHS_STANDARD)",
 "INFOPLIST_FILE": "testFramework copy-Info.plist",
 "DEFINES_MODULE": "YES",
 "DYLIB_COMPATIBILITY_VERSION": "1",
 "MACOSX_DEPLOYMENT_TARGET": "10.8",
 "INFOPLIST_PATH": "$(FULL_PRODUCT_NAME)/Info.plist",
 "INSTALL_PATH": "$(LOCAL_LIBRARY_DIR)/Frameworks",
 "SKIP_INSTALL": "YES",
 "DYLIB_INSTALL_NAME_BASE": "@rpath",
 "MACH_O_TYPE": "staticlib",
 "DYLIB_CURRENT_VERSION": "1",
 "LIBRARY_SEARCH_PATHS": [
 "$(inherited)",
 "$(PROJECT_DIR)/Pods/build/Debug-iphoneos"
 ],
 "OTHER_LDFLAGS": "",
 "PRODUCT_NAME": "testFramework2"
 },
 "Base Configuration": "Pods-mainClient.release.xcconfig"
 }
 }
 ]
 }
 */
- (void)setUserConfigrations:(NSDictionary *)userConfigrations {
    _userConfigrations = userConfigrations;
    [self anlayzeTargetFrameworkPhases];
    self.userBuildSettings = [[self valueForKey:@"Release" inArray:self.userConfigrations[@"Build Configurations"]] objectForKey:@"Build Settings"];
}

- (id)valueForKey:(NSString *)key inArray:(NSArray *)array {
    for (NSDictionary *dic in array) {
        NSArray *allKeys = [dic allKeys];
        if ([allKeys count] > 0) {
            if ([allKeys[0] isEqualToString:key]) {
                return dic[key];
            }
        }
    }
    return nil;
}

- (void)anlayzeTargetFrameworkPhases {
    NSArray        *frameworksBuildPhase = [self valueForKey:@"FrameworksBuildPhase" inArray:self.userConfigrations[@"Build Phases"]];
    NSString       *frameworkName        = [self.name hasSuffix:@"Demo"] ? [[self.name substringToIndex:[self.name length] - 4] stringByAppendingPathExtension:@"framework"] : nil;
    NSMutableArray *frameworks           = [NSMutableArray array];
    NSMutableArray *libraries            = [NSMutableArray array];
    for (id key in frameworksBuildPhase) {
        NSString *phase = nil;
        if ([key isKindOfClass:[NSString class]]) {
            phase = key;
        } else if ([key isKindOfClass:[NSDictionary class]]) {
            phase = [[key allKeys] objectAtIndex:0];
        } else {
            continue;
        }
        NSString *extension = [phase pathExtension];
        if ([extension isEqualToString:@"framework"]) {
            if (!frameworkName || ![phase isEqualToString:frameworkName]) {
                [frameworks addObject:[phase stringByDeletingPathExtension]];
            }
        } else if (([@[@"a", @"dylib", @"tbd"] indexOfObject:extension] != NSNotFound) && [phase hasPrefix:@"lib"]) {
            if (![phase hasPrefix:@"libPods"]) {
                [libraries addObject:[[phase stringByDeletingPathExtension] substringFromIndex:3]];
            }
        }
    }
    self.libraries  = libraries;
    self.frameworks = frameworks;

    // 只有动态库和静态库需要拷贝本地 framework
    if (self.type == MYPackageTargetTypeStaticLibrary || self.type == MYPackageTargetTypeDynamicLibrary) {
        NSMutableDictionary *local   = [NSMutableDictionary dictionaryWithCapacity:[self.frameworks count]];
        NSDictionary        *allFwks = self.project.info[@"Frameworks"];
        for (NSString *framework in self.frameworks) {
            NSString *path = [allFwks objectForKey:[framework stringByAppendingPathExtension:@"framework"]];
            if (path) {
                if ([path hasPrefix:@"/"]) {
                    if ([path rangeOfString:@"/usr/lib/"].location != NSNotFound || [path rangeOfString:@"/System/Library/Frameworks/"].location != NSNotFound) { // 系统库
                        continue;
                    }
                } else {
                    path = [[self.project.filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:path];
                }
                BOOL isDirectory;
                if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
                    [local setObject:path forKey:[framework stringByAppendingPathExtension:@"framework"]];
                }
            }
        }
        self.localFrameworks = local;
    }
}

#pragma mark - configurations

- (void)setConfigurations:(NSDictionary *)configurations {
    _configurations = configurations;
    NSString *type = [configurations objectForKey:@"MACH_O_TYPE"];
    if ([type isEqualToString:@"staticlib"]) {
        _type = MYPackageTargetTypeStaticLibrary;
    } else if ([type isEqualToString:@"mh_execute"]) {
        _type = MYPackageTargetTypeExecutable;
    } else if ([type isEqualToString:@"mh_dylib"]) {
        _type = MYPackageTargetTypeDynamicLibrary;
    } else if ([type isEqualToString:@"mh_bundle"]) {
        _type = MYPackageTargetTypeBundle;
    } else if ([type isEqualToString:@"mh_object"]) {
        _type = MYPackageTargetTypeObjectFile;
    }
}

- (NSString *)configurationForKey:(NSString *)key {
    return [self.configurations objectForKey:key];
}

- (BOOL)isSharedLibrary {
    return (_type & (MYPackageTargetTypeDynamicLibrary|MYPackageTargetTypeObjectFile|MYPackageTargetTypeStaticLibrary)) > 0;
}

- (NSString *)wrapperExtension {
    return [self configurationForKey:@"WRAPPER_EXTENSION"];
}

- (NSString *)productName {
    // like "testFramework"
    return [self configurationForKey:@"PRODUCT_NAME"];
}

- (NSString *)fullProductName {
    // like "testFramework.framework"
    return [self configurationForKey:@"FULL_PRODUCT_NAME"];
}

- (NSString *)originInfoPlistPath {
    // like "testFramework/Info.plist"
    // this is different with INFOPLIST_PATH
    return [self configurationForKey:@"INFOPLIST_FILE"];
}

- (NSString *)infoPlistPath {
    // like "testFramework.framework/Info.plist"
    return [self configurationForKey:@"INFOPLIST_PATH"];
}

- (NSString *)binaryPath {
    // like "testFramework.framework/testFramework"
    return [self configurationForKey:@"EXECUTABLE_PATH"];
}

- (NSString *)resourcePath {
    // like "testFramework.framework/Resources"
    return [self.fullProductName stringByAppendingPathComponent:@"Resources"];
}

- (NSString *)publicHeaderPath {
    // like "testFramework.framework/Headers"
    return [self configurationForKey:@"PUBLIC_HEADERS_FOLDER_PATH"];
}

- (NSString *)systemMinVersion {
    if ([self.supportedPlatform isEqualToString:@"ios"]) {
        return [self configurationForKey:@"IPHONEOS_DEPLOYMENT_TARGET"];
    }
    return [self configurationForKey:@"MACOSX_DEPLOYMENT_TARGET"];
}

- (NSString *)supportedPlatform {
    NSString *platform = [self configurationForKey:@"SUPPORTED_PLATFORMS"];
    if ([platform isEqualToString:@"macosx"]) {
        return @"osx";
    }
    return @"ios";
}

- (NSString *)zipFileName {
    return [self.name stringByAppendingString:@".zip"];
}

#pragma mark - TBJSONModel
+ (NSDictionary *)jsonToModelKeyMapDictionary {
    return @{@"Build Phases": @"phases"};
}

@end
