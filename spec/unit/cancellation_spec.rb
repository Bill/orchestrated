require 'spec_helper'

require 'orchestrated'

shared_examples_for 'cancellation:' do
  before(:each) do
    @prerequisite.cancel!
  end
  it 'dependent should be in the "canceled" state' do
    expect(@dependent.reload.canceled?).to be_true
  end
end

shared_examples_for 'cannot cancel:' do
  it 'dependent should be in the "canceled" state' do
    expect{@prerequisite.cancel!}.to raise_error(StateMachine::InvalidTransition)
  end
end

describe 'cancellation' do
  context 'directly on an orchestration' do
    before(:each) do
      @prerequisite = @dependent = First.new.orchestrated.do_first_thing(1)
    end
    context 'that is ready' do
      it_should_behave_like 'cancellation:'
      it 'should never subsequently deliver the orchestrated message' do
        First.any_instance.should_not_receive(:do_first_thing)
        DJ.work(1)
      end
    end
    context 'that is succeeded' do
      before(:each) do
        @prerequisite.orchestration.state = 'succeeded'
      end
      it_should_behave_like 'cannot cancel:'
    end
    context 'that is failed' do
      before(:each) do
        @prerequisite.orchestration.state = 'failed'
      end
      it_should_behave_like 'cannot cancel:'
    end
    context 'that is canceled' do
      before(:each) do
        @prerequisite.orchestration.state = 'canceled'
      end
      it_should_behave_like 'cannot cancel:'
    end
  end
  context 'of an orchestration that is depended on directly' do
    before(:each) do
      @dependent = Second.new.orchestrated( @prerequisite = First.new.orchestrated.do_first_thing(1)).do_second_thing(2)
    end
    it_should_behave_like 'cancellation:'
  end
  context 'of an orchestration that is depended on through a LastCompletion' do
    before(:each) do
      @dependent = Second.new.orchestrated(
        Orchestrated::LastCompletion.new <<
          (@prerequisite = First.new.orchestrated.do_first_thing(1))
        ).do_second_thing(2)
    end
    it_should_behave_like 'cancellation:'
  end
end
