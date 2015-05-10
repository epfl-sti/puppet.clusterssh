#
# module_path.rb
#
# Dominique Quatravaux: lifted from git://gist.github.com/5312010.git and
# https://gist.github.com/3307835.git then refactored to taste
#
# Copyright 2011 Puppet Labs Inc.
# Copyright 2011 Krzysztof Wilczynski
# Copyright 2012 James Fellows
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Clusterssh
  def module_path(mod_name)
    env = compiler.environment.to_s
    mod = Puppet::Module.find(mod_name, env)
    raise Puppet::Error, "exists(): invalid module name #{mod_name}" unless mod
    return mod.path
  end

  # Returns a path resolved on the Puppet Master.
  # 
  # Replace 'puppet://module/<foo>' with the `module_path()` of <foo>,
  # and return the resulting string.
  def resolve_puppetmaster_path(path)
    raise Puppet::ParseError, 'resolve_puppet_master_path(): Requires a string'
      unless file.is_a?(String)
 
    if path.slice!('puppet:///')
    # Perform relative lookup in modules/files dir.
        # strip off the modules prefix too if it's there
        path.slice!('modules/')
        mod_name, file = file.split(File::SEPARATOR, 2)
        return File.join(module_path(mod_name), "files", path)
    else
        return File.expand_path(path)
    end
end
 
module Puppet::Parser::Functions
  newfunction(:module_path, :type => :rvalue, :doc => <<-EOS
Returns the root path of a given module on the Puppet Master.

Prototype:

    module_path(module_name)

    EOS
  ) do |arguments|
 
    #
    # This is to ensure that whenever we call this function from within
    # the Puppet manifest or alternatively from a template it will always
    # do the right thing ...
    #
    arguments = arguments.shift if arguments.first.is_a?(Array)
 
    raise Puppet::ParseError, "exists(): Wrong number of arguments " +
      "given (#{arguments.size} for 1)" if arguments.size < 1
 
    return Clusterssh::module_path(arguments.shift)
  end

  newfunction(:exists, :type => :rvalue, :doc => <<-EOS
Returns an boolean value if a given file and/or directory exists on Puppet Master.

Prototype:

    exists(x)

Where x is a file or directory.

For example:

  Given the following statements:

    $a = '/etc/resolv.conf'
    $b = '/this/does/not/exist'

    notice exists($a)
    notice exists($b)

  The result will be as follows:

    notice: Scope(Class[main]): true
    notice: Scope(Class[main]): false

  The function will also look in the puppetmaster modules directory if the 
  file path is relative rather than absolute:

    $c = 'puppet:///modules/my_module/exists'

    notice exists ($c)
 
  The result will be as follows, IF the file 'modules/my_module/files/exists' 
  exists

    notice: Scope(Class[main]): true

  An error will be thrown if the a module by that name doesn't exist.

  Note:

    This function will ONLY be evaluated on the Puppet Master side and it
    makes no sense to use it when checking whether a file and/or directory
    exists on the client side.
    EOS
  ) do |arguments|
     arguments = arguments.shift if arguments.first.is_a?(Array)
    raise Puppet::ParseError, "exists(): Wrong number of arguments " +
      "given (#{arguments.size} for 1)" if arguments.size < 1
    return File.exists?(Clusterssh::resolve_puppetmaster_path(arguments.shift))
  end
end
 
# vim: set ts=2 sw=2 et :
