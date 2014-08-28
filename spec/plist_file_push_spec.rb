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
        <array>
             <dict>
                 <key>0</key>
                 <integer>0</integer>
             </dict>
             <dict>
                 <key>a</key>
                 <string>a</string>
                 <key>b</key>
                 <dict>
                     <key>0</key>
                     <real>0</real>
                 </dict>
             </dict>
        </array>
    </dict>
    <key>outer1</key>
    <dict>
        <key>inner1</key>
        <array>
             <array>
                 <integer>0</integer>
                 <integer>1</integer>
             </array>
             <array>
                 <integer>1</integer>
                 <integer>2</integer>
             </array>
        </array>
    </dict>
    <key>outer2</key>
    <dict>
        <key>inner2</key>
        <array>
             <string>a</string>
             <string>b</string>
        </array>
    </dict>
    <key>outer3</key>
    <dict>
        <key>inner3</key>
        <array>
             <integer>0</integer>
             <integer>1</integer>
        </array>
    </dict>
    <key>outer4</key>
    <dict>
        <key>inner4</key>
        <array>
             <real>0.12</real>
             <real>1.23</real>
        </array>
    </dict>
    <key>outer5</key>
    <dict>
        <key>inner5</key>
        <array>
            <data>
            enl4d3Z1dHNycXBvbm1sa2ppaGdmZWRjYmF6eXh3dnV0c3JxcG9u
            bWxramloZ2ZlZGNiYXp5eHd2dXRzcnFwb25tbGtqaWhnZmVkY2Jh
            </data>
        </array>
    </dict>
    <key>outer6</key>
    <dict>
        <key>inner6</key>
        <array>
            <date>2014-01-01T00:00:00Z</date>
            <date>2015-01-01T00:00:00Z</date>
        </array>
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
		<array>
			<dict>
				<key>0</key>
				<integer>0</integer>
			</dict>
			<dict>
				<key>a</key>
				<string>a</string>
				<key>b</key>
				<dict>
					<key>0</key>
					<real>0.0</real>
				</dict>
			</dict>
			<dict>
				<key>1</key>
				<integer>1</integer>
			</dict>
		</array>
	</dict>
	<key>outer1</key>
	<dict>
		<key>inner1</key>
		<array>
			<array>
				<integer>0</integer>
				<integer>1</integer>
			</array>
			<array>
				<integer>1</integer>
				<integer>2</integer>
			</array>
			<array>
				<integer>2</integer>
				<integer>3</integer>
			</array>
		</array>
	</dict>
	<key>outer2</key>
	<dict>
		<key>inner2</key>
		<array>
			<string>a</string>
			<string>b</string>
			<string>c</string>
		</array>
	</dict>
	<key>outer3</key>
	<dict>
		<key>inner3</key>
		<array>
			<integer>0</integer>
			<integer>1</integer>
			<integer>2</integer>
		</array>
	</dict>
	<key>outer4</key>
	<dict>
		<key>inner4</key>
		<array>
			<real>0.12</real>
			<real>1.23</real>
			<real>2.34</real>
		</array>
	</dict>
	<key>outer5</key>
	<dict>
		<key>inner5</key>
		<array>
			<data>
			enl4d3Z1dHNycXBvbm1sa2ppaGdmZWRjYmF6eXh3dnV0c3JxcG9u
			bWxramloZ2ZlZGNiYXp5eHd2dXRzcnFwb25tbGtqaWhnZmVkY2Jh
			</data>
			<data>
			YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXphYmNkZWZnaGlqa2xt
			bm9wcXJzdHV2d3h5emFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6
			</data>
		</array>
	</dict>
	<key>outer6</key>
	<dict>
		<key>inner6</key>
		<array>
			<date>2014-01-01T00:00:00Z</date>
			<date>2015-01-01T00:00:00Z</date>
			<date>2016-01-01T00:00:00Z</date>
		</array>
	</dict>
</dict>
</plist>
EOS

test_file = Pathname.new(Dir.tmpdir) + "plist_file_push_spec.plist"

describe "plist-test::plist_file_push" do
  before(:all) do
    test_file.open("wb") { |f| f.write(content) }

    ChefSpec::Runner.new(step_into: ["plist_file"]).converge(described_recipe)
  end

  it "pushes the value onto a nested `array`" do
    expect(test_file.open("rb") { |f| f.read }).to eq(updated_content)
  end

  after(:all) do
    test_file.delete
  end
end
