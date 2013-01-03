require 'spec_helper'

require 'orchestrated'

describe Orchestrated do
  context 'initializing' do
    it 'should not define orchestrated on Object' do
      expect(Object.public_method_defined?(:orchestrated)).to be_false
    end
    it 'should not define orchestrated on ActiveRecord::Base' do
      expect(ActiveRecord::Base.public_method_defined?(:orchestrated)).to be_false
    end
    it 'should define orchestrated on First' do
      expect(First.public_method_defined?(:orchestrated)).to be_true
    end
  end
  context 'a new orchestrated object' do
    let(:f){First.new}
    context 'responding to messages without orchestration' do
      let(:result){f.do_first_thing(2)} # 2 is a prime number
      it 'should immediately invoke a non-orchestrated method and return correct result' do
        expect(result).to eq(5 * 2)
      end
    end
    context 'orchestrating with no prerequisites' do
      before(:each){@result = f.orchestrated.do_first_thing(2)}
      after(:each){DJ.clear_all_jobs}
      it 'should not immediately invoke an orchestrated method' do
        First.any_instance.should_not_receive(:do_first_thing)
      end
      it 'should return an Orchestration object' do
        expect(@result).to be_kind_of(Orchestrated::CompletionExpression)
      end
    end
  end
  context 'invocation' do
    before(:each) do
      First.new.orchestrated.do_first_thing(1)
    end
    it 'should have access to Orchestration' do
      First.any_instance.should_receive(:orchestration=).with(kind_of(Orchestrated::Orchestration))
      First.any_instance.should_receive(:orchestration=).with(nil)
      DJ.work(1)
    end
  end
end
