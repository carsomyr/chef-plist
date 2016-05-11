# -*- coding: utf-8 -*-
#
# Copyright 2014-2016 Roy Liu
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

require "pathname"

actions [:update, :create]
default_action :update

attribute :domain, kind_of: String, name_attribute: true
attribute :file, kind_of: Pathname
attribute :format, kind_of: [NilClass, Symbol, String], equal_to: [nil, :binary, "binary", :xml, "xml"]
attribute :owner, kind_of: String
attribute :group, kind_of: String
attribute :mode, kind_of: [String, Fixnum]

attr_reader :op_keys_values
attr_reader :css_queries
attr_reader :css_query_callback

def set(*keys, value)
  raise "Setting the plist root `dict` requires an instance of `Hash`" \
    if keys.size == 0 && !value.is_a?(Hash)

  @op_keys_values.push([:set, keys, value])
end

def push(*keys, value)
  raise "Please provide at least one `dict` key" \
    if keys.size == 0

  @op_keys_values.push([:push, keys, value])
end

def css_select(*css_queries, &css_query_callback)
  raise "Please provide a callback for the CSS3 query results" \
    if !css_query_callback

  @css_queries = css_queries
  @css_query_callback = css_query_callback
end

def content(value)
  raise "Setting the plist root `dict` requires an instance of `Hash`" \
    if !value.is_a?(Hash)

  @op_keys_values = [[:content, [], value]]
end

def initialize(domain, run_context = nil)
  super

  @css_queries = []
  @op_keys_values = []
end
