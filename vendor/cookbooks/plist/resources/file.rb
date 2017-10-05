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
attribute :mode, kind_of: [String, Integer]

attr_reader :op_keys_values

def set(*keys, value)
  raise "Setting the plist root `dict` requires an instance of `Hash`" \
    if keys.size == 0 && !value.is_a?(Hash)

  @op_keys_values.push([:set, keys, value, @options || {}])
end

def push(*keys, value)
  raise "Please provide at least one `dict` key" \
    if keys.size == 0

  @op_keys_values.push([:push, keys, value, @options || {}])
end

def options(options, &block)
  raise "Nested `option` calls are not allowed" \
    if @options

  raise "Please provide some options" \
    if !options.is_a?(Hash)

  raise "Please provide a block" \
    if !block

  begin
    @options = options.dup

    block.call
  ensure
    @options = nil
  end
end

def initialize(domain, run_context = nil)
  super

  @op_keys_values = []
  @options = nil
end
