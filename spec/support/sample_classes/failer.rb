class Failer
  acts_as_orchestrated

  def always_fail(something)
    raise 'I never work'
  end
end
