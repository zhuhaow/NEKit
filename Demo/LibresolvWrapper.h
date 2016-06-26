#import <Foundation/Foundation.h>

// TODO: Current workaround should be fixed. This class should never be exposed. We have to define a module.
@interface LibresolvWrapper : NSObject
+ (nonnull NSArray<NSString *> *) fetchDNSServers;
@end
