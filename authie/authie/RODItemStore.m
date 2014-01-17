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
            _authie.privateKey = uuid;
            
            [self saveChanges];
        } else {
            NSLog(@"Loaded authie from file, public/private: %@, %@", self.authie.handle.publicKey, self.authie.handle.privateKey);
                        
        }
        
        NSLog(@"current authie: registered: %i, authieKey: %@, selfies: %lu, id: %@, name: %@", self.authie.registered, self.authie.privateKey, (unsigned long)[self.authie.allSelfies count], self.authie.handle.id, self.authie.handle.name);
        
        if(!_authie.allContacts)
            _authie.allContacts = [[NSMutableArray alloc] init];
        
        if(!_authie.allSelfies)
            _authie.allSelfies = [[NSMutableArray alloc] init];
        
        if(!_authie.allThreads)
            _authie.allThreads = [[NSMutableArray alloc] init];
        
        if(!loadedThreadsFromAuthor)
            loadedThreadsFromAuthor = [[NSMutableArray alloc] init];
        
        if(!self.dailyThreads) {
            self.dailyThreads = [[NSMutableArray alloc] init];
        }
        
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

- (void) removeContact:(RODHandle *)handle
{
    NSLog(@"Remove contact: %@", handle.name);

    NSError *error = nil;
    
    NSMutableData *data = [NSMutableData data];
    [data appendData:[[NSString stringWithFormat:@"=%@",handle.name] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = @"http://authie.me/api/follower";
    
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
            
            NSLog(@"results from delete contact: %@", object);
            
            NSInteger response_result;
            response_result = [[object objectForKey:@"result"] integerValue];
            
            if(response_result == 1) {
                [self loadContacts];
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                [appDelegate.contactsViewController.navigationController popToRootViewControllerAnimated:YES];
                
            }
            
            
        }
        
    } else {
        NSLog(@"Error: %@", error);
    }
    
    
    [self saveChanges];
    
}

- (void)removeThread:(RODThread *)thread
{
    
    NSLog(@"Remove thread: %@", thread.groupKey);
    
    NSError *error = nil;
    
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

                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"bye" message:@"This thread has been trashed." delegate:appDelegate.masterViewController cancelButtonTitle:@"ok" otherButtonTitles:nil];

                [alert show];
                
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

- (void)report:(NSString *)groupKey
{
    NSError *error = nil;
    NSData *localData = nil;
    NSURLResponse *response;
    
    NSDictionary *checkDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                               @"1", @"id",
                               @"1", @"fromHandleId",
                               @"1", @"toHandleId",
                               groupKey, @"groupKey",
                               @"1", @"active",
                               @"", @"caption",
                               nil];
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:checkDict options:kNilOptions error:&error];
    
    NSString *url = @"http://authie.me/api/report";
    
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
        
        if(deserialize_error == nil) {
            
            NSLog(@"results from report: %@", object);
            
        }
        
    }
    

}

- (void)giveLove:(NSString *)groupKey
{
    NSError *error = nil;
    NSData *localData = nil;
    NSURLResponse *response;

    NSDictionary *checkDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                               @"1", @"id",
                               @"1", @"fromHandleId",
                               @"1", @"toHandleId",
                               groupKey, @"groupKey",
                               @"1", @"active",
                               @"", @"caption",
                               nil];
    
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:checkDict options:kNilOptions error:&error];
    
    NSString *url = @"http://authie.me/api/heart";
    
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
        
        if(deserialize_error == nil) {
            
            NSLog(@"results from heart: %@", object);
            
            //NSInteger response_result;
            //response_result = [[object objectForKey:@"result"] integerValue];
            
            //NSString *message_result;
            // this will contain our private key if we were successful
            //message_result = [object objectForKey:@"message"];
            
        }
        
    }
    
}

- (BOOL)login:(NSString *)handle privateKey:(NSString *)key;
{
    BOOL logged_in = NO;
    
    NSDictionary *checkDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                               @"1", @"id",
                               handle, @"name",
                               @"1", @"active",
                               @"lol", @"userGuid",
                               key, @"publicKey",
                               key, @"privateKey",
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
            
            NSString *message_result;
            // this will contain our private key if we were successful
            message_result = [object objectForKey:@"message"];
            
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            
            if(response_result == 0) {
                logged_in = NO;
                [appDelegate.loginViewController.labelResults setText:message_result];
            } else {
                logged_in = YES;
                
                [RODItemStore sharedStore].authie.handle.privateKey = message_result;
                [RODItemStore sharedStore].authie.privateKey = message_result;
                [[RODItemStore sharedStore] saveChanges];
                NSLog(@"found key: %@", message_result);
                
                [self getHandleInformation];
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

- (BOOL)getHandleInformation
{
    BOOL got = NO;
    
    NSError *error = nil;
    
    NSURLResponse *response;
    
    NSString *url = @"http://authie.me/api/handle";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];

    NSData *localData = nil;
    
    if(error == nil) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        //send the request and get the response
        localData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSError *deserialize_error = nil;
        
        id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingAllowFragments error:&deserialize_error];
        
        id inner_object = [object objectAtIndex:0];

        if([inner_object isKindOfClass:[NSDictionary class]] && deserialize_error == nil) {

            NSLog(@"results from getHandleInformation: %@", object);
            
            NSInteger active_result;
            active_result = [[inner_object objectForKey:@"active"] integerValue];
            
            NSInteger id_result;
            id_result = [[inner_object objectForKey:@"id"] integerValue];
            
            //NSString *privateKey;
            //privateKey = [inner_object objectForKey:@"privateKey"];
            
            NSString *publicKey;
            publicKey = [inner_object objectForKey:@"publicKey"];
            
            NSString *name;
            name = [inner_object objectForKey:@"name"];
            
            NSString *userGuid;
            userGuid = [inner_object objectForKey:@"userGuid"];
            
            if(active_result == 1) {
                got = YES;
                [self.authie setRegistered:1];
                
                self.authie.handle = [[RODHandle alloc] init];
                
                [self.authie.handle setId:[NSNumber numberWithInteger:id_result]];
                [self.authie.handle setName:name];
                [self.authie.handle setActive:[NSNumber numberWithInteger:active_result]];
                [self.authie.handle setUserGuid:userGuid];
                //[self.authie.handle setPrivateKey:privateKey];
                [self.authie.handle setPublicKey:publicKey];
                
                NSLog(@"id: %lu, privateKey: %@, publicKey: %@", [self.authie.handle.id longValue], self.authie.privateKey, self.authie.handle.publicKey);
                
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                [appDelegate.masterViewController.navigationController popToRootViewControllerAnimated:YES];
                
                [self saveChanges];
                
                [self loadThreads];
                [self loadContacts];
                
            } else {
                got = NO;
                NSLog(@"bad result: %@", object);
                
            }

            
        } else {
            NSLog(@"bad result: %@", object);
        }
        
    }
    
    
    return got;
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
        
        
        if(localData != nil) {

            id object = [NSJSONSerialization JSONObjectWithData:localData options:NSJSONReadingAllowFragments error:&deserialize_error];
            if([object isKindOfClass:[NSDictionary class]] && deserialize_error == nil) {
                
                NSLog(@"results from postfile: %@", object);
                
                [self loadThreads];
                upload_success = YES;
                
            }
            
        } else {
            NSLog(@"uploadSnap timed out.");
        }
        
    }
    
    NSLog(@".. and we done");
    
    return upload_success;
}

- (BOOL)startThread:(NSString *)toHandle forKey:(NSString *)key withCaption:(NSString *)caption;
{
    
    BOOL start_convo_success = NO;
    
	// Create a new letter and POST it to the server
        
    NSDictionary *checkDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                               toHandle, @"toGuid",
                               key, @"groupKey",
                               caption, @"caption",
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
                //[self loadThreads];
                
                
            }
            
        }
        
    }
    
    return start_convo_success;
}

- (BOOL)addContact:(NSString *)handle
{
    NSLog(@"Add contact: %@", handle);
    
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

                RODHandle *new_contact = [[RODHandle alloc] init];
                new_contact.publicKey = [object objectForKey:@"message"];
                new_contact.name = handle;
                
                // okay, now we show create screen
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                                            
                [appDelegate.contactsViewController setSelected:new_contact];
            
                [appDelegate.contactsViewController showAuthorizationRequestImagePicker];
                
                
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


- (void) authorizeContact:(NSString *)publicKey;
{
    NSLog(@"authorizeContact: %@", publicKey);
    
    NSError *error = nil;
    
    NSMutableData *data = [NSMutableData data];
    [data appendData:[[NSString stringWithFormat:@"=%@", publicKey] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = @"http://authie.me/api/authorize";
    
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
            
            NSLog(@"results from authorizeContact: %@", object);
            
            NSInteger result = [[object objectForKey:@"result"] integerValue];
            
            if(result == 1) {

                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                [appDelegate.masterViewController.navigationController popToRootViewControllerAnimated:YES];
                
                [self loadThreads];
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
    
}

- (BOOL)loadContacts
{
    
    BOOL loaded_contacts = NO;
    
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
                
                RODHandle *followeeHandle = [[RODHandle alloc] init];
                
                NSDictionary *from_result = [result objectForKey:@"followeeHandle"];
                
                followeeHandle.name = [from_result objectForKey:@"name"];
                followeeHandle.publicKey = [from_result objectForKey:@"publicKey"];
                
                [self.authie.allContacts addObject:followeeHandle];
                
            }

            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate.contactsViewController.tableView reloadData];
            [appDelegate.contactsViewController.refreshControl endRefreshing];
                        
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
                
                //NSLog(@"loadThreads: %@", result);
                NSInteger id_result = [[result objectForKey:@"id"] integerValue];
                
                // replace them with the new ones
                RODThread *thready = [[RODThread alloc] init];
                thready.id = [NSNumber numberWithInteger:id_result];
                
                NSDictionary *inner_result = [result objectForKey:@"toHandle"];
                NSString *to_result = [inner_result objectForKey:@"name"];
                NSString *to_publicKey = [inner_result objectForKey:@"publicKey"];
                
                NSDictionary *from_inner_result = [result objectForKey:@"fromHandle"];
                NSString *from_result = [from_inner_result objectForKey:@"name"];
                NSString *from_publicKey = [from_inner_result objectForKey:@"publicKey"];
                
                RODHandle *fromHandle = [[RODHandle alloc] init];
                fromHandle.name = from_result;
                fromHandle.publicKey = from_publicKey;
                
                thready.fromHandle = fromHandle;
                
                RODHandle *toHandle = [[RODHandle alloc] init];
                toHandle.name = to_result;
                toHandle.publicKey = to_publicKey;
                
                thready.toHandle = toHandle;
                
                thready.groupKey = [result objectForKey:@"groupKey"];
                thready.toHandleId = to_result;
                thready.fromHandleId = from_result;
                
                NSString *caption_result = [result objectForKey:@"caption"];
                thready.caption = caption_result;
                
                NSInteger hearts = [[result objectForKey:@"hearts"] integerValue];
                NSInteger authorizeRequest = [[result objectForKey:@"authorizeRequest"] integerValue];
                
                id toHandleSeen_result = [result objectForKey:@"toHandleSeen"];
                if(toHandleSeen_result == [NSNull null]) {
                    thready.toHandleSeen = 0;
                } else {
                    thready.toHandleSeen = [NSNumber numberWithInteger:[toHandleSeen_result integerValue]];
                }
                
                
                thready.hearts = [NSNumber numberWithInteger:hearts];
                thready.authorizeRequest = [NSNumber numberWithInteger:authorizeRequest];
                
                NSString *silly_date = [result objectForKey:@"startDate"];
                NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
                
                //The Z at the end of your string represents Zulu which is UTC
                [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
                [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
                
                thready.startDate = [dateFormatter dateFromString:silly_date];
                
                [self.authie.allThreads addObject:thready];
                
            }
            
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate.masterViewController.tableView reloadData];
            [appDelegate.masterViewController.refreshControl endRefreshing];
            
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
                
                NSString *caption_result = [result objectForKey:@"caption"];
                thready.caption = caption_result;
                
                NSInteger hearts = [[result objectForKey:@"hearts"] integerValue];
                NSInteger authorizeRequest = [[result objectForKey:@"authorizeRequest"] integerValue];
                
                id toHandleSeen_result = [result objectForKey:@"toHandleSeen"];
                if(toHandleSeen_result == [NSNull null]) {
                    thready.toHandleSeen = 0;
                } else {
                    thready.toHandleSeen = [NSNumber numberWithInteger:[toHandleSeen_result integerValue]];
                }
                
                thready.hearts = [NSNumber numberWithInteger:hearts];
                thready.authorizeRequest = [NSNumber numberWithInteger:authorizeRequest];
                                
                thready.groupKey = [result objectForKey:@"groupKey"];
                thready.toHandleId = to_result;
                thready.fromHandleId = from_result;

                NSString *silly_date = [result objectForKey:@"startDate"];
                NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
                
                //The Z at the end of your string represents Zulu which is UTC
                [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
                [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
                
                thready.startDate = [dateFormatter dateFromString:silly_date];                
                
                [self.loadedThreadsFromAuthor addObject:thready];
                
                [[RODImageStore sharedStore] downloadImage:thready.groupKey];
                                
            }
            
            loaded_threads = YES;
            
        } else {
            NSLog(@"Not that kind of object: %@, deserialize_error: %@", object, deserialize_error);
        }
        
    }
        
    return loaded_threads;
}

- (void)loadDaily
{
    
    NSError *error = nil;
    
    NSURLResponse *response;
    NSData *localData = nil;
    
    NSString *url = [NSString stringWithFormat:@"http://authie.me/api/daily"];
    
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
            [self.dailyThreads removeAllObjects];
            
            for (NSDictionary *result in object) {
                
                NSLog(@"the daily: %@", result);
                
                NSInteger id_result = [[result objectForKey:@"id"] integerValue];
                
                // replace them with the new ones
                RODThread *thready = [[RODThread alloc] init];
                thready.id = [NSNumber numberWithInteger:id_result];
                
                NSDictionary *inner_result = [result objectForKey:@"toHandle"];
                NSString *to_result = [inner_result objectForKey:@"name"];
                
                NSDictionary *from_inner_result = [result objectForKey:@"fromHandle"];
                NSString *from_result = [NSString stringWithFormat:@"from: %@",[from_inner_result objectForKey:@"name"]];
                
                NSString *caption_result = [result objectForKey:@"caption"];
                thready.caption = caption_result;
                
                NSInteger hearts = [[result objectForKey:@"hearts"] integerValue];
                NSInteger authorizeRequest = [[result objectForKey:@"authorizeRequest"] integerValue];
                
                id toHandleSeen_result = [result objectForKey:@"toHandleSeen"];
                if(toHandleSeen_result == [NSNull null]) {
                    thready.toHandleSeen = 0;
                } else {
                    thready.toHandleSeen = [NSNumber numberWithInteger:[toHandleSeen_result integerValue]];
                }
                
                thready.hearts = [NSNumber numberWithInteger:hearts];
                thready.authorizeRequest = [NSNumber numberWithInteger:authorizeRequest];
                
                thready.groupKey = [result objectForKey:@"groupKey"];
                thready.toHandleId = to_result;
                thready.fromHandleId = from_result;
                
                NSString *silly_date = [result objectForKey:@"startDate"];
                NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
                
                //The Z at the end of your string represents Zulu which is UTC
                [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
                [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
                
                thready.startDate = [dateFormatter dateFromString:silly_date];
                
                [self.dailyThreads addObject:thready];
                
                //[[RODImageStore sharedStore] downloadImage:thready.groupKey];
                
            }            
            
        } else {
            NSLog(@"Not that kind of object: %@, deserialize_error: %@", object, deserialize_error);
        }
        
    }
    
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
                
                [self.authie setPrivateKey:privateKey];
                
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

-(UIView *)generateDailyView
{
    UIView *holder = [[UIView alloc] init];
    [holder setFrame:CGRectMake(0, 0, 100, 35)];
    
    UIImage *image = [UIImage imageNamed:@"authie-logo-07-350px"];
    UIImageView *imageview = [[UIImageView alloc] initWithImage:image];
    [imageview setFrame:CGRectMake(0, 2, 100, 18)];
    [imageview setContentMode:UIViewContentModeScaleAspectFit];
    
    [holder addSubview:imageview];
    
    UILabel *handleLabel = [[UILabel alloc] init];
    handleLabel.text = @"today's prompt: post cats";
    [handleLabel setFont:[UIFont systemFontOfSize:10]];
    [handleLabel setFrame:CGRectMake(0, 22, 100, 10)];
    [handleLabel setTextAlignment:NSTextAlignmentCenter];
    
    [holder addSubview:handleLabel];
    
    return holder;
}

-(UIView *)generateHeaderView
{
    UIView *holder = [[UIView alloc] init];
    [holder setFrame:CGRectMake(0, 0, 100, 35)];
    
    UIImage *image = [UIImage imageNamed:@"authie-logo-07-350px"];
    UIImageView *imageview = [[UIImageView alloc] initWithImage:image];
    [imageview setFrame:CGRectMake(0, 2, 100, 18)];
    [imageview setContentMode:UIViewContentModeScaleAspectFit];
    
    [holder addSubview:imageview];
    
    UILabel *handleLabel = [[UILabel alloc] init];
    handleLabel.text = [RODItemStore sharedStore].authie.handle.name;
    [handleLabel setFont:[UIFont systemFontOfSize:10]];
    [handleLabel setFrame:CGRectMake(0, 22, 100, 10)];
    [handleLabel setTextAlignment:NSTextAlignmentCenter];
    
    [holder addSubview:handleLabel];
    
    return holder;
}

- (UIBarButtonItem *)generateSettingsCog:(UIViewController *)target
{
    UIButton *button_menu = [UIButton buttonWithType:UIButtonTypeCustom];
    [button_menu setFrame:CGRectMake(0, 0, 40, 40)];
    [button_menu setImage:[UIImage imageNamed:@"cog-black.png"] forState:UIControlStateNormal];
    [button_menu addTarget:target.navigationController action:@selector(showMenu:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *leftDrawerButton = [[UIBarButtonItem alloc] initWithCustomView:button_menu];

    return leftDrawerButton;
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
