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

#include <cassert>
#include "TargetConditionals.h"

#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

using testing::TestCase;
using testing::TestInfo;
using testing::TestPartResult;
using testing::UnitTest;

NSString * uuidString() {
    // Returns a UUID
    
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    
    return uuidString;
}

static NSString * const GoogleTestDisabledPrefix = @"DISABLED_";

/**
 * Class prefix used for generated Objective-C class names.
 *
 * If a class name generated for a Google Test case conflicts with an existing
 * class the value of this variable can be changed to add a class prefix.
 */
static NSString * const GeneratedClassPrefix = @"";

/**
 * Map of test keys to Google Test filter strings.
 *
 * Some names allowed by Google Test would result in illegal Objective-C
 * identifiers and in such cases the generated class and method names are
 * adjusted to handle this. This map is used to obtain the original Google Test
 * filter string associated with a generated Objective-C test method.
 */
static NSDictionary *GoogleTestFilterMap;

char file_output_base[512] = {};
char output_arg[512] = {};
NSString * testFilesPath = @"";
NSString * dataDir = @"";
NSString * fullDataDir = @"";
NSString * filename = @"";

static void deleteDir( id self, NSString * path ) {
    if ( [[NSFileManager defaultManager] isReadableFileAtPath:path] ) {
        BOOL res = [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        assert((res==YES) && "Error : cant remove directory");
    }
}
static void createFreshDir( id self, NSString * path ) {
    deleteDir( self, path );
    
    BOOL isDir;
    NSFileManager *fileManager= [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:path isDirectory:&isDir]) {
        BOOL res = [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
        XCTAssertTrue(res, @"Error: Create folder failed %@", path);
    }
}

/**
 * A Google Test listener that reports failures to XCTest.
 */
class XCTestListener : public testing::EmptyTestEventListener {
public:
    XCTestListener(XCTestCase *testCase) :
        _testCase(testCase) {}

    void OnTestPartResult(const TestPartResult& test_part_result) override {
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
    
    void OnTestEnd(const TestInfo& info) override {
        last_test_case = std::string( info.test_case_name() );
        last_test = std::string( info.name() );
    }
    
    void OnTestProgramEnd( const UnitTest & unit_test ) override {
        assert( [filename length] != 0 );
        assert( !last_test_case.empty() );
        assert( !last_test.empty() );
        
        NSString * fileSrc = [NSString stringWithFormat:@"%@/%@/%@.xml", testFilesPath, dataDir, filename];
        if ( [[NSFileManager defaultManager] isReadableFileAtPath:fileSrc] ) {
            NSString * dirDst = [NSString stringWithFormat:@"%@/%s/", testFilesPath, last_test_case.c_str()];
            BOOL isDir;
            if(![[NSFileManager defaultManager]  fileExistsAtPath:dirDst isDirectory:&isDir]) {
                BOOL res = [[NSFileManager defaultManager]  createDirectoryAtPath:dirDst withIntermediateDirectories:YES attributes:nil error:NULL];
                assert((res==YES) && "Error: Create folder failed");
            }

            NSString * fileDst = [NSString stringWithFormat:@"%@%s.xml", dirDst, last_test.c_str()];
            if ( [[NSFileManager defaultManager] isReadableFileAtPath:fileDst] ) {
                BOOL res = [[NSFileManager defaultManager] removeItemAtPath:fileDst error:nil];
                assert((res==YES) && "Error : cant remove file");
            }
            
            BOOL res = [[NSFileManager defaultManager] copyItemAtPath:fileSrc toPath:fileDst error:nil];
            assert((res==YES) && "Error: copy file failed");
            
            deleteDir(0, fullDataDir);
        } else {
            assert(0);
        }
    }
private:
    XCTestCase *_testCase;
    std::string last_test_case, last_test;
};

/**
 * Registers an XCTestCase subclass for each Google Test case.
 *
 * Generating these classes allows Google Test cases to be represented as peers
 * of standard XCTest suites and supports filtering of test runs to specific
 * Google Test cases or individual tests via Xcode.
 */
@interface GoogleTestLoader : NSObject
@end

/**
 * Base class for the generated classes for Google Test cases.
 */
@interface GoogleTestCase : XCTestCase
@end

@implementation GoogleTestCase

/**
 * Associates generated Google Test classes with the test bundle.
 *
 * This affects how the generated test cases are represented in reports. By
 * associating the generated classes with a test bundle the Google Test cases
 * appear to be part of the same test bundle that this source file is compiled
 * into. Without this association they appear to be part of a bundle
 * representing the directory of an internal Xcode tool that runs the tests.
 */
+ (NSBundle *)bundleForClass {
    return [NSBundle bundleForClass:[GoogleTestLoader class]];
}

/**
 * Implementation of +[XCTestCase testInvocations] that returns an array of test
 * invocations for each test method in the class.
 *
 * This differs from the standard implementation of testInvocations, which only
 * adds methods with a prefix of "test".
 */
+ (NSArray *)testInvocations {
    NSMutableArray *invocations = [NSMutableArray array];

    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList([self class], &methodCount);

    for (unsigned int i = 0; i < methodCount; i++) {
        SEL sel = method_getName(methods[i]);
        NSMethodSignature *sig = [self instanceMethodSignatureForSelector:sel];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
        [invocation setSelector:sel];
        [invocations addObject:invocation];
    }

    free(methods);

    return invocations;
}

@end

/**
 * Runs a single test.
 */
static void RunTest(id self, SEL _cmd) {
    XCTestListener *listener = new XCTestListener(self);
    UnitTest *googleTest = UnitTest::GetInstance();
    googleTest->listeners().Append(listener);

    NSString *testKey = [NSString stringWithFormat:@"%@.%@", [self class], NSStringFromSelector(_cmd)];
    NSString *testFilter = GoogleTestFilterMap[testKey];
    XCTAssertNotNil(testFilter, @"No test filter found for test %@", testKey);
    XCTAssertNotNil(fullDataDir);
    createFreshDir( self, fullDataDir );
    
    testing::GTEST_FLAG(filter) = [testFilter UTF8String];

    (void)RUN_ALL_TESTS();

    delete googleTest->listeners().Release(listener);

    int totalTestsRun = googleTest->successful_test_count() + googleTest->failed_test_count();
    XCTAssertEqual(totalTestsRun, 1, @"Expected to run a single test for filter \"%@\"", testFilter);
}

@implementation GoogleTestLoader

/**
 * Performs registration of classes for Google Test cases after our bundle has
 * finished loading.
 *
 * This registration needs to occur before XCTest queries the runtime for test
 * subclasses, but after C++ static initializers have run so that all Google
 * Test cases have been registered. This is accomplished by synchronously
 * observing the NSBundleDidLoadNotification for our own bundle.
 */
+ (void)load {
    
#ifdef MACRO_TEST_REPORT
    snprintf(file_output_base, sizeof(file_output_base), "%s", TOSTRING(MACRO_TEST_REPORT));
    snprintf(output_arg, sizeof(output_arg), "--gtest_output=xml:%s.xml", file_output_base);
    filename = [[NSString alloc] initWithCString:file_output_base encoding:NSASCIIStringEncoding];
#else
    assert(0);
    return;
#endif

#ifdef MACRO_TEST_REPORT_DIR
    
    NSString * reportPath = @TOSTRING(MACRO_TEST_REPORT_DIR);

    NSString * platform = nil;

    // keep those in sync with the ones in build.py !
#if TARGET_OS_SIMULATOR
    platform = @"IOS.Simulator";
#else
    platform = @"OS.X";
#endif
    
    testFilesPath = [[NSString alloc] initWithFormat:@"%@/%@/unmerged/%@/", reportPath, platform, filename];

    createFreshDir( self, testFilesPath );

    dataDir = uuidString();
    fullDataDir = [[NSString alloc] initWithFormat:@"%@/%@", testFilesPath, dataDir];
    createFreshDir( self, fullDataDir );
    
    BOOL res = [[NSFileManager defaultManager] changeCurrentDirectoryPath: fullDataDir];
    NSAssert1(res, @"Failed to set current directory \"%@\"", testFilesPath);
#else
    assert(0);
    return;
#endif

    NSBundle *bundle = [NSBundle bundleForClass:self];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSBundleDidLoadNotification object:bundle queue:nil usingBlock:^(NSNotification *notification) {

        NSArray* loadedClasses = [notification.userInfo objectForKey:NSLoadedClasses];
        
        if( loadedClasses != nil ) {
            if( [loadedClasses indexOfObject:@"GoogleTestLoader"] != NSNotFound) {
                [self registerTestClasses];
            }
        }
    }];
}

+ (void)registerTestClasses {
    // Pass the command-line arguments to Google Test to support the --gtest options
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];

    int i = 0;
    int argc = (int)[arguments count];
    const char **argv = (const char **)calloc((unsigned int)argc + 2, sizeof(const char *));
    for (NSString *arg in arguments) {
        argv[i++] = [arg UTF8String];
    }
    argc++;
    argv[i++] = output_arg;

    testing::InitGoogleTest(&argc, (char **)argv);
    free(argv);

    UnitTest *googleTest = UnitTest::GetInstance();
    testing::TestEventListeners& listeners = googleTest->listeners();
    delete listeners.Release(listeners.default_result_printer());

    BOOL runDisabledTests = testing::GTEST_FLAG(also_run_disabled_tests);
    NSMutableDictionary *testFilterMap = [NSMutableDictionary dictionary];
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
        BOOL hasMethods = NO;

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

            NSString *testKey = [NSString stringWithFormat:@"%@.%@", className, methodName];
            NSString *testFilter = [NSString stringWithFormat:@"%@.%@", testCaseName, testName];
            testFilterMap[testKey] = testFilter;

            SEL selector = sel_registerName([methodName UTF8String]);
            BOOL added = class_addMethod(testClass, selector, (IMP)RunTest, "v@:");
            NSAssert1(added, @"Failed to add Google Test method \"%@\", this method may already exist in the class.", methodName);
            hasMethods = YES;
        }

        if (hasMethods) {
            objc_registerClassPair(testClass);
        } else {
            objc_disposeClassPair(testClass);
        }
    }

    GoogleTestFilterMap = testFilterMap;
}

@end
