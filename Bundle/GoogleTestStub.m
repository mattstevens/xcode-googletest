#import "GoogleTestStub.h"

@implementation GoogleTestStub {
    NSString *_name;
    unsigned int _count;
}

- (id)initWithName:(NSString *)name testCaseCount:(unsigned int)count {
    self = [super init];
    if (self) {
        _name = [name copy];
        _count = count;
    }

    return self;
}

+ (instancetype)testCaseStubWithName:(NSString *)name suite:(NSString *)suiteName {
    NSString *senTestCompatibleName = [NSString stringWithFormat:@"-[%@ %@]", suiteName, name];
    return [[self alloc] initWithName:senTestCompatibleName testCaseCount:1];
}

+ (instancetype)testSuiteStubWithName:(NSString *)name testCaseCount:(unsigned int)count {
    return [[self alloc] initWithName:name testCaseCount:count];
}

- (NSString *)name {
    return _name;
}

- (unsigned int)testCaseCount {
    return _count;
}

- (NSString *)description {
    return [self name];
}

@end
