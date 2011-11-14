// Mac OS X 10.6 or higher only.
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#import <CoreFoundation/CFBase.h>
#import <Foundation/NSObject.h>

void CFAllocatorDefaultDoubleFree() {
  void *mem =  CFAllocatorAllocate(kCFAllocatorDefault, 5, 0);
  CFAllocatorDeallocate(kCFAllocatorDefault, mem);
  CFAllocatorDeallocate(kCFAllocatorDefault, mem);
}

void CFAllocatorSystemDefaultDoubleFree() {
  void *mem =  CFAllocatorAllocate(kCFAllocatorSystemDefault, 5, 0);
  CFAllocatorDeallocate(kCFAllocatorSystemDefault, mem);
  CFAllocatorDeallocate(kCFAllocatorSystemDefault, mem);
}

void CFAllocatorMallocDoubleFree() {
  void *mem =  CFAllocatorAllocate(kCFAllocatorMalloc, 5, 0);
  CFAllocatorDeallocate(kCFAllocatorMalloc, mem);
  CFAllocatorDeallocate(kCFAllocatorMalloc, mem);
}

void CFAllocatorMallocZoneDoubleFree() {
  void *mem =  CFAllocatorAllocate(kCFAllocatorMallocZone, 5, 0);
  CFAllocatorDeallocate(kCFAllocatorMallocZone, mem);
  CFAllocatorDeallocate(kCFAllocatorMallocZone, mem);
}


// Test the +load instrumentation.
// Because the +load methods are invoked before anything else is initialized,
// it makes little sense to wrap the code below into a gTest test case.
// If AddressSanitizer doesn't instrument the +load method below correctly,
// everything will just crash.

char kStartupStr[] =
    "If your test didn't crash, AddressSanitizer is instrumenting "
    "the +load methods correctly.";

@interface LoadSomething : NSObject {
}
@end

@implementation LoadSomething

+(void) load {
  for (int i = 0; i < strlen(kStartupStr); i++) {
    volatile char ch = kStartupStr[i];  // make sure no optimizations occur.
  }
  // Don't print anything here not to interfere with the death tests.
}

@end

void worker_do_alloc(int size) {
  char *mem = malloc(size);
  mem[0] = 0; // Ok
  free(mem);
}

void worker_do_crash(int size) {
  char *mem = malloc(size);
  mem[size] = 0;  // BOOM
  free(mem);
}

// Test the Grand Central Dispatch. See
// http://developer.apple.com/library/mac/#documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html
// for the reference.
void TestGCDRunBlock() {
  dispatch_queue_t queue = dispatch_get_global_queue(0,0);
  dispatch_block_t block = ^{ worker_do_crash(1024); };
  // dispatch_async() runs the task on a worker thread that does not go through
  // pthread_create(). We need to verify that AddressSanitizer notices that the
  // thread has started.
  dispatch_async(queue, block);
  // TODO(glider): this is hacky. Need to wait for the worker instead.
  sleep(1);
}

// libdispatch spawns a rather small number of threads and reuses them. We need
// to make sure AddressSanitizer handles the reusing correctly.
void TestGCDReuseWqthreads() {
  dispatch_queue_t queue = dispatch_get_global_queue(0,0);
  dispatch_block_t block_alloc = ^{ worker_do_alloc(1024); };
  dispatch_block_t block_crash = ^{ worker_do_crash(1024); };
  for (int i = 0; i < 100; i++) {
    dispatch_async(queue, block_alloc);
  }
  dispatch_async(queue, block_crash);
  // TODO(glider): this is hacky. Need to wait for the workers instead.
  sleep(1);
}

void TestGCDDispatchAfter() {
  dispatch_queue_t queue = dispatch_get_global_queue(0,0);
  dispatch_block_t block_crash = ^{ worker_do_crash(1024); };
  // Schedule the event one second from the current time.
  dispatch_time_t milestone =
      dispatch_time(DISPATCH_TIME_NOW, 1LL * NSEC_PER_SEC);
  dispatch_after(milestone, queue, block_crash);
  // Let's wait for a bit longer now.
  // TODO(glider): this is still hacky.
  sleep(2);
}