//
//  BBCExceptionHandler.m

#import "include/BBCExceptionHandler.h"
@import Foundation;

@implementation BBCExceptionHandler

+ (BOOL)tryBlock:(void (^)(void))tryBlock error:(NSError **)error {
    
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        if (error) {
            NSMutableDictionary *userInfo = [exception.userInfo mutableCopy] ?: [NSMutableDictionary new];
            userInfo[@"NSExceptionName"] = exception.name;
            *error = [NSError errorWithDomain:@"BBCExceptionHandlerDomain" code:-1 userInfo:userInfo];
        }
        return NO;
    }

    return YES;
}

@end

@implementation NSError (BBCExceptionHandler)

- (NSExceptionName)exceptionName {
    return self.userInfo[@"NSExceptionName"];
}

@end
