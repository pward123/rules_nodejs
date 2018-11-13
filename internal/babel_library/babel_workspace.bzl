# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"Install babel toolchain dependencies"

# load("@build_bazel_rules_nodejs//:defs.bzl", "check_bazel_version", "check_rules_nodejs_version", "yarn_install")
# load("@bazel_gazelle//:deps.bzl", "go_repository")
load("//internal/npm_install:npm_install.bzl", "npm_install", "yarn_install")
load("//internal/common:check_bazel_version.bzl", "check_bazel_version")
load("//:package.bzl", "check_rules_nodejs_version")

def babel_setup_workspace():
    """This repository rule should be called from your WORKSPACE file.

    It installs dependencies needed for the babel_library rule.
    """

    # 0.14.0: @bazel_tools//tools/bash/runfiles is required
    # 0.15.0: "data" attributes don't need 'cfg = "data"'
    # 0.17.1: allow @ in package names is required for fine grained deps
    check_bazel_version("0.17.1")

    # go_repository(
    #     name = "com_github_kylelemons_godebug",
    #     commit = "d65d576e9348f5982d7f6d83682b694e731a45c6",
    #     importpath = "github.com/kylelemons/godebug",
    # )
    #
    # go_repository(
    #     name = "com_github_mattn_go_isatty",
    #     commit = "3fb116b820352b7f0c281308a4d6250c22d94e27",
    #     importpath = "github.com/mattn/go-isatty",
    # )

    # 0.11.3: node module resolution fixes & check_rules_nodejs_version
    # 0.14.0: fine grained npm dependencies support for ts_library
    # 0.14.1: fine grained npm dependencies fix for npm_install
    # 0.15.0: fine grained npm dependencies breaking change
    check_rules_nodejs_version("0.15.0")

    # yarn has a bug with installing local packages that are symlinked so use npm
    # See https://github.com/yarnpkg/yarn/issues/6037
    npm_install(
        name = "build_bazel_rules_nodejs_babel_deps",
        # package_json = "@devserver_example//:package.json",
        package_json = "//my-es6-lib:package.json",
        data = [
            "@build_bazel_rules_nodejs//internal/babel_library:package.json",
            "@build_bazel_rules_nodejs//internal/babel_library:babel.js",
            "@build_bazel_rules_nodejs//internal/babel_library:yarn.lock",
        ],
    )

    # # Included here for backward compatability for downstream repositories
    # # that use @build_bazel_rules_typescript_tsc_wrapped_deps such as rxjs.
    # # @build_bazel_rules_typescript_tsc_wrapped_deps is not used locally.
    # yarn_install(
    #     name = "build_bazel_rules_typescript_tsc_wrapped_deps",
    #     package_json = "@build_bazel_rules_typescript//internal:tsc_wrapped/package.json",
    #     yarn_lock = "@build_bazel_rules_typescript//internal:tsc_wrapped/yarn.lock",
    # )
    #
    # yarn_install(
    #     name = "build_bazel_rules_typescript_devserver_deps",
    #     package_json = "@build_bazel_rules_typescript//internal/devserver:package.json",
    #     yarn_lock = "@build_bazel_rules_typescript//internal/devserver:yarn.lock",
    # )
    #
    # yarn_install(
    #     name = "build_bazel_rules_typescript_protobufs_compiletime_deps",
    #     package_json = "@build_bazel_rules_typescript//internal/protobufjs:package.json",
    #     yarn_lock = "@build_bazel_rules_typescript//internal/protobufjs:yarn.lock",
    # )
