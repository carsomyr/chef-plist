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

require "chef/shell_out"
require "diff/lcs"
require "diff/lcs/hunk"
require "etc"
require "pathname"

include Chef::Mixin::ShellOut
include Plist

def whyrun_supported?
  true
end

action :update do
  require "nokogiri" \
    if !defined?(Nokogiri)

  file = new_resource.file

  if !file
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

    file = prefix + "Library/Preferences/#{domain}.plist"
  end

  if !file.file?
    Chef::Log.info("no action taken for #{new_resource} because plist file #{file.to_s.dump} doesn't exist")

    next
  end

  # Use `plutil` to read plists that are potentially in the binary format.
  xml = shell_out!("plutil", "-convert", "xml1", "-o", "-", "--", file.to_s).stdout

  original_doc = Nokogiri::XML::Document.parse(xml)
  doc = original_doc.dup

  new_resource.keys_values.each do |keys, value|
    keys = keys.map { |key| key.to_s }
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

            # Prepend newly created children to the node representing the insertion location. Note that we are
            # rebuilding the `NodeSet` of children because Nokogiri incorrectly reparents existing `Text` nodes with
            # `Node#before`.
            children = children[0, index] \
              + [to_node(Plist::Key.new(last_key), doc, node, depth),
                 to_node(Plist::Text.new(shim_start), doc, node, depth),
                 to_node(value, doc, node, depth),
                 to_node(Plist::Text.new(shim_end), doc, node, depth)] \
              + children[index, children.size]

            node.children = Nokogiri::XML::NodeSet.new(doc, children)
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

  # Run the user queries.
  doc.root.css(*new_resource.css_queries, self).each(&new_resource.css_query_callback)

  original_xml = original_doc.to_xml(indent: 0)
  xml = doc.to_xml(indent: 0)

  next \
    if original_xml == xml

  format = new_resource.format

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
  descriptions.push(udiff(file, original_xml, file, xml).split("\n", -1))

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
  end
end
