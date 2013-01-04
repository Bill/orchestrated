require 'spec_helper'

require 'orchestrated'

shared_context 'cancelling first prerequisite' do
  before(:each) do
    first_prerequisite.cancel!
  end
end
shared_context 'cancelling all prerequisites' do
  before(:each) do
    first_prerequisite.cancel!
    last_prerequisite.cancel!
  end
end
shared_examples_for 'cancellation:' do
  it 'dependent should be in the "canceled" state' do
    expect(dependent.reload.canceled?).to be_true
  end
end
shared_examples_for "cancellation doesn't (cancel):" do
  it 'dependent not should be in the "canceled" state' do
    expect(dependent.reload.canceled?).to be_false
  end
end
shared_examples_for 'cannot cancel:' do
  it 'should raise an error when we try to cancel it' do
    expect{@first_prerequisite.cancel!}.to raise_error(StateMachine::InvalidTransition)
  end
end

describe 'cancellation' do
  attr_accessor :first_prerequisite, :last_prerequisite, :dependent
  def dependent;@dependent;end
  context 'directly on an orchestration' do
    before(:each) do
      @first_prerequisite = @dependent = First.new.orchestrated.do_first_thing(1)
    end
    context 'that is ready' do
      include_context 'cancelling first prerequisite'
      it_should_behave_like 'cancellation:'
      it 'should never subsequently deliver the orchestrated message' do
        First.any_instance.should_not_receive(:do_first_thing)
        DJ.work(1)
      end
    end
    context 'that is succeeded' do
      before(:each) do
        @first_prerequisite.orchestration.state = 'succeeded'
      end
      it_should_behave_like 'cannot cancel:'
    end
    context 'that is failed' do
      before(:each) do
        @first_prerequisite.orchestration.state = 'failed'
      end
      it_should_behave_like 'cannot cancel:'
    end
    context 'that is canceled' do
      before(:each) do
        @first_prerequisite.orchestration.state = 'canceled'
      end
      it_should_behave_like 'cannot cancel:'
    end
  end
  context 'of an orchestration that is depended on directly' do
    before(:each) do
      @dependent = Second.new.orchestrated( @first_prerequisite = First.new.orchestrated.do_first_thing(1)).do_second_thing(2)
    end
    include_context 'cancelling first prerequisite'
    it_should_behave_like 'cancellation:'
  end
  context 'of an orchestration that is depended on through a LastCompletion' do
    before(:each) do
      @dependent = Second.new.orchestrated(
        Orchestrated::LastCompletion.new <<
          (@first_prerequisite = First.new.orchestrated.do_first_thing(1))
        ).do_second_thing(2)
    end
    include_context 'cancelling first prerequisite'
    it_should_behave_like 'cancellation:'
  end
  context 'of an orchestration that is depended on through a FirstCompletion with two prerequisites' do
    before(:each) do
      @dependent = Second.new.orchestrated(
        Orchestrated::FirstCompletion.new <<
          (@first_prerequisite = First.new.orchestrated.do_first_thing(3)) <<
          (@last_prerequisite = First.new.orchestrated.do_first_thing(1))
        ).do_second_thing(2)
    end
    context 'after first prerequisite is canceled' do
      include_context 'cancelling first prerequisite'
      it_should_behave_like "cancellation doesn't (cancel):"
    end
    context 'after last prerequisite is canceled' do
      include_context 'cancelling all prerequisites'
      it_should_behave_like "cancellation:"
    end
  end
end
