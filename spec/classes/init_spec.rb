require 'spec_helper'
describe 'clusterssh' do

  context 'with defaults for all parameters' do
    it { should contain_class('clusterssh') }
  end
end
