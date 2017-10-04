# -*- coding: utf-8 -*-
#
# Copyright 2014 Roy Liu
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require "spec_helper"

content = <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>outer0</key>
    <dict>
        <key>inner0</key>
        <dict>
            <key>key0</key>
            <false/>
            <key>key2</key>
            <false/>
        </dict>
    </dict>
    <key>outer1</key>
    <dict>
        <key>inner1</key>
        <dict>
            <key>key1</key>
            <false/>
        </dict>
    </dict>
</dict>
</plist>
EOS

updated_content = <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>outer0</key>
	<dict>
		<key>inner0</key>
		<dict>
			<key>key0</key>
			<true/>
			<key>key1</key>
			<dict>
				<key>a</key>
				<dict>
					<key>a</key>
					<date>2014-01-01T00:00:00Z</date>
					<key>b</key>
					<array>
						<true/>
						<string>a</string>
					</array>
					<key>c</key>
					<array>
						<false/>
						<integer>0</integer>
						<real>1.23</real>
					</array>
				</dict>
			</dict>
			<key>key2</key>
			<false/>
		</dict>
	</dict>
	<key>outer1</key>
	<dict>
		<key>inner1</key>
		<dict>
			<key>key0</key>
			<data>
			YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXphYmNkZWZnaGlqa2xt
			bm9wcXJzdHV2d3h5emFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6
			</data>
			<key>key1</key>
			<false/>
			<key>key2</key>
			<data>
			YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXphYmNkZWZnaGlqa2xt
			bm9wcXJzdHV2d3h5emFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6
			</data>
		</dict>
	</dict>
</dict>
</plist>
EOS

test_file = Pathname.new(Dir.tmpdir) + "plist_file_set_spec.plist"

describe "plist-test::plist_file_set" do
  before(:all) do
    test_file.open("wb") {|f| f.write(content)}

    ChefSpec::ServerRunner.new(step_into: ["plist_file"]).converge(described_recipe)
  end

  it "sets the value at a nested `dict` key" do
    expect(test_file.open("rb") {|f| f.read}).to eq(updated_content)
  end

  after(:all) do
    test_file.delete
  end
end
