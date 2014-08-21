# `plist` Cookbook

A cookbook containing recipes and resources for manipulating Apple property list files on Mac OS X. To select keys for
modification, the LWRP depends on the Nokogiri gem's CSS3 query feature. The user can then modify the selected keys like
they would XML nodes in the DOM tree, and the result is written back to the user- or system-level plist.

### License

    Copyright 2014 Roy Liu

    Licensed under the Apache License, Version 2.0 (the "License"); you may not
    use this file except in compliance with the License. You may obtain a copy
    of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
    License for the specific language governing permissions and limitations
    under the License.
