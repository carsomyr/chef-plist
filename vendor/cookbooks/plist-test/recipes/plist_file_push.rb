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

require "time"

test_file = Pathname.new(Dir.tmpdir) + "#{recipe_name}_spec.plist"

plist_file "#{recipe_name}_spec" do
  file test_file
  push "outer0", "inner0", {1 => 1}
  push "outer0", "inner0", {b: {0 => 0.0}, a: "a"}
  push "outer1", "inner1", [2, 3]
  push "outer1", "inner1", [1, 2]
  push "outer2", "inner2", "c"
  push "outer2", "inner2", "b"
  push "outer3", "inner3", 2
  push "outer3", "inner3", 1
  push "outer4", "inner4", 2.34
  push "outer4", "inner4", 1.23
  push "outer5", "inner5",
       Plist::Data.new("abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz")
  push "outer5", "inner5",
       Plist::Data.new("zyxwvutsrqponmlkjihgfedcbazyxwvutsrqponmlkjihgfedcbazyxwvutsrqponmlkjihgfedcba")
  push "outer6", "inner6", Time.iso8601("2016-01-01T00:00:00Z")
  push "outer6", "inner6", Time.iso8601("2015-01-01T00:00:00Z")

  options intermediate: true do
    push "outer7", "inner7", "a", 1
  end

  push "outer7", "inner7", "a", 2

  options intermediate: true do
    push "outer7", "inner9", "c", 1
    push "outer7", "inner8", "b", 1
  end

  action :nothing
end.action(:update)
