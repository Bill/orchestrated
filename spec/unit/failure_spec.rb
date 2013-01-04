require 'spec_helper'

require 'orchestrated'

describe 'failure' do
  context 'orchestrating a method that always fails' do
    before(:each) do
      Failer.new.orchestrated.always_fail('important stuff')
    end
    context 'after first exception from orchestrated method' do
      before(:each) do
        DJ.work(1)
      end
      it 'should leave the orchestration in the ready state' do
        expect(Orchestrated::Orchestration.with_state('ready').count).to eq(1)
      end
      it 'should leave the orchestration in the run queue' do
        expect(DJ.job_count).to eq(1)
      end
      context 'on first retry' do
        it 'should retry with same arguments' do
          Failer.any_instance.should_receive(:always_fail).with('important stuff')
          DJ.work_now(1)
        end
      end
    end
    context 'after (Delayed::Worker.max_attempts + 1) exceptions from orchestrated method' do
      before(:each) do
        DJ.work_now(DJ.max_attempts)
      end
      it 'should leave the orchestration in the failed state' do
        expect(Orchestrated::Orchestration.with_state('failed').count).to eq(1)
      end
      context 'on first subsequent retry' do
        it 'should never deliver the orchestrated message again' do
          Failer.any_instance.should_not_receive(:always_fail)
          DJ.work_now(1)
        end
      end
    end
  end
end
