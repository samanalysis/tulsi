// Copyright 2016 The Tulsi Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest
@testable import TulsiGenerator


// Tests for the tulsi_sources_aspect aspect.
class TulsiSourcesAspectTests: BazelIntegrationTestCase {
  var aspectWorkspaceInfoExtractor: BazelAspectWorkspaceInfoExtractor! = nil

  override func setUp() {
    super.setUp()
    aspectWorkspaceInfoExtractor = BazelAspectWorkspaceInfoExtractor(bazelURL: bazelURL,
                                                                     workspaceRootURL: workspaceRootURL!,
                                                                     packagePathFetcher: packagePathFetcher,
                                                                     localizedMessageLogger: localizedMessageLogger,
                                                                     bazelStartupOptions: bazelStartupOptions,
                                                                     bazelBuildOptions: bazelBuildOptions)
  }

  func testSimple() {
    installBUILDFile("Simple", inSubdirectory: "tulsi_test")
    let applicationRuleEntry = RuleEntry(label: "//tulsi_test:Application", type: "ios_application")
    let testRuleEntry = RuleEntry(label: "//tulsi_test:XCTest", type: "ios_test")

    let ruleEntries = aspectWorkspaceInfoExtractor.extractInfoForTargetRules([applicationRuleEntry,
                                                                             testRuleEntry])
    XCTAssertEqual(ruleEntries.count, 4)

    let checker = InfoChecker(ruleEntries: ruleEntries)

    checker.assertThat("//tulsi_test:Application")
        .dependsOn("//tulsi_test:Binary")

    checker.assertThat("//tulsi_test:Binary")
        .dependsOn("//tulsi_test:Library")
        .hasSources(["tulsi_test/main.m"])

    checker.assertThat("//tulsi_test:Library")
        .hasSources(["tulsi_test/path/to/src1.m",
                     "tulsi_test/path/to/src2.m",
                     "tulsi_test/path/to/src3.m",
                     "tulsi_test/path/to/src4.m",
                        ])

    checker.assertThat("//tulsi_test:XCTest")
        .dependsOn("//tulsi_test:Library")
        .hasTestHost("//tulsi_test:Application")
        .hasSources(["tulsi_test/test/src1.mm"])
  }


  private class InfoChecker {
    let ruleEntries: [BuildLabel: RuleEntry]

    init(ruleEntries: [RuleEntry]) {
      var map = [BuildLabel: RuleEntry]()
      for entry in ruleEntries {
        map[entry.label] = entry
      }
      self.ruleEntries = map
    }

    func assertThat(targetLabel: String, line: UInt = __LINE__) -> Context {
      let ruleEntry = ruleEntries[BuildLabel(targetLabel)]
      XCTAssertNotNil(ruleEntry,
                      "No rule entry with the label \(targetLabel) was found",
                      line: line)

      return Context(ruleEntry: ruleEntry, ruleEntries: ruleEntries)
    }

    /// Context allowing checks against a single rule entry instance.
    class Context {
      let ruleEntry: RuleEntry?
      let ruleEntries: [BuildLabel: RuleEntry]

      init(ruleEntry: RuleEntry?, ruleEntries: [BuildLabel: RuleEntry]) {
        self.ruleEntry = ruleEntry
        self.ruleEntries = ruleEntries
      }

      // Does nothing as "assertThat" already asserted the existence of the associated ruleEntry.
      func exists() -> Context {
        return self
      }

      /// Asserts that the contextual RuleEntry is linked to a rule identified by the given
      /// targetLabel as a dependency.
      func dependsOn(targetLabel: String, line: UInt = __LINE__) -> Context {
        guard let ruleEntry = ruleEntry else { return self }
        XCTAssertNotNil(ruleEntry.dependencies[targetLabel],
                        "\(ruleEntry) must depend on \(targetLabel)",
                        line: line)
        return self
      }

      /// Asserts that the contextual RuleEntry contains the given list of sources (but may have
      /// others as well).
      func containsSources(sources: [String], line: UInt = __LINE__) -> Context {
        guard let ruleEntry = ruleEntry else { return self }
        for s in sources {
          XCTAssert(ruleEntry.sourceFiles.contains(s),
                    "\(ruleEntry) missing expected source file '\(s)'",
                    line: line)
        }
        return self
      }

      /// Asserts that the contextual RuleEntry has exactly the given list of sources.
      func hasSources(sources: [String], line: UInt = __LINE__) -> Context {
        guard let ruleEntry = ruleEntry else { return self }
        containsSources(sources, line: line)
        XCTAssertEqual(ruleEntry.sourceFiles.count,
                       sources.count,
                       "\(ruleEntry) expected to have exactly \(sources.count) source files but has \(ruleEntry.sourceFiles.count)",
                       line: line)
        return self
      }

      /// Asserts that the contextual RuleEntry is an ios_test with an xctest_app identified by the
      /// given label.
      func hasTestHost(targetLabel: String, line: UInt = __LINE__) -> Context {
        guard let ruleEntry = ruleEntry else { return self }
        let hostLabelString = ruleEntry.attributes["xctest_app"]
        XCTAssertEqual(hostLabelString,
                       targetLabel,
                       "\(ruleEntry) expected to have an xctest_app of \(targetLabel)",
                       line: line)
        return self
      }
    }
  }
}