//
//  RODItemStore.m
//  selfies
//
//  Created by Seth Hayward on 11/14/13.
//  Copyright (c) 2013 bitwise. All rights reserved.
//

#import "RODItemStore.h"
#import "RODImageStore.h"
#import "RODSelfie.h"
#import "RODAuthie.h"

@implementation RODItemStore

- (id)init
{
    self = [super init];
    if (self) {
        
        NSString *path = [self itemArchivePath];

        _authie = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        
        if(!_authie) {
            NSLog(@"Generated new authie.");
            _authie = [[RODAuthie alloc] init];
            
            // automatically assume all new apps are not registered,
            // later on we'll need to add the functionality that lets
            // you log in to your account from another account.
            _authie.registered = NO;
            
            // generate a private key for the app/device 8)
            // THIS IS A USER's PASSWORD!
            NSString * uuid = [[NSUUID UUID] UUIDString];
            _authie.authieKey = uuid;
            
            [self saveChanges];
        } else {
            NSLog(@"Loaded authie from file.");
        }
        
        
        
        NSLog(@"current authie: registered: %i, authieKey: %@, selfies: %lu", self.authie.registered, self.authie.authieKey, (unsigned long)[self.allSelfies count]);
        
        if(!allSelfies)
            allSelfies = [[NSMutableArray alloc] init];
                
        self.recentSelfie = [allSelfies lastObject];
    }
    
    return self;
}

- (RODAuthie *)authie;
{
    return _authie;
}

- (NSArray *)allSelfies
{
    return allSelfies;
}

- (RODSelfie *)createSelfie:(NSString *)key
{
    RODSelfie *s = [[RODSelfie alloc] init];
    [s setSelfieKey:key];
    
    [allSelfies addObject:s];
    
    [self saveChanges];
    
    return s;
}

- (void)removeSelfie:(NSInteger)index
{
    NSString *key = [(RODSelfie *)[allSelfies objectAtIndex:index] selfieKey];
    [[RODImageStore sharedStore] deleteImageForKey:key];
    
    [allSelfies removeObjectAtIndex:index];
    
    [self saveChanges];
}

- (NSString *)itemArchivePath
{
    NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [documentDirectories objectAtIndex:0];
    
    return [documentDirectory stringByAppendingPathComponent:@"items.archive"];
}

- (BOOL)saveChanges
{    
    NSString *path = [self itemArchivePath];
    return [NSKeyedArchiver archiveRootObject:_authie toFile:path];
}

+ (RODItemStore *)sharedStore
{
    static RODItemStore *sharedStore = nil;
    if (!sharedStore) {
        sharedStore = [[super allocWithZone:nil] init];
    }
    
    return sharedStore;
}

+ (id)allocWithZone:(struct _NSZone *)zone
{
    return [self sharedStore];
}



@end
