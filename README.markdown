[Orchestrated](https://github.com/paydici/orchestrated)
=======================================================

The [delayed_job](https://github.com/collectiveidea/delayed_job) Ruby Gem provides a restartable queuing system for Ruby. It implements an elegant API for delaying execution of any Ruby object method invocation. Not only is the message delivery delayed in time, it is potentially shifted in space too. By shifting in space, i.e. running in a different virtual machine, possibly on a separate computer, multiple CPUs can be brought to bear on a computing problem.

By breaking up otherwise serial execution into multiple queued jobs, a program can be made more scalable. This sort of distributed queue-processing architecture has a long and successful history in data processing.

Queuing works well for simple, independent tasks. By simple we mean the task can be done all at once, in one piece, with no inter-task dependencies. This works well for performing a file upload task in the background (to avoid tying up a Ruby virtual machine process/thread). More complex (compound) multi-part tasks, however, do not fit this model. Examples of complex (compound) tasks include:

1. pipelined (multi-step) generation of a complex PDF document
2. an extract/transfer/load (ETL) job that must acquire data from source systems, transform it and load it into the target system

If we would like to scale these compound operations, breaking them into smaller parts, and managing the execution of those parts across many computers, we need an "orchestrator". This project implements just such a framework, called "[Orchestrated](https://github.com/paydici/orchestrated)".

[Orchestrated](https://github.com/paydici/orchestrated) introduces the ```acts_as_orchestrated``` Object class method. When invoked on your class, this will define the ```orchestrate``` instance method. You use ```orchestrate``` in a mannner similar to [delayed_job](https://github.com/collectiveidea/delayed_job)'s ```delay```—the difference being that ```orchestrate``` takes a parameter that lets you specify dependencies between your jobs.

The reason we refer to [delayed_job](https://github.com/collectiveidea/delayed_job) as a restartable queueing system is because, even if computers (database host, worker hosts) in the cluster crash, the work on the queues progresses. If no worker is servicing a particular queue, then work accumulates there. Once workers are available, they consume the jobs. This is a resilient architecture.

With [Orchestrated](https://github.com/paydici/orchestrated) you can create restartable workflows, a workflow consisting of one or more dependent, queueable, tasks. This means that your workflows will continue to make progress even in the face of database and (queue) worker crashes.

In summary, orchestrated workflows running atop [active_record](https://github.com/rails/rails/tree/master/activerecord) and [delayed_job](https://github.com/collectiveidea/delayed_job) have these characteristics:

1. restartable—the workflows make progress even though (queue worker, and database) hosts are not always available
2. scalable—compound workflows are broken into steps which can be executed on separate computers. Results can be accumulated from the disparate steps as needed.
3. forgiving of external system failures—workflow steps that communicate with an external system can simply throw an exception when the system is unavailable, assured that the step will be automatically retried again later.
4. composable—compound tasks can be defined in terms of simpler ones

Read on to get started.

Installation
------------

Add this line to your application's Gemfile:

    gem 'orchestrated'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install orchestrated

Now generate the database migration:

    $ rails g orchestrated:active_record
    $ rake db:migrate

If you do not already have [delayed_job](https://github.com/collectiveidea/delayed_job) set up, you'll need to do that as well.

The API
-------

To orchestrate (methods) on your own classes you simply call ```acts_as_orchestrated``` in the class definition. Declaring ```acts_as_orchestrated``` on your class defines the ```orchestrate``` method:

* ```orchestrate```—call this to specify your workflow prerequisite, and designate a workflow step

Use ```orchestrate``` to orchestrate any method on your class.

Let's say for example you needed to download a couple files from remote systems (a slow process), merge their content and then load the results into your system. This sort of workflow is sometimes referred to as extract/transfer/load or ETL. Imagine you have a ```Downloader``` class that knows how to download and an ```Xform``` class that knows how to merge the content and load the results into your system. Your ```Xform``` class might look something like this:

```ruby
class Xform

  acts_as_orchestrated

  def merge(many, one)
  ...
  end

  def load(stuff)
  ...
  end

end
```

You might write an orchestration like this:

```ruby
xform = Xform.new
xform.orchestrate(
  xform.orchestrate(
    Orchestrated::LastCompletion.new(
      Downloader.new.orchestrate.download(
        :from=>'http://fred.com/stuff', :to=>'fred_records'
      ),
      Downloader.new.orchestrate.download(
        :from=>'http://sally.com/stuff', :to=>'sally_records'
      )
    )
  ).merge(['fred_records', 'sally_records'], 'combined_records')
).load('combined_records')
```

The next time you process delayed jobs, the ```download``` messages will be delivered to a couple Downloaders. After the last download completes, the next time a delayed job is processed, the ```merge``` message will be delivered to an Xform object. And on it goes…

What happened there? The pattern is:

1. create an orchestrated object (instantiate it)
2. call ```orchestrate``` on it: this returns a *magic proxy* object that can respond to any of the messages your object can respond to
3. send any message to the *magic proxy* (returned in the second step) and the framework will delay delivery of that message and immediately return a "completion expression" you can use as a prerequisite for other orchestrations
4. (optionally) use the "completion expression" returned in (3) as a prerequisite for other orchestrations

Now the messages you can send in (3) can be anything that your object can respond to. The message will be remembered by the framework and "replayed" (on a new instance of your object) somewhere on the network (later).

Not accidentally, this is similar to the way [delayed_job](https://github.com/collectiveidea/delayed_job)'s delay method works. Under the covers, [Orchestrated](https://github.com/paydici/orchestrated) is conspiring with [delayed_job](https://github.com/collectiveidea/delayed_job) when it comes time to actually execute a workflow step. Before that time though, [Orchestrated](https://github.com/paydici/orchestrated) keeps track of everything.

Key Concept: Prerequisites (Completion Expressions)
---------------------------------------------------

Unlike [delayed_job](https://github.com/collectiveidea/delayed_job) ```delay```, the orchestrated ```orchestrate``` method takes an optional parameter: the prerequisite. The prerequisite determines when your workflow step is ready to run.

The return value from messaging the *magic proxy* is itself a ready-to-use prerequisite. You saw this in the ETL example above. The result of the first call to ```orchestrate``` calls (to ```download```) were sent as an argument to the third (```merge```). In this way, the ```merge``` workflow step was suspended until after the ```download```s finished.

You may have also noticed from that example that if you specify no prerequisite then the step will be ready to run immediately, as was the case for the ```download``` calls). If calling ```orchestrate``` with no parameters makes the step ready to run immediately then why should we bother to call it at all? Why not just call the method directly? The answer is that by calling ```orchestrate``` we are submitting the step to the underlying queueing system, enabling the step to be run on other resources (computers). Had we called the ```download``` directly it would have blocked the Ruby thread and would not have taken advantage of (potentially many) ```delayed_job``` job workers.

Users of the framework deal directly with three kinds of prerequisite or "completion expression":

1. ```OrchestrationCompletion```—returned from any message to a *magic proxy*: complete when its associated orchestration is complete
2. ```FirstCompletion```—aggregates other completions: complete after the first one completes
3. ```LastCompletion```—aggregates other completions: complete after all of them are complete

There are other kinds of completion expression used internally by the framework but these three are the important ones for users to understand. See the completion_spec for examples of how to combine these different prerequisite types into completion expressions.

Key Concept: Orchestration State
--------------------------------

An orchestration can be in one of a few states:

![Alt text](https://github.com/paydici/orchestrated/raw/master/Orchestration_state.png 'Orchestration States')

When you create a new orchestration that is waiting on a prerequisite that is not complete yet, the orchestration will be in the "waiting" state. Some time later, if that prerequisite completes, then your orchestration will become "ready". A "ready" orchestration is automatically queued to run by the framework (via [delayed_job](https://github.com/collectiveidea/delayed_job)).

A "ready" orchestration will use [delayed_job](https://github.com/collectiveidea/delayed_job) to deliver its (delayed) message. In the context of such a message delivery (inside your object method e.g. ```Xform#merge``` or ```Xform#load``` in our example) you can rely on the ability to access the current Orchestration (context) object via the ```orchestration``` accessor. Be careful with that one though. You really shouldn't need it very often, and to use it, you have to understand framework internals.

After your workflow step executes, the orchestration moves into either the "succeeded" or "failed" state.

When an orchestration is "ready" or "waiting" it may be canceled by sending it the ```cancel!``` message (i.e. a ```cancel!``` message to the ```OrchestrationCompletion```). This moves the orchestration to the "canceled" state and prevents subsequent delivery of the orchestrated message.

It is important to understand that both of the states: "succeeded" and "failed" are part of a "super-state": "complete". When an orchestration is in either of those two states, it will return ```true``` in response to the ```complete?``` message.

It is not just successful completion of orchestrated methods that causes dependent ones to run—a "failed" orchestration is complete too! If you have an orchestration that actually requires successful completion of its prerequisite then your method can inspect the prerequisite as needed, by accessing it via ```self.orchestration.prerequisite.prerequisite```.

Failure (An Option)
-------------------

Since Orchestration is built atop [delayed_job](https://github.com/collectiveidea/delayed_job) and borrows [delayed_job](https://github.com/collectiveidea/delayed_job)'s failure semantics. Neither framework imposes any special constraints on the (delayed or orchestrated) methods. In particular, there are no special return values to signal "failure". Orchestration adopts [delayed_job](https://github.com/collectiveidea/delayed_job)'s semantics for failure detection: a method that raises an exception has failed. After a certain number of retries (configurable in [delayed_job](https://github.com/collectiveidea/delayed_job)) the jobs is deemed permanently failed. When that happens, the corresponding orchestration is marked "failed". Until all the retries have been attempted, the orchestration remains in the "ready" state (as it was before the first failed attempt).

See the failure_spec if you'd like to understand more.

Cancelling an Orchestration
---------------------------

An orchestration can be canceled by sending the (orchestration completion) the ```cancel!``` message. This will prevent the orchestrated method from running (in the future). It will also cancel dependent workflow steps.

The cancellation_spec spells out more of the details.

Ruby 1.8.x Support (BasicObject)
---------------------------

The orchestrated gem was created for ruby 1.9.x and beyond. However, with [marcandre's backports](https://github.com/marcandre/backports) you can make it work. Simply add the following to your Gemfile, above the orchestrated gem.

```ruby
gem 'backports', :require => 'backports/basic_object'
gem 'orchestrated'
```

Now you can run `bundle install` and you should be good to go.

Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Future Work
-----------

Some possible avenues for exploration:

* orchestrate option: :max_attempts to configure max_attempts on underlying delayed job instance
* orchestrate option: :max_run_time to configure max_run_time on underlying delayed job instance
* orchestrate options: :queue to specify a particular named queue for the underlying delayed job
* some way to change the run_at recalculation for failed attempts (f(n) = 5 + n**4 is not always right and what's right varies by job)

License
-------

Copyright &copy; 2013 Paydici Inc. Distributed under the MIT License. See [LICENSE.txt](https://github.com/paydici/orchestrated/blob/master/LICENSE.txt) for further details.

Contains code originally from [delayed_job](https://github.com/collectiveidea/delayed_job) Copyright &copy; 2005 Tobias Luetke, [Ruby on Rails](https://github.com/rails/rails), and [Ick](https://github.com/raganwald-deprecated/ick); all of which are also under the MIT License.
