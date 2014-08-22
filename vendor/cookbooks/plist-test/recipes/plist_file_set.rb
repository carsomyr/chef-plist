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

test_file = Pathname.new(Dir.tmpdir) + "#{recipe_name}_spec.plist"

plist_file "#{recipe_name}_spec" do
  file test_file
  set "outer0", "inner0", "key1", {a: {b: [true, "a"], c: [false, 0, 1.23]}}
  set "outer0", "inner0", "key0", true
  set "outer1", "inner1", "key0",
      Plist::Data.new("abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz")
  set "outer1", "inner1", "key2",
      Plist::Data.new("YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXphYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5emFiY2RlZmdo" \
                      "aWprbG1ub3BxcnN0dXZ3eHl6", false)
  action :nothing
end.action(:update)
