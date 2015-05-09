# -*- coding: utf-8 -*-
# == Fact: has_hammer
#
# ♬ If I had a hammer... ♫
#
Facter.add("has_hammer") do
  setcode do
    system('rpm -qi rubygem-hammer_cli >/dev/null 2>&1')
  end
end
