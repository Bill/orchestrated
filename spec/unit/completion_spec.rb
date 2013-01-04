require 'spec_helper'

require 'orchestrated'

shared_examples_for 'literally complete' do
  it 'should immediately enqueue the dependent orchestration' do
    expect(DJ.job_count).to eq(1)
  end
  it 'should cause the dependent orchestration to run immediately' do
    First.any_instance.should_receive(:do_first_thing)
    DJ.work(1)
  end
end

describe Orchestrated::CompletionExpression do
  context 'Complete' do
    context 'implicitly specified' do
      before(:each){ First.new.orchestrated.do_first_thing(12) }
      it_should_behave_like 'literally complete'
    end
    context 'explicitly specified' do
      before(:each){ First.new.orchestrated(Orchestrated::Complete.new).do_first_thing(12) }
      it_should_behave_like 'literally complete'
    end
  end
  context 'Incomplete' do
    it 'should immediately raise an error' do
      expect{First.new.orchestrated(Orchestrated::Incomplete.new).do_first_thing(12)}.to raise_error
    end
  end
  context 'OrchestrationCompletion' do
    before(:each){Second.new.orchestrated( First.new.orchestrated.do_first_thing(3)).do_second_thing(4)}
    it 'should block second orchestration until after first runs' do
      expect(DJ.job_count).to eq(1)
    end
    it 'should run second orchestration after first is complete' do
      Second.any_instance.should_receive(:do_second_thing)
      DJ.work(2)
    end
  end
  context 'FirstCompletion' do
    context 'given a (literal) Complete' do
      before(:each) do
        Second.new.orchestrated( Orchestrated::FirstCompletion.new <<
          Orchestrated::Complete.new
          ).do_second_thing(5)
      end
      it 'should immediately enqueue the dependent orchestration' do
        expect(DJ.job_count).to eq(1)
      end
    end
    context 'given two OrchestrationCompletions' do
      before(:each) do
        Second.new.orchestrated( Orchestrated::FirstCompletion.new <<
          First.new.orchestrated.do_first_thing(3) <<
          First.new.orchestrated.do_first_thing(4)
          ).do_second_thing(5)
      end
      it 'should enqueue the dependent orchestration as soon as the first prerequisite completes' do
        expect(DJ.job_count).to eq(2)
        DJ.work(1)
        expect(DJ.job_count).to eq(2)
      end
      it 'should cause the dependent orchestration to run eventually' do
        Second.any_instance.should_receive(:do_second_thing).with(5)
        DJ.work(3)
      end
      it 'should skip dependents after the first one runs' do
        First.any_instance.should_not_receive(:do_first_thing).with(4)
        DJ.work(3)
      end
    end
  end
  context 'LastCompletion' do
    context 'given two OrchestrationCompletions' do
      before(:each) do
        Second.new.orchestrated( Orchestrated::LastCompletion.new <<
          First.new.orchestrated.do_first_thing(3) <<
          First.new.orchestrated.do_first_thing(4)
          ).do_second_thing(5)
      end
      it 'should not enqueue the dependent orchestration as soon as the first prerequisite completes' do
        expect(DJ.job_count).to eq(2)
        DJ.work(1)
        expect(DJ.job_count).to eq(1)
      end
      it 'should not run the dependent orchestration as soon as the first prerequisite completes' do
        Second.any_instance.should_not_receive(:do_second_thing)
        DJ.work(2)
      end
      it 'should run the dependent orchestration after all the prerequisite are complete' do
        Second.any_instance.should_receive(:do_second_thing)
        DJ.work(3)
      end
    end
  end
end
