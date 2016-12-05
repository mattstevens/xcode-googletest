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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <gtest/gtest.h>
#import <objc/runtime.h>

using testing::TestCase;
using testing::TestInfo;
using testing::TestPartResult;
using testing::UnitTest;

static NSString * const GoogleTestDisabledPrefix = @"DISABLED_";

/**
 * Class prefix used for generated Objective-C class names.
 *
 * If a class name generated for a Google Test case conflicts with an existing
 * class the value of this variable can be changed to add a class prefix.
 */
static NSString * const GeneratedClassPrefix = @"";

/**
 * A Google Test listener that reports failures to XCTest.
 */
class XCTestListener : public testing::EmptyTestEventListener {
public:
    XCTestListener(XCTestCase *testCase) :
        _testCase(testCase) {}

    void OnTestPartResult(const TestPartResult& test_part_result) {
        if (test_part_result.passed())
            return;

        int lineNumber = test_part_result.line_number();
        const char *fileName = test_part_result.file_name();
        NSString *path = fileName ? [@(fileName) stringByStandardizingPath] : nil;
        NSString *description = @(test_part_result.message());
        [_testCase recordFailureWithDescription:description
                                         inFile:path
                                         atLine:(lineNumber >= 0 ? (NSUInteger)lineNumber : 0)
                                       expected:YES];
    }

private:
    XCTestCase *_testCase;
};

/**
 * Base class for the generated classes for Google Test cases.
 */
@interface GoogleTestCase : XCTestCase
@end

@implementation GoogleTestCase
@end

/**
 * Runs a single test.
 */
static void RunTest(id self, NSString *testFilter) {
    XCTestListener *listener = new XCTestListener(self);
    UnitTest *googleTest = UnitTest::GetInstance();
    googleTest->listeners().Append(listener);

    testing::GTEST_FLAG(filter) = [testFilter UTF8String];

    (void)RUN_ALL_TESTS();

    delete googleTest->listeners().Release(listener);

    int totalTestsRun = googleTest->successful_test_count() + googleTest->failed_test_count();
    XCTAssertEqual(totalTestsRun, 1, @"Expected to run a single test for filter \"%@\"", testFilter);
}

/**
 * Test suite for the entire set of gtests.  Finds all registered tests and adds them to itself.
 */
@interface GoogleTestSuite : XCTestSuite
@end

@implementation GoogleTestSuite

- (instancetype)init
{
    if (self = [self initWithName:@"GoogleTestSuite"]) {
        // Pass the command-line arguments to Google Test to support the --gtest options
        NSArray *arguments = [[NSProcessInfo processInfo] arguments];

        int i = 0;
        int argc = (int)[arguments count];
        const char **argv = (const char **)calloc((unsigned int)argc + 1, sizeof(const char *));
        for (NSString *arg in arguments) {
            argv[i++] = [arg UTF8String];
        }

        testing::InitGoogleTest(&argc, (char **)argv);
        UnitTest *googleTest = UnitTest::GetInstance();
        testing::TestEventListeners& listeners = googleTest->listeners();
        delete listeners.Release(listeners.default_result_printer());
        free(argv);

        BOOL runDisabledTests = testing::GTEST_FLAG(also_run_disabled_tests);
        NSCharacterSet *decimalDigitCharacterSet = [NSCharacterSet decimalDigitCharacterSet];

        for (int testCaseIndex = 0; testCaseIndex < googleTest->total_test_case_count(); testCaseIndex++) {
            const TestCase *testCase = googleTest->GetTestCase(testCaseIndex);
            NSString *testCaseName = @(testCase->name());

            // For typed tests '/' is used to separate the parts of the test case name.
            NSArray *testCaseNameComponents = [testCaseName componentsSeparatedByString:@"/"];

            if (runDisabledTests == NO) {
                BOOL testCaseDisabled = NO;

                for (NSString *component in testCaseNameComponents) {
                    if ([component hasPrefix:GoogleTestDisabledPrefix]) {
                        testCaseDisabled = YES;
                        break;
                    }
                }

                if (testCaseDisabled) {
                    continue;
                }
            }

            // Join the test case name components with '_' rather than '/' to create
            // a valid class name.
            NSString *className = [GeneratedClassPrefix stringByAppendingString:[testCaseNameComponents componentsJoinedByString:@"_"]];

            Class testClass = objc_allocateClassPair([GoogleTestCase class], [className UTF8String], 0);
            NSAssert1(testClass, @"Failed to register Google Test class \"%@\", this class may already exist. The value of GeneratedClassPrefix can be changed to avoid this.", className);
            std::vector<SEL> selectors;

            for (int testIndex = 0; testIndex < testCase->total_test_count(); testIndex++) {
                const TestInfo *testInfo = testCase->GetTestInfo(testIndex);
                NSString *testName = @(testInfo->name());
                if (runDisabledTests == NO && [testName hasPrefix:GoogleTestDisabledPrefix]) {
                    continue;
                }

                // Google Test allows test names starting with a digit, prefix these with an
                // underscore to create a valid method name.
                NSString *methodName = testName;
                if ([methodName length] > 0 && [decimalDigitCharacterSet characterIsMember:[methodName characterAtIndex:0]]) {
                    methodName = [@"_" stringByAppendingString:methodName];
                }

                // Google Test set test method name in parameterized tests to <name>/<index>.
                // Replace / with a _ to create a valid method name.
                methodName = [methodName stringByReplacingOccurrencesOfString:@"/" withString:@"_"];

                NSString *testFilter = [NSString stringWithFormat:@"%@.%@", testCaseName, testName];
                IMP imp = imp_implementationWithBlock(^void (id self_) { RunTest(self_, testFilter); });
                SEL selector = sel_registerName([methodName UTF8String]);
                BOOL added = class_addMethod(testClass, selector, imp, "v@:");
                NSAssert1(added, @"Failed to add Goole Test method \"%@\", this method may already exist in the class.", methodName);
                selectors.push_back(selector);
            }

            if (!selectors.empty()) {
                objc_registerClassPair(testClass);
                for (SEL s : selectors) {
                    [self addTest:[testClass testCaseWithSelector:s]];
                }
            } else {
                objc_disposeClassPair(testClass);
            }
        }
    }
    return self;
}

@end

/**
 * Test case that bootstraps the test suite containing all the gtests.
 */
@interface GoogleTests : XCTestCase
@end

@implementation GoogleTests
+ (XCTestSuite *)defaultTestSuite
{
    return [GoogleTestSuite new];
}
@end
