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
#import "RegisterViewController.h"
#import "AppDelegate.h"
#import "RODResponseMessage.h"
#import "RODHandle.h"
#import "RODThread.h"
#import "RODFollower.h"
#import "MasterViewController.h"

@implementation RODItemStore
@synthesize loadedThreadsFromAuthor;

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
            NSLog(@"Loaded authie from file, public/private: %@, %@", self.authie.handle.publicKey, self.authie.handle.privateKey);
        }
        
        NSLog(@"current authie: registered: %i, authieKey: %@, selfies: %lu, id: %@, name: %@", self.authie.registered, self.authie.authieKey, (unsigned long)[self.authie.allSelfies count], self.authie.handle.id, self.authie.handle.name);
        
        if(!_authie.allContacts)
            _authie.allContacts = [[NSMutableArray alloc] init];
        
        if(!_authie.allSelfies)
            _authie.allSelfies = [[NSMutableArray alloc] init];
        
        if(!_authie.allThreads)
            _authie.allThreads = [[NSMutableArray alloc] init];
        
                
        
    }
    
    return self;
}

- (RODAuthie *)authie;
{
    return _authie;
}

- (RODSelfie *)createSelfie:(NSString *)key
{
    RODSelfie *s = [[RODSelfie alloc] init];
    [s setSelfieKey:key];
    
    [_authie.allSelfies addObject:s];
    
    [self saveChanges];
    
    return s;
}

- (void)removeThread:(RODThread *)thread
{
    
    NSLog(@"Remove thread: %@", thread.groupKey);
    
    NSError *error = nil;
    
    NSData *jsonData;
    [jsonData setValue:thread.groupKey forKey:@""];
    
    NSMutableData *data = [NSMutableData data];
    [data appendData:[[NSString stringWithFormat:@"=%@",thread.groupKey] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = @"http://authie.me/api/thread";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"DELETE"];
    
    if(error == nil) {
        [request setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setHTTPBody:data];
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingAllowFragments error:&deserialize_error];
        
        if([object isKindOfClass:[NSDictionary class]] && deserialize_error == nil) {
            
            NSLog(@"results from delete: %@", object);
            
            NSInteger response_result;
            response_result = [[object objectForKey:@"result"] integerValue];
            
            if(response_result == 1) {
                [self loadThreads];
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                [appDelegate.masterViewController.navigationController popToRootViewControllerAnimated:YES];
                
            }
            
            
        }
        
    } else {
        NSLog(@"Error: %@", error);
    }

    
    [[RODImageStore sharedStore] deleteImageForKey:thread.groupKey];
    
    [self saveChanges];
}

- (NSString *)itemArchivePath
{
    NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [documentDirectories objectAtIndex:0];
    
    return [documentDirectory stringByAppendingPathComponent:@"items.archive"];
}

- (BOOL)login
{
    BOOL logged_in = NO;
    
	// Create a new letter and POST it to the server
    
    NSDictionary *checkDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                               @"1", @"id",
                               self.authie.handle.name, @"name",
                               @"1", @"active",
                               @"lol", @"userGuid",
                               self.authie.handle.publicKey, @"publicKey",
                               self.authie.handle.privateKey, @"privateKey",
                               nil];
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:checkDict options:kNilOptions error:&error];
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = @"http://authie.me/api/login";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    
    if(error == nil) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setHTTPBody:jsonData];
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingAllowFragments error:&deserialize_error];
        
        if([object isKindOfClass:[NSDictionary class]] && deserialize_error == nil) {

            NSLog(@"results from login: %@", object);
            
            NSInteger response_result;
            response_result = [[object objectForKey:@"result"] integerValue];
            
            if(response_result == 0) {
                logged_in = NO;
            } else {
                logged_in = YES;
            }
            
        }
        
    }
    
    return logged_in;
}

- (BOOL)checkLoginStatus
{
    
    BOOL is_logged_in = NO;
    
    NSError *error = nil;
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = @"http://authie.me/api/login";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    
    if(error == nil) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingAllowFragments error:&deserialize_error];
        if([object isKindOfClass:[NSDictionary class]] && deserialize_error == nil) {

            NSLog(@"results from login: %@", object);
            
            NSInteger response_result;
            response_result = [[object objectForKey:@"result"] integerValue];
            
            if(response_result == 0) {
                is_logged_in = NO;
            } else {
                //[self loadThreads];
                is_logged_in = YES;
                
                [self loadThreads];
                [self loadContacts];

            }
            
        }
        
    }
    
    return is_logged_in;
    
}

- (BOOL)uploadSnap:(NSString *)key
{
    BOOL upload_success = NO;

    NSError *error = nil;
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = [NSString stringWithFormat:@"http://authie.me/api/upload/postfile?key=%@", key];

    NSLog(@"ok, about to upload snap: %@", key);
    
    // create request
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setHTTPShouldHandleCookies:NO];
    [request setTimeoutInterval:30];
    [request setHTTPMethod:@"POST"];

    // ??????
    NSString *boundary = @"0xKhTmLbOuNdArY";
    
    // set Content-Type in HTTP header
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    // post body
    NSMutableData *body = [NSMutableData data];

    // add image data
    NSData *imageData = UIImageJPEGRepresentation([[RODImageStore sharedStore] imageForKey:key], 0.25);
    
    if (imageData) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"image.jpg\"\r\n", @"file"] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Type: image/jpeg\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:imageData];
        [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", @"groupKey"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // setting the body of the post to the reqeust
    [request setHTTPBody:body];
    
    // set URL
    [request setURL:[NSURL URLWithString:url]];
    
    if(error == nil) {
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingAllowFragments error:&deserialize_error];
        if([object isKindOfClass:[NSDictionary class]] && deserialize_error == nil) {
            
            NSLog(@"results from postfile: %@", object);
            
            upload_success = YES;
            
        } else {
            NSLog(@"weird object from postfile, %@", object);
        }
        
    }
    
    NSLog(@".. and we done");
    
    return upload_success;
}

- (BOOL)startThread:(NSString *)toHandle forKey:(NSString *)key;
{
    
    BOOL start_convo_success = NO;
    
	// Create a new letter and POST it to the server
        
    NSDictionary *checkDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                               toHandle, @"toGuid",
                               key, @"groupKey",
                               nil];
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:checkDict options:kNilOptions error:&error];
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = @"http://authie.me/api/thread";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    
    if(error == nil) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setHTTPBody:jsonData];
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingAllowFragments error:&deserialize_error];
        
        if([object isKindOfClass:[NSDictionary class]] && deserialize_error == nil) {
            
            NSLog(@"results from startConvo: %@", object);
            
            NSInteger response_result;
            response_result = [[object objectForKey:@"result"] integerValue];
            
            if(response_result == 0) {
                start_convo_success = NO;
            } else {
                start_convo_success = YES;
                
                [self uploadSnap:key];
                [self loadThreads];
                
                
            }
            
        }
        
    }
    
    return start_convo_success;
}

- (BOOL)addContact:(NSString *)handle
{
    NSLog(@"Added contact: %@", handle);
    
    BOOL added_contact = NO;
    
    NSError *error = nil;
    
    NSData *jsonData;
    [jsonData setValue:handle forKey:@""];
    
    NSMutableData *data = [NSMutableData data];
    [data appendData:[[NSString stringWithFormat:@"=%@",handle] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = @"http://authie.me/api/follower";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    
    if(error == nil) {
        [request setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setHTTPBody:data];
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingAllowFragments error:&deserialize_error];
        
        if([object isKindOfClass:[NSDictionary class]] && deserialize_error == nil) {
            
            NSLog(@"results from add_contact: %@", object);
            
            NSInteger result = [[object objectForKey:@"result"] integerValue];
            
            if(result == 1) {
                [self loadContacts];
            } else {
                
                NSString *message = [object objectForKey:@"message"];
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"error" message:message delegate:self cancelButtonTitle:@"ok" otherButtonTitles:nil];
                [alert show];
                
            }

        }
        
    } else {
        NSLog(@"Error: %@", error);
    }
    
    return added_contact;
}

- (BOOL)loadContacts
{
    
    BOOL loaded_contacts = NO;

    NSLog(@"loadContacts.");
    
    NSError *error = nil;
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = @"http://authie.me/api/follower";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    
    if(error == nil) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingMutableContainers error:&deserialize_error];
        
        if([object isKindOfClass:[NSArray self]] && deserialize_error == nil) {
            
            // clear all old contacts
            [self.authie.allContacts removeAllObjects];
            
            for (NSDictionary *result in object) {
                
                NSLog(@"found contact: %@", result);
                
                RODHandle *followeeHandle = [[RODHandle alloc] init];
                
                NSDictionary *from_result = [result objectForKey:@"followeeHandle"];
                
                followeeHandle.name = [from_result objectForKey:@"name"];
                followeeHandle.publicKey = [from_result objectForKey:@"publicKey"];
                
                [self.authie.allContacts addObject:followeeHandle];
                
            }

            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate.contactsViewController.tableView reloadData];
                        
            loaded_contacts = YES;
            
        } else {
            NSLog(@"Not that kind of object: %@, deserialize_error: %@", object, deserialize_error);
        }
        
    }
    
    return loaded_contacts;
}

- (BOOL)loadThreads
{
    BOOL loaded_convos = NO;
    
    NSError *error = nil;
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = @"http://authie.me/api/thread";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    
    if(error == nil) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingMutableContainers error:&deserialize_error];
        if([object isKindOfClass:[NSArray self]] && deserialize_error == nil) {

            // clear all other threads
            [self.authie.allThreads removeAllObjects];
            
            for (NSDictionary *result in object) {
                
                NSInteger id_result = [[result objectForKey:@"id"] integerValue];

                
                // replace them with the new ones
                RODThread *thready = [[RODThread alloc] init];
                thready.id = [NSNumber numberWithInteger:id_result];
                
                
                NSDictionary *inner_result = [result objectForKey:@"toHandle"];
                NSString *to_result = [inner_result objectForKey:@"name"];
                
                NSDictionary *from_inner_result = [result objectForKey:@"fromHandle"];
                NSString *from_result = [NSString stringWithFormat:@"from: %@",[from_inner_result objectForKey:@"name"]];
                
                thready.groupKey = [result objectForKey:@"groupKey"];
                thready.toHandleId = to_result;
                thready.fromHandleId = from_result;
                thready.startDate = [NSDate new];
                
                [self.authie.allThreads addObject:thready];

                NSLog(@"found thread %@ to %@, from %@", thready.groupKey, to_result, from_result);

                
            }
            
            loaded_convos = YES;
            
        } else {
            NSLog(@"Not that kind of object: %@, deserialize_error: %@", object, deserialize_error);
        }
        
    }

    return loaded_convos;
}

- (BOOL)getThreadsFromHandle:(NSString *)publicKey
{
    BOOL loaded_threads = NO;

    NSError *error = nil;
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = [NSString stringWithFormat:@"http://authie.me/api/threads/%@", publicKey];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    
    if(error == nil) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingMutableContainers error:&deserialize_error];
        if([object isKindOfClass:[NSArray self]] && deserialize_error == nil) {
            
            // clear out old threads
            [self.loadedThreadsFromAuthor removeAllObjects];
            
            for (NSDictionary *result in object) {
                
                NSInteger id_result = [[result objectForKey:@"id"] integerValue];
                
                // replace them with the new ones
                RODThread *thready = [[RODThread alloc] init];
                thready.id = [NSNumber numberWithInteger:id_result];
                                
                NSDictionary *inner_result = [result objectForKey:@"toHandle"];
                NSString *to_result = [inner_result objectForKey:@"name"];
                
                NSDictionary *from_inner_result = [result objectForKey:@"fromHandle"];
                NSString *from_result = [NSString stringWithFormat:@"from: %@",[from_inner_result objectForKey:@"name"]];
                
                thready.groupKey = [result objectForKey:@"groupKey"];
                thready.toHandleId = to_result;
                thready.fromHandleId = from_result;
                thready.startDate = [NSDate new];
                
                [self.loadedThreadsFromAuthor addObject:thready];
                
                NSLog(@"found thread %@ to %@, from %@", thready.groupKey, to_result, from_result);
                
                
            }
            
            loaded_threads = YES;
            
        } else {
            NSLog(@"Not that kind of object: %@, deserialize_error: %@", object, deserialize_error);
        }
        
    }

    
    
    return loaded_threads;
}


- (BOOL)checkHandleAvailability:(NSString *)handle
{
   
    BOOL is_available = NO;
    
	// Create a new letter and POST it to the server
	RODHandle* check_handle = [RODHandle new];
    check_handle.active = [NSNumber numberWithInt:1];
    check_handle.userGuid = @"lol";
    check_handle.name = handle;
    check_handle.id = [NSNumber numberWithInt:1];

    NSDictionary *checkDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                               @"1", @"id",
                               handle, @"name",
                               @"1", @"active",
                               @"lol", @"userGuid",
                               nil];
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:checkDict options:kNilOptions error:&error];
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = @"http://authie.me/api/checkhandle";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    
    if(error == nil) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setHTTPBody:jsonData];
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingAllowFragments error:&deserialize_error];
        
        if([object isKindOfClass:[NSDictionary class]] && deserialize_error == nil) {
            
            NSInteger response_result;
            response_result = [[object objectForKey:@"result"] integerValue];

            if(response_result == 0) {
                is_available = NO;
            } else {
                is_available = YES;
            }
            
        }
        
    }
    
    return is_available;
    
}

- (BOOL)registerHandle:(NSString *)handle
{
    bool registered_result = NO;
    
	// Create a new letter and POST it to the server
	RODHandle* check_handle = [RODHandle new];
    check_handle.active = [NSNumber numberWithInt:1];
    check_handle.userGuid = @"lol";
    check_handle.name = handle;
    check_handle.id = [NSNumber numberWithInt:1];
    
    NSDictionary *checkDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                               @"1", @"id",
                               handle, @"name",
                               @"1", @"active",
                               @"lol", @"userGuid",
                               nil];
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:checkDict options:kNilOptions error:&error];
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = @"http://authie.me/api/handle";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    
    if(error == nil) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setHTTPBody:jsonData];
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingAllowFragments error:&deserialize_error];
        
        if([object isKindOfClass:[NSDictionary class]] && deserialize_error == nil) {
            
            NSLog(@"results from registration: %@", object);
            
            NSInteger active_result;
            active_result = [[object objectForKey:@"active"] integerValue];
            
            NSInteger id_result;
            id_result = [[object objectForKey:@"id"] integerValue];
            
            NSString *privateKey;
            privateKey = [object objectForKey:@"privateKey"];
            
            NSString *publicKey;
            publicKey = [object objectForKey:@"publicKey"];
            
            NSString *name;
            name = [object objectForKey:@"name"];
            
            NSString *userGuid;
            userGuid = [object objectForKey:@"userGuid"];
                        
            if(active_result == 1) {
                registered_result = YES;
                [self.authie setRegistered:1];
                
                self.authie.handle = [[RODHandle alloc] init];

                [self.authie.handle setId:[NSNumber numberWithInteger:id_result]];
                [self.authie.handle setName:name];
                [self.authie.handle setActive:[NSNumber numberWithInteger:active_result]];
                [self.authie.handle setUserGuid:userGuid];
                [self.authie.handle setPrivateKey:privateKey];
                [self.authie.handle setPublicKey:publicKey];
                
                NSLog(@"id: %lu, privateKey: %@, publicKey: %@", [self.authie.handle.id longValue], self.authie.handle.privateKey, self.authie.handle.publicKey);
                
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                [appDelegate.masterViewController.navigationController popToRootViewControllerAnimated:YES];
                
                [self saveChanges];
            } else {
                registered_result = NO;
            }
            
        }
        
    }
    
    return registered_result;
    
}

- (BOOL)saveChanges
{    
    NSString *path = [self itemArchivePath];
    return [NSKeyedArchiver archiveRootObject:_authie toFile:path];
}

- (UIView *)generateHeaderView
{
    
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
