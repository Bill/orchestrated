require 'delayed_job_active_record'

# facade for controlling delayed_job
module DJ
  module_function

  def job_count
    Delayed::Job.count
  end
  def work(num=100)
    Delayed::Worker.new.work_off(num)
  end
  def work_now(num=100)
    (1..num).each do
      first = Delayed::Job.first
      break unless first.present?
      first.tap{|job| job.run_at = 1.second.ago; job.save!}
      DJ.work(1)
    end
  end
  def clear_all_jobs
    Delayed::Job.delete_all
  end
  def max_attempts
    # configured in initializers/delayed_job_config.rb
    Delayed::Worker.max_attempts
  end
end
