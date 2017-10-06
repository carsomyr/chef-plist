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

def css_set(node, css_query, last_key_or_value, value = nil)
  doc = node.document

  if !value.nil?
    last_key = last_key_or_value
  else
    last_key = nil
    value = last_key_or_value
  end

  if last_key
    ((css_query && node.css(css_query, self)) || [node]).each do |dict_node|
      raise "Node name must be `dict`" \
        if dict_node.name != "dict"

      old_nodes = dict_node.css("> key:content_equals(#{escape_css(last_key)})", self)

      if old_nodes.size > 0
        # A value already exists for the key; replace it.
        new_node = to_node(value, doc, dict_node)
        old_nodes.each {|old_node| old_node.next_element.replace(new_node)}
      else
        depth = depth(dict_node)

        # Find a suitable insertion location so that keys remain lexicographically ordered.
        insertion_node = dict_node.css("> key").to_a.bsearch {|node| node.text > last_key}

        if insertion_node
          shim_start = "\n" + "\t" * depth
          shim_end = shim_start

          children = dict_node.children.to_a
          index = children.index(insertion_node)

          # Prepend newly created children to the node representing the insertion location. Note that we are rebuilding
          # the `NodeSet` of children because Nokogiri incorrectly reparents existing `Text` nodes with `Node#before`.
          children = children[0, index] \
            + [to_node(Plist::Key.new(last_key), doc, dict_node),
               to_node(Plist::Text.new(shim_start), doc, dict_node),
               to_node(value, doc, dict_node),
               to_node(Plist::Text.new(shim_end), doc, dict_node)] \
            + children[index, children.size]

          dict_node.children = Nokogiri::XML::NodeSet.new(doc, children) # ~FC047
        else
          shim_start = dict_node.children.size > 0 ? "\t" : "\n" + "\t" * depth
          shim_mid = "\n" + "\t" * depth
          shim_end = "\n" + "\t" * (depth - 1)

          # Append newly created children to the end.
          dict_node.add_child(to_node(Plist::Text.new(shim_start), doc, dict_node))
          dict_node.add_child(to_node(Plist::Key.new(last_key), doc, dict_node))
          dict_node.add_child(to_node(Plist::Text.new(shim_mid), doc, dict_node))
          dict_node.add_child(to_node(value, doc, dict_node))
          dict_node.add_child(to_node(Plist::Text.new(shim_end), doc, dict_node))
        end
      end
    end
  else
    ((css_query && node.css(css_query, self)) || [node]).each do |key_node|
      raise "Node name must be `key`" \
        if key_node.name != "key"

      new_node = to_node(value, doc, key_node.parent)
      key_node.next_element.replace(new_node)
    end
  end
end

def set(doc, keys, value, options = {})
  root = doc.root

  if options[:intermediate]
    create_intermediate_dicts(doc, keys[0...-1])
  end

  if keys.size > 0
    last_key = keys.last
    css_query = "> dict" + keys[0...-1].map {|key| " > key:content_equals(#{escape_css(key)}) + dict"}.join("")

    css_set(root, css_query, last_key, value)
  else
    # The user intends to replace the root `dict`.
    root.css("> dict").each do |dict_node|
      dict_node.replace(to_node(value, doc, root))
    end
  end
end

def css_push(node, css_query, value)
  doc = node.document

  ((css_query && node.css(css_query, self)) || [node]).each do |array_node|
    raise "Node name must be `array`" \
      if array_node.name != "array"

    depth = depth(array_node)

    value_node = to_node(value, doc, array_node)
    value = to_ruby(value_node)

    # Remove the node so that `to_ruby` doesn't pick it up when called on its parent.
    value_node.remove

    # Do nothing if the array already contains the value.
    next \
      if to_ruby(array_node).find {|xml_value| deep_equals?(xml_value, value)}

    shim_start = array_node.children.size > 0 ? "\t" : "\n" + "\t" * depth
    shim_end = "\n" + "\t" * (depth - 1)

    # Append newly created children to the end.
    array_node.add_child(to_node(Plist::Text.new(shim_start), doc, array_node))
    array_node.add_child(value_node)
    array_node.add_child(to_node(Plist::Text.new(shim_end), doc, array_node))
  end
end

def push(doc, keys, value, options = {})
  root = doc.root

  if options[:intermediate]
    dict_node = create_intermediate_dicts(doc, keys[0...-1])
    last_key = keys.last

    css_set(dict_node, nil, last_key, []) \
      if !dict_node.css("> key:content_equals(#{escape_css(last_key)}) + array", self).first
  end

  css_query = "> dict" \
    + keys.map {|key| " > key:content_equals(#{escape_css(key)})"}.join(" + dict") \
    + " + array"

  css_push(root, css_query, value)
end

def create_intermediate_dicts(doc, keys)
  root = doc.root
  root_dict_node = root.css("> dict").first

  return \
    if !root_dict_node || keys.size <= 1

  keys.reduce(root_dict_node) do |dict_node, key|
    css_query = "> key:content_equals(#{escape_css(key)}) + dict"
    child_dict_node = dict_node.css(css_query, self).first

    if !child_dict_node
      css_set(dict_node, nil, key, {})
      child_dict_node = dict_node.css(css_query, self).first
    end

    child_dict_node
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
        when "text/xml"
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
        file.open("wb") {|f| f.write(xml)}
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

action :create do
  require "nokogiri" \
    if !defined?(Nokogiri)

  if file.file?
    xml = shell_out!("plutil", "-convert", "xml1", "-o", "-", "--", file.to_s).stdout
    doc = Nokogiri::XML::Document.parse(xml).dup

    original_file = file
    original_xml = doc.to_xml(indent: 0)
  else
    doc = Nokogiri::XML::Document.new("1.0")
    doc.encoding = "UTF-8"
    doc.create_internal_subset("plist", "-//Apple//DTD PLIST 1.0//EN", "http://www.apple.com/DTDs/PropertyList-1.0.dtd")

    root = Nokogiri::XML::Node.new("plist", doc)
    root["version"] = "1.0"
    doc.add_child(root)

    # Start with an empty `dict` as the root's sole child.
    root.add_child(to_node({}, doc, root))

    original_file = nil
    original_xml = ""
  end

  new_resource.op_keys_values.each do |operation, keys, value, options|
    keys = keys.map {|key| key.to_s}

    case operation
      when :set
        set(doc, keys, value, options)
      when :push
        push(doc, keys, value, options)
      else
        raise "Invalid operation #{operation.to_s.dump}"
    end
  end

  new_resource.updated_by_last_action(save(original_file, original_xml, file, doc.to_xml(indent: 0)))
end
