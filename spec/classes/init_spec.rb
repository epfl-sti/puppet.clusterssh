require 'spec_helper'
describe 'ssh_netgroup' do

  context 'with defaults for all parameters' do
    it { should contain_class('ssh_netgroup') }
  end
end
