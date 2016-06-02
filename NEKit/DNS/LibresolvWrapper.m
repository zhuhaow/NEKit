#import <resolv.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import "LibresolvWrapper.h"

@implementation LibresolvWrapper
+ (nonnull NSArray<NSString *> *) fetchDNSServers {
    NSMutableArray *result = [NSMutableArray array];
    
    res_state res = malloc(sizeof(struct __res_state));
    
    if ( res_ninit(res) == 0 )
    {
        for ( int i = 0; i < res->nscount; i++ )
        {
            char *rep = inet_ntoa(res->nsaddr_list[i].sin_addr);
            NSString *s = [NSString stringWithUTF8String: rep];
            free(rep);
            [result addObject: s];
        }
    }
    
    free(res);
    return result;
}
@end
