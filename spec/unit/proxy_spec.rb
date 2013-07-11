require 'spec_helper'
require 'orchestrated'

class Object
  def my_crazy_proxy_test_method
    raise Exception.new("uh, we shouldn't get this")
  end
end

class MyProxyTestHarness
  acts_as_orchestrated

  def my_crazy_proxy_test_method
    4
  end
end

describe Orchestrated::Proxy do

  subject { MyProxyTestHarness.new }

  describe "when delegating methods" do
    before(:each) do
      Orchestrated::Orchestration.stub(:create)
    end

    it "ignores ::Object monkey patches" do
      expect {subject.orchestrate.my_crazy_proxy_test_method }.to_not raise_error
    end

    it "doesn't immediately call the method" do
      subject.should_not_receive(:my_crazy_proxy_test_method)
      subject.orchestrate.my_crazy_proxy_test_method
    end
  end
end
