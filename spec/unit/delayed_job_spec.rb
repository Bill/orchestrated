require 'spec_helper'

class TestJob < Struct.new(:name)

  class << self
    attr_accessor :called

    def reset_called
      @called = Hash.new { |hash, key| hash[key] = 0 }
    end
  end

  reset_called # initialized the class

  # some random method
  def custom_action
    self.class.called[:custom_action] += 1
  end

  # -------------- delayed_job lifecycle callbacks ---------------
  def enqueue(job)
  end

  def perform
    self.class.called[:perform] += 1
  end

  def before(job)
  end

  def after(job)
  end

  def success(job)
  end

  def error(job, exception)
  end

  def failure
  end

end

describe Delayed::Job do
  context 'with a job' do
    let(:job) {TestJob.new('fred')}
    it 'should accept rspec message hooks' do
      # these hooks aren't as useful as you might think since
      # the object "waked" by DJ is a different object entirely!
      job.should_receive(:custom_action).and_call_original
      job.custom_action
    end
    it 'should start with an empty queue' do
      expect(DJ.job_count).to be(0)
    end
    it 'should enqueue a job' do
      expect {
        job.delay.custom_action
      }.to change{DJ.job_count}.by(1)
    end
    context 'that is enqueued' do
      before(:each) do
        DJ.clear_all_jobs
        job.delay.custom_action # queue exactly one job
      end
      it 'should dequeue the job' do
        expect {
          successes, failures = DJ.work
        }.to change{DJ.job_count}.by(-1)
      end
      it 'should deliver a message' do
        expect {
          successes, failures = DJ.work
        }.to change{TestJob.called[:custom_action]}.by(1)
      end
    end
  end
end
