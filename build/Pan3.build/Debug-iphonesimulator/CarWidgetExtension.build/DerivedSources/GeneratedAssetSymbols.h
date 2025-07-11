#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "my_car" asset catalog image resource.
static NSString * const ACImageNameMyCar AC_SWIFT_PRIVATE = @"my_car";

#undef AC_SWIFT_PRIVATE
