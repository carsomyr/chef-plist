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

require "diff/lcs"
require "diff/lcs/hunk"
require "etc"
require "pathname"

include Chef::Mixin::ShellOut
include Plist

def whyrun_supported?
  true
end

def set_operation(doc, keys, value)
  root = doc.root

  if keys.size > 0
    last_key = keys.pop
    css_query = "> dict" + keys.map { |key| " > key:content_equals(#{escape_css(key)}) + dict" }.join("")

    root.css(css_query, self).each do |node|
      old_nodes = node.css("> key:content_equals(#{escape_css(last_key)})", self)

      if old_nodes.size > 0
        # A value already exists for the key; replace it.
        new_node = to_node(value, doc, node)
        old_nodes.each { |old_node| old_node.next_element.replace(new_node) }
      else
        parent = node
        depth = 0

        while parent != root
          parent = parent.parent
          depth += 1
        end

        # Find a suitable insertion location so that keys remain lexicographically ordered.
        insertion_node = node.css("> key").to_a.bsearch { |node| node.text > last_key }

        if insertion_node
          shim_start = "\n" + "\t" * depth
          shim_end = shim_start

          children = node.children.to_a
          index = children.index(insertion_node)

          # Prepend newly created children to the node representing the insertion location. Note that we are rebuilding
          # the `NodeSet` of children because Nokogiri incorrectly reparents existing `Text` nodes with `Node#before`.
          children = children[0, index] \
            + [to_node(Plist::Key.new(last_key), doc, node, depth),
               to_node(Plist::Text.new(shim_start), doc, node, depth),
               to_node(value, doc, node, depth),
               to_node(Plist::Text.new(shim_end), doc, node, depth)] \
            + children[index, children.size]

          node.children = Nokogiri::XML::NodeSet.new(doc, children) # ~FC047
        else
          shim_start = node.children.size > 0 ? "\t" : "\n" + "\t" * depth
          shim_mid = "\n" + "\t" * depth
          shim_end = "\n" + "\t" * (depth - 1)

          # Append newly created children to the end.
          node.add_child(to_node(Plist::Text.new(shim_start), doc, node, depth))
          node.add_child(to_node(Plist::Key.new(last_key), doc, node, depth))
          node.add_child(to_node(Plist::Text.new(shim_mid), doc, node, depth))
          node.add_child(to_node(value, doc, node, depth))
          node.add_child(to_node(Plist::Text.new(shim_end), doc, node, depth))
        end
      end
    end
  else
    # The user intends to replace the root `dict`.
    root.css("> dict").each do |node|
      node.replace(to_node(value, doc, root, 0))
    end
  end
end

def push_operation(doc, keys, value)
  root = doc.root

  last_key = keys.pop
  css_query = "> dict" \
    + keys.map { |key| " > key:content_equals(#{escape_css(key)}) + dict" }.join("") \
    + " > key:content_equals(#{escape_css(last_key)}) + array"

  root.css(css_query, self).each do |node|
    parent = node
    depth = 0

    while parent != root
      parent = parent.parent
      depth += 1
    end

    value_node = to_node(value, doc, node, depth).remove
    value = to_ruby(value_node, depth)

    # Do nothing if the array already contains the value.
    next \
      if to_ruby(node, depth - 1).find { |xml_value| deep_equals?(xml_value, value) }

    shim_start = node.children.size > 0 ? "\t" : "\n" + "\t" * depth
    shim_end = "\n" + "\t" * (depth - 1)

    # Append newly created children to the end.
    node.add_child(to_node(Plist::Text.new(shim_start), doc, node, depth))
    node.add_child(value_node)
    node.add_child(to_node(Plist::Text.new(shim_end), doc, node, depth))
  end
end

def file
  @file \
    if @file

  @file = new_resource.file

  if !@file
    domain = new_resource.domain

    # Handle special domains.
    case domain
      when "Apple Global Domain"
        domain = ".GlobalPreferences"
    end

    if owner != "root"
      prefix = Pathname.new(Etc.getpwnam(owner).dir)
    else
      # If the owner is root, we assume that the user is referring to a system-level plist file.
      prefix = Pathname.new("/")
    end

    @file = prefix + "Library/Preferences/#{domain}.plist"
  end

  @file
end

def save(original_file, original_xml, file, xml)
  format = new_resource.format
  group = new_resource.group
  mode = new_resource.mode

  return false \
    if original_xml == xml

  if !format
    if file.file?
      # Use the original input format if the output format wasn't specified.

      mime_type = shell_out!("file", "-b", "--mime-type", "--", file.to_s).stdout.chomp("\n")

      case mime_type
        when "application/octet-stream"
          format = "binary"
        when "application/xml"
          format = "xml"
        else
          raise "Invalid MIME type #{mime_type.dump}"
      end
    else
      format = "xml"
    end
  else
    format = format.to_s
  end

  descriptions = ["#{action.to_s} plist #{file.to_s.dump}"]
  descriptions.push(udiff(original_file, original_xml, file, xml).split("\n", -1))

  # Use `converge_by` to obtain some nice why-run output.
  converge_by(descriptions) do
    case format
      when "binary"
        # Use `plutil` to write out the plist in the binary format.
        shell_out!("plutil", "-convert", "binary1", "-o", file.to_s, "--", "-", input: xml)
      when "xml"
        file.open("wb") { |f| f.write(xml) }
      else
        raise "Invalid plist output format #{format.dump}"
    end

    FileUtils.chown(owner, nil, file) \
      if owner

    FileUtils.chown(nil, group, file) \
      if group

    FileUtils.chmod(mode, file) \
      if mode
  end

  true
end

action :update do
  require "nokogiri" \
    if !defined?(Nokogiri)

  if !file.file?
    Chef::Log.info("no action taken for #{new_resource} because plist file #{file.to_s.dump} doesn't exist")

    next
  end

  # Use `plutil` to read plists that are potentially in the binary format.
  xml = shell_out!("plutil", "-convert", "xml1", "-o", "-", "--", file.to_s).stdout

  original_doc = Nokogiri::XML::Document.parse(xml)
  doc = original_doc.dup

  new_resource.op_keys_values.each do |operation, keys, value|
    keys = keys.map { |key| key.to_s }

    case operation
      when :set
        set_operation(doc, keys, value)
      when :push
        push_operation(doc, keys, value)
      else
        raise "Invalid operation #{operation.to_s.dump}"
    end
  end

  # Run the user queries.
  doc.root.css(*new_resource.css_queries, self).each(&new_resource.css_query_callback)

  new_resource.updated_by_last_action(save(file, original_doc.to_xml(indent: 0), file, doc.to_xml(indent: 0)))
end

action :create do
  require "nokogiri" \
    if !defined?(Nokogiri)

  if file.file?
    xml = shell_out!("plutil", "-convert", "xml1", "-o", "-", "--", file.to_s).stdout
    original_file = file
    original_xml = Nokogiri::XML::Document.parse(xml).to_xml(indent: 0)
  else
    original_file = nil
    original_xml = ""
  end

  op_keys_values = new_resource.op_keys_values

  raise "Please set the resource's `content` attribute for plist creation" \
    if op_keys_values.size != 1 || op_keys_values.first[0] != :content

  value = op_keys_values.first[2]

  doc = Nokogiri::XML::Document.new("1.0")
  doc.encoding = "UTF-8"
  doc.create_internal_subset("plist", "-//Apple//DTD PLIST 1.0//EN", "http://www.apple.com/DTDs/PropertyList-1.0.dtd")

  root = Nokogiri::XML::Node.new("plist", doc)
  root["version"] = "1.0"
  doc.add_child(root)

  root.add_child(to_node(value, doc, root, 0))

  new_resource.updated_by_last_action(save(original_file, original_xml, file, doc.to_xml(indent: 0)))
end
