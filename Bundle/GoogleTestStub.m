#import "GoogleTestStub.h"

/**
 * A stub XCTest that simply returns the data provided in its initializer.
 */
@implementation GoogleTestStub {
    NSString *_name;
    NSUInteger _count;
}

- (id)initWithName:(NSString *)name testCaseCount:(NSUInteger)count {
    self = [super init];
    if (self) {
        _name = [name copy];
        _count = count;
    }

    return self;
}

+ (instancetype)testCaseStubWithName:(NSString *)name suite:(NSString *)suiteName {
    NSString *xcTestCompatibleName = [NSString stringWithFormat:@"-[%@ %@]", suiteName, name];
    return [[self alloc] initWithName:xcTestCompatibleName testCaseCount:1];
}

+ (instancetype)testSuiteStubWithName:(NSString *)name testCaseCount:(NSUInteger)count {
    return [[self alloc] initWithName:name testCaseCount:count];
}

- (NSString *)name {
    return _name;
}

- (NSUInteger)testCaseCount {
    return _count;
}

- (NSString *)description {
    return [self name];
}

@end
