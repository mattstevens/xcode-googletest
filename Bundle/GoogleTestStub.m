/*
 * Copyright (c) 2013 Matthew Stevens
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

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
    NSString *xcTestCompatibleName = [self XCTestNameForSuiteName:suiteName testCaseName:name];
    return [[self alloc] initWithName:xcTestCompatibleName testCaseCount:1];
}

+ (instancetype)testSuiteStubWithName:(NSString *)name testCaseCount:(NSUInteger)count {
    return [[self alloc] initWithName:name testCaseCount:count];
}

+ (NSString *)XCTestNameForSuiteName:(NSString *)suiteName testCaseName:(NSString *)name {
    return [NSString stringWithFormat:@"-[%@ %@]", suiteName, name];
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
