//
//  BBCExceptionHandler.h

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

/**
 `ExceptionHandler` is a work around for Swift not supporting exception handling. There are cases
 (such as out-of-memory) when it is desirable to exit a function gracefully rather than crashing
 the app. This class allows for writing Swift methods that convert the `NSException` to an
 `NSError`.
 */
NS_SWIFT_NAME(ExceptionHandler)
@interface BBCExceptionHandler : NSObject

+ (BOOL)tryBlock:(void (^)(void))tryBlock error:(NSError * __autoreleasing *)error;

@end

@interface NSError (BBCExceptionHandler)

- (NSExceptionName _Nullable)exceptionName;

@end

NS_ASSUME_NONNULL_END
