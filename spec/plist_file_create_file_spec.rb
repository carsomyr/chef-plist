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
	<key>a</key>
	<string>a</string>
	<key>b</key>
	<string>b</string>
	<key>c</key>
	<dict>
		<key>a</key>
		<string>a</string>
		<key>b</key>
		<string>b</string>
		<key>c</key>
		<string>c</string>
	</dict>
</dict>
</plist>
EOS

test_file = Pathname.new(Dir.tmpdir) + "plist_file_create_file_spec.plist"

describe "plist-test::plist_file_create_file" do
  before(:all) do
    ChefSpec::ServerRunner.new(step_into: ["plist_file"]).converge(described_recipe)
  end

  it "creates a plist file" do
    expect(test_file.open("rb") {|f| f.read}).to eq(content)
  end

  after(:all) do
    test_file.delete
  end
end
