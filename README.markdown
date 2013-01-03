Orchestrated
============

The [delayed_job](https://github.com/collectiveidea/delayed_job) Ruby Gem provides a job queuing system for Ruby. It implements an elegant API for delaying execution of any object method. Not only is the execution of the method (message delivery) delayed in time, it is potentially shifted in space too. By shifting in space, i.e. running in a separate virtual machine, possibly on a separate computer, multiple CPUs can be brought to bear on a computing problem.

By breaking up otherwise serial execution into multiple queued jobs, a program can be made more scalable. This sort of distributed queue-processing architecture has a long and successful history in data processing.

Queuing works well for simple tasks. By simple we mean, the task can be done all at once, in one piece. It has no dependencies on other tasks. This works well for performing a file upload task in the background (to avoid tying up a Ruby virtual machine process/thread). More complex (compound) multi-part tasks, however, do not fit this model. Examples of complex (compound) tasks include:

1. pipelined (multi-step) generation of complex PDF documents
2. extract/transfer/load (ETL) jobs that may load thousands of database records

If we would like to scale these compound operations, breaking them into smaller parts, and managing the execution of those parts across many computers, we need an "orchestrator". This project implements just such a framework, called "Orchestrated".

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

To orchestrate (methods) on your own classes you simply call ```acts_as_orchestrated``` in the class definition like this:

```ruby
class StatementGenerator

  acts_as_orchestrated

  def generate(statement_id)
  ...
  end

  def render(statement_id)
  ...
  end

end
```

Declaring ```acts_as_orchestrated``` on your class gives it two methods:

* ```orchestrated```—call this to specify your workflow prerequisite, and designate a workflow step
* ```orchestration```—call this in the context of a workflow step (execution) to access orchestration (and prerequisite) context

After that you can orchestrate any method on such a class. Let's say you needed to download files from a remote system (a slow process), transform each one, and then load it into your system. Imagine you had had a Downloader class that knew how to download and an Xform class that knew how to transform the downloaded file and load it into your system. You might write an orchestration like this:

```ruby
xform = Xform.new
xform.orchestrated(
  xform.orchestrated(
    Downloader.new.orchestrated.download(
      :from=>'http://foo.bar.com/customer_fred', :to=>'fred_file'
    )
  ).transform('fred_file', 'fred_file_processed')
).load('fred_file_processed')
```

The next time you process a delayed job, the :download message will be delivered to a Downloader. After the download is complete, the next time a delayed job is processed, the :transform message will be delivered to an Xform object.

What happened there? The pattern is:

1. create an orchestrated object (instantiate it)
2. call orchestrated on it: this returns an "orchestration"
3. send a message to the orchestration (returned in the second step)

Now the messages you can send in (3) are limited to the messages that your object can respond to. The message will be remembered by the framework and "replayed" (on a new instance of your object) somewhere on the network (later).

Not accidentally, this is similar to the way [delayed_job](https://github.com/collectiveidea/delayed_job)'s delay method works. Under the covers, orchestrated is conspiring with [delayed_job](https://github.com/collectiveidea/delayed_job) when it comes time to actually execute a workflow step. Before that time though, orchestrated keeps track of everything.

Key Concept: Prerequisites (Completion Expressions)
---------------------------------------------------

Unlike [delayed_job](https://github.com/collectiveidea/delayed_job) ```delay```, the orchestrated ```orchestrated``` method takes an optional parameter: the prerequisite. The prerequisite determines when your workflow step is ready to run.

The return value from "orchestrate" is itself a ready-to-use prerequisite. You saw this in the statement generation example above. The result of the first ```orchestrated``` call was sent as an argument to the second. In this way, the second workflow step was suspended until after the first one finished. You may have also noticed from that example that if you specify no prerequisite then the step will be ready to run immediately, as was the case for the "generate" call).

There are five kinds of prerequisite in all. Some of them are used for combining others. The prerequisites types, also known as "completion expressions" are:

1. ```OrchestrationCompletion```—returned by "orchestrate", complete when its associated orchestration is complete
2. ```Complete```—always complete
3. ```FirstCompletion```—aggregates other completions: complete after the first one completes
4. ```LastCompletion```—aggregates other completions: complete after all of them are complete

See the completion_spec for examples of how to combine these different prerequisite types into completion expressions.

Key Concept: Orchestration State
--------------------------------

An orchestration can be in one of six (6) states:

![Alt text](https://github.com/paydici/orchestrated/raw/master/Orchestrated::Orchestration_state.png 'Orchestration States')

You'll never see an orchestration in the "new" state, it's for internal use in the framework. But all the others are interesting.

When you create a new orchestration that is waiting on a prerequisite that is not complete yet, the orchestration will be in the "waiting" state. Some time later, if that prerequisite completes, then your orchestration will become "ready". A "ready" orchestration is automatically queued to run by the framework (via [delayed_job](https://github.com/collectiveidea/delayed_job)).

A "ready" orchestration will use [delayed_job](https://github.com/collectiveidea/delayed_job) to delivery its (delayed) message. In the context of such a message delivery (inside your object method e.g. StatementGenerator#generate or StatementGenerator#render) you can rely on the ability to access the current Orchestration (context) object via the "orchestration" accessor.

After your workflow step executes, the orchestration moves into either the "succeeded" or "failed" state.

When an orchestration is "ready" or "waiting" it may be canceled by sending it the ```cancel!``` message. This moves it to the "canceled" state and prevents delivery of the orchestrated message (in the future).

It is important to understand that both of the states: "succeeded" and "failed" are part of a "super-state": "complete". When an orchestration is in either of those two states, it will return ```true``` in response to the ```complete?``` message.

It is not just successful completion of orchestrated methods that causes dependent ones to run—a "failed" orchestration is complete too! If you have an orchestration that actually requires successful completion of its prerequisite then it can inspect the prerequisite as needed. It's accessible through the ```orchestration`` accessor (on the orchestrated object).

Failure (An Option)
-------------------

Orchestration is built atop [delayed_job](https://github.com/collectiveidea/delayed_job) and borrows [delayed_job](https://github.com/collectiveidea/delayed_job)'s failure semantics. Neither framework imposes any special constraints on the (delayed or orchestrated) methods. In particular, there are no special return values to signal "failure". Orchestration adopts [delayed_job](https://github.com/collectiveidea/delayed_job)'s semantics for failure detection: a method that raises an exception has failed. After a certain number of retries (configurable in [delayed_job](https://github.com/collectiveidea/delayed_job)) the jobs is deemed permanently failed. When that happens, the corresponding orchestration is marked "failed".

See the failure_spec if you'd like to understand more.

Cancelling an Orchestration
---------------------------

An orchestration can be canceled by sending the (orchestration completion) the ```cancel!``` message. This will prevent the orchestrated method from running (in the future). It will also cancel dependent workflow steps.

The cancellation_spec spells out more of the details.

Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
