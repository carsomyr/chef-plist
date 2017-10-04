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

require "base64"
require "etc"
require "pathname"
require "time"

module Plist
  class Key
    attr_reader :content

    def initialize(content)
      @content = content
    end
  end

  def Key(content)
    Key.new(content)
  end

  class Text
    attr_reader :content

    def initialize(content)
      @content = content
    end
  end

  def Text(content)
    Text.new(content)
  end

  class Data
    attr_reader :content

    def initialize(content, encode = true)
      if encode
        @content = Base64.strict_encode64(content)
      else
        # Make sure that the encoding is valid.
        Base64.strict_decode64(content)

        @content = content
      end
    end

    def ==(rhs)
      @content == rhs.content
    end

    def hash
      @content.hash
    end

    def eql?(rhs)
      self == rhs
    end
  end

  def Data(content, encode = true)
    Data.new(content, encode)
  end

  module InstanceMethods
    def owner
      @owner ||= new_resource.owner || node["plist"]["owner"] || ENV["SUDO_USER"] || Etc.getpwuid.name # ~FC019
    end

    # We are using Aaron Patterson's remedy here (see
    # `https://groups.google.com/forum/#!msg/nokogiri-talk/6stziv8GcJM/5-VYgSEt7MsJ`).
    def escape_css(str)
      "'#{str.split("'", -1).join("', \"'\", '")}'"
    end

    def content_equals(node_set, *escaped_text_fragments)
      text = escaped_text_fragments.join("")
      node_set.find_all {|node| node.text == text}
    end

    def to_node(data, document, parent, depth = nil)
      if !depth
        node = parent
        depth = 0

        while node != document.root
          node = node.parent
          depth += 1
        end
      end

      shim_start = "\n" + "\t" * (depth + 1)
      shim_end = "\n" + "\t" * depth

      case data
        when Hash
          node = Nokogiri::XML::Node.new("dict", document)
          node.parent = parent # ~FC047

          data.each_pair.sort do |lhs, rhs|
            lhs[0].to_s <=> rhs[0].to_s
          end.map do |key, value|
            node.add_child(to_node(Text(shim_start), document, node, depth + 1))
            node.add_child(to_node(Key(key), document, node, depth + 1))
            node.add_child(to_node(Text(shim_start), document, node, depth + 1))
            node.add_child(to_node(value, document, node, depth + 1))
          end

          node.add_child(to_node(Text(shim_end), document, node, depth + 1)) \
            if data.size > 0
        when Array
          node = Nokogiri::XML::Node.new("array", document)
          node.parent = parent # ~FC047

          data.each do |value|
            node.add_child(to_node(Text(shim_start), document, node, depth + 1))
            node.add_child(to_node(value, document, node, depth + 1))
          end

          node.add_child(to_node(Text(shim_end), document, node, depth + 1)) \
            if data.size > 0
        when String
          node = Nokogiri::XML::Node.new("string", document)
          node.parent = parent # ~FC047
          node.content = data # ~FC047
        when TrueClass
          node = Nokogiri::XML::Node.new("true", document)
          node.parent = parent # ~FC047
        when FalseClass
          node = Nokogiri::XML::Node.new("false", document)
          node.parent = parent # ~FC047
        when Integer
          node = Nokogiri::XML::Node.new("integer", document)
          node.parent = parent # ~FC047
          node.content = data.to_s # ~FC047
        when Float
          node = Nokogiri::XML::Node.new("real", document)
          node.parent = parent # ~FC047

          # Remove trailing zeroes if the float has an integral value: Apparently this is the representation used by
          # Apple for their `real` data type.
          data = data.to_i \
            if data == data.to_i && data != 0.0

          node.content = data.to_s # ~FC047
        when Data
          node = Nokogiri::XML::Node.new("data", document)
          node.parent = parent # ~FC047

          lines = data.content.scan(Regexp.new(".{1,#{76 - 8 * depth}}"))

          node.add_child(to_node(Text(([""] + lines + [""]).join(shim_end)), document, node, depth + 1)) \
            if data.content.size > 0
        when Time
          node = Nokogiri::XML::Node.new("date", document)
          node.parent = parent # ~FC047
          node.content = data.iso8601 # ~FC047
        when Key
          node = Nokogiri::XML::Node.new("key", document)
          node.parent = parent # ~FC047
          node.content = data.content # ~FC047
        when Text
          node = Nokogiri::XML::Text.new(data.content, document)
          node.parent = parent # ~FC047
        else
          raise "There is no corresponding plist data type for the given Ruby object"
      end

      node
    end

    def to_ruby(node, depth)
      case node.name
        when "dict"
          elements = node.elements
          Hash[(0...elements.size).step(2).map {|i| [elements[i].text, to_ruby(elements[i + 1], depth + 1)]}]
        when "array"
          node.elements.map {|element| to_ruby(element, depth + 1)}
        when "string"
          node.text
        when "true"
          true
        when "false"
          false
        when "integer"
          node.text.to_i
        when "real"
          node.text.to_f
        when "data"
          # Strip out pretty-printed whitespace.
          Data.new(node.text.gsub("\n" + "\t" * depth, ""), false)
        when "date"
          Time.iso8601(node.text)
        else
          raise "Invalid plist data type #{node.name.dump}"
      end
    end

    def deep_equals?(lhs, rhs)
      return false \
        if lhs.class != rhs.class

      case lhs
        when Array
          return false \
            if lhs.size != rhs.size || (0...lhs.size).find {|i| !deep_equals?(lhs[i], rhs[i])}
        when Hash
          lhs_keys = lhs.keys
          rhs_keys = rhs.keys

          return false \
            if lhs_keys.sort != rhs_keys.sort || lhs_keys.find {|key| !deep_equals?(lhs[key], rhs[key])}
        when String, TrueClass, FalseClass, Integer, Float, Plist::Data, Time
          return false \
            if lhs != rhs
        else
          raise "There is no corresponding plist data type for the given Ruby object"
      end

      true
    end

    def udiff(src_file, src_content, dst_file, dst_content)
      time_format = "%Y-%m-%d %H:%M:%S.%N %z"
      time_str = Time.now.localtime.strftime(time_format)

      acc = ""

      if src_file
        acc.concat("--- #{src_file.to_s}\t#{src_file.stat.mtime.localtime.strftime(time_format)}\n")
      else
        acc.concat("--- /dev/null\t#{time_str}\n")
      end

      if dst_file
        acc.concat("--- #{dst_file.to_s}\t#{time_str}\n")
      else
        acc.concat("--- /dev/null\t#{time_str}\n")
      end

      curr_hunk = nil
      prev_hunk = nil
      prev_difference = 0

      src_lines = src_content.split("\n", -1)
      dst_lines = dst_content.split("\n", -1)

      # Build the diff output from merged hunks. Inspired by
      # `https://github.com/opscode/chef/blob/master/lib/chef/util/diff.rb`.
      Diff::LCS.diff(src_lines, dst_lines).each do |fragment|
        begin
          curr_hunk = Diff::LCS::Hunk.new(src_lines, dst_lines, fragment, 3, prev_difference)
          prev_difference = curr_hunk.file_length_difference

          next \
            if !prev_hunk || curr_hunk.merge(prev_hunk)

          acc.concat("#{prev_hunk.diff(:unified)}\n")
        ensure
          prev_hunk = curr_hunk
        end
      end

      acc.concat("#{prev_hunk.diff(:unified)}\n") \
        if prev_hunk

      acc
    end
  end

  def self.included(clazz)
    clazz.send(:include, InstanceMethods)
  end
end
