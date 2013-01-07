require 'spec_helper'

require 'orchestrated'


shared_examples_for 'orchestration accessing prerequisite and dependent' do
  it 'should reach interest at prerequisite' do
    expect(@orchestration.prerequisite).to eq(@interest)
  end
  it 'should reach completion at dependent' do
    expect(@orchestration.dependent).to eq(@completion)
  end
end

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
  context 'a new object' do
    let(:f){First.new}
    context 'responding to messages without orchestration' do
      let(:result){f.do_first_thing(2)} # 2 is a prime number
      it 'should immediately invoke a non-orchestrated method and return correct result' do
        expect(result).to eq(5 * 2)
      end
    end
    # I don't trust the has_one associations inside Orchestration to work right with the STI Completion hierarchy
    # after spec'ing this I see that ActiveRecord does indeed qualify the has_one lookup (both of them)
    # with the "type" field yay!
    context 'creating orchestrated' do
      # TODO: reimplement the next three functions as Factory Girl factories!
      def create_orchestration
        Orchestrated::Orchestration.new.tap do |orchestration|
          orchestration.handler = Orchestrated::Orchestration::Handler.new( f, :do_first_thing, [1])
          orchestration.save!
        end
      end
      def create_interest(orchestration, prerequisite=Orchestrated::Complete.new)
        prerequisite.save!
        Orchestrated::OrchestrationInterest.new.tap do |interest|
            interest.prerequisite = prerequisite
            interest.orchestration = orchestration
            interest.save!
        end
      end
      def create_completion(orchestration)
        Orchestrated::OrchestrationCompletion.new.tap do |completion|
          completion.orchestration = @orchestration
          completion.save!
        end
      end
      before(:each) do
        @orchestration = create_orchestration
      end
      context 'with prerequisite created before dependent' do
        before(:each) do
          @interest = create_interest(@orchestration)
          @completion = create_completion(@orchestration)
        end
        it_should_behave_like 'orchestration accessing prerequisite and dependent'
      end
      context 'with dependent created before prerequisite' do
        before(:each) do
          @completion = create_completion(@orchestration)
          @interest = create_interest(@orchestration)
        end
        it_should_behave_like 'orchestration accessing prerequisite and dependent'
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
      it 'should be ready' do
        expect(@result.orchestration.state).to eq('ready')
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
