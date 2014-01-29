# Copyright 2013 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This file is a part of AddressSanitizer, an address sanity checker.

ifeq ($(PLATFORM), )
	PLATFORM=$(shell uname -s | sed -e "s/CYGWIN.*/Windows/" | sed -e "s/Darwin/Mac/")
endif

ifeq ($(PLATFORM), Windows)
	# TODO(timurrrr): auto-adjust when using `clang -fsanitize=address`?
	# Currently, I run
	# make CC=clang.exe CC_OUT="-c -o" CFLAGS=-fsanitize=address EXTRA_OBJ=<path_to_rtl>/asan_rtl.lib -j
	CC=cl
	CFLAGS=-TP -Zi -nologo
	CC_DLL=-LD
	CC_DLL_OUT=-Fe
	CC_EXE_OUT=-Fe
	LINK=link
	LINK_FLAGS=-debug -nologo -incremental:no
	LINK_OUT=-out:
else ifeq ($(PLATFORM), Linux)
	# TODO(timurrrr): auto-adjust when using `clang -fsanitize=address`?
	# Currently, I run
	# make CC=clang CFLAGS=-faddress-sanitizer EXTRA_OBJ="<path_to_rtl>/libasan64.so -lpthread -ldl" -j
	CC=g++
	CFLAGS=-g
	CC_DLL=
	CC_DLL_OUT=-o
	CC_EXE_OUT=-o
	LINK=g++
	LINK_FLAGS=
	LINK_OUT=-o
endif
UAR_ENV=ASAN_OPTIONS=detect_stack_use_after_return=1
EXTRA_CFLAGS=
FILECHECK=
RM_F=rm -f

run_all_tests: $(RUN_TEST_TARGETS)
	@echo "========================================"
	@echo "ALL TESTS PASSED!"
	@echo "Please note that the crash reports above are expected, e.g. glibc printing to tty"
	@echo "Cleaning up..."
.PHONY: run_all_tests

clean:
	$(RM_F) *.exe *.dll *.obj *.obj-* *.o *.o-* *.pdb *.ilk *.exe.manifest *.exp *.lib *.suo *.output
.PHONY: clean

######### Utility macros

run_%_crash_test: %_crash_test.output
	@cat $^
	@echo "$< - CRASHED AS EXPECTED"

check_%_crash_test: %_crash_test.output %_crash.cpp
	@$(FILECHECK) -input-file=$^
	@echo "$< - PASSED (CRASHED WITH THE CORRECT OUTPUT)"

check_%_pass_test: run_%_pass_test
	@echo "$< - PASSED"

.PHONY: run_%_test
