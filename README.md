# Sidekiq::Corral

A [Sidekiq](https://github.com/sidekiq/sidekiq) add-on that makes it easy to keep the processing for a job and all of the jobs it enqueues on a single queue.

## But Why?
Imagine a situation where you need to introduce a new Sidekiq job to do a specific task. But because you're working with a good bit of data, you split up the work into a bunch of small, idempotent jobs, as Sidekiq suggests. And you even go a step further, putting this new job class on its own queue to avoid clogging up one of your standard queues with these specialized jobs.

But these new jobs hardly ever live in isolation. In your existing application you're probably enqueuing jobs from a wide variety of places. And that's great until you realize that your new job enqueues a handful of these preexisting jobs based on lifecycle events or something else a few call sites away from the new job itself. This can quickly lead to a situation where the new jobs are on their own queue, as you intended, but as you churn through enough of them, the other jobs they enqueue start to fill up your other queues!

Wouldn't it be nice to be able to tell a job that not only does it go on a certain queue, but any other job that's enqueued while it's being processed should _also_ go on that same queue, ensuring that all work related to the initial job is processed separately from the other jobs in your application?

That's exactly where Sidekiq::Corral comes in!

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add sidekiq-corral

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install sidekiq-corral
    
Install the middleware on application boot (e.g. in a Rails initializer or wherever you're configuring other parts of Sidekiq):

```ruby
# config/initializers/sidekiq.rb

Sidekiq::Corral.install
```

This will register the included middleware in the right spots.

## Usage

### Sidekiq::Job.set
Set the corral when enqueueing a job:

```ruby
SomeJob.set(corral: "backfill").perform_async(args)
```

This will both set the corral and the queue for that job and any job enqueued during processing of that `SomeJob` instance.

### Sidekiq::Corral.confine
If you're enqueueing multiple jobs or calling classes that enqueue jobs of their own and you want to confine everything to a single queue, you can use `Sidekiq::Corral.confine`:

```ruby
Sidekiq::Corral.confne("backfill") do
  SomeJob.perform_async(args)
  ClassThatEnqueuesJobs.new.call(more_args)
  AnotherJob.peform_async(even_more_args) 
end
```

All jobs enqueued within that block (including those enqueued in `ClassThatEnqueuesJobs`, etc.) will be put in the `"backfill"` corral and processed on the `"backfill"` queue.


### Exempt Queues

Sometimes a queue is special enough that you always want jobs destined for it to _always_ be processed there, regardless of Sidekiq::Corral's concerns. You can name those queues on setup:

```ruby
Sidekiq::Corral.install(exempt_queues: ["notifications"])
```

Doing this will ensure anything destined for the `"notifications"` queue will be processed there. But those jobs will still pass along the corral set either on the job or further up the chain.  So any jobs enqueued while it's processing will use the corral.

For example, given this set of jobs:

```ruby
class NormalJob
  include Sidekiq::Job
  sidekiq_options queue: "default"
  
  def perform
    SpecialJob.perform_async
  end
end

class SpecialJob
  include Sidekiq::Job
  sidekiq_options queue: "notifications"
  
  def peform
    AnotherNormalJob.perform_async
  end
end

class AnotherNormalJob
  include Sidekiq::Job
  sidekiq_options queue: "default"
  
  def perform
  end
end
```

Enqueuing the NormalJob with a corral would get processed like so:

```ruby
NormalJob.set(corral: "backfill").perform_async

NormalJob               # queue: "backfill"       corral: "backfill"
-> SpecialJob           # queue: "notifications"  corral: "backfill"
   -> AnotherNormalJob  # queue: "backfill"       corral: "backfill"
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/molawson/sidekiq-corral. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/molawson/sidekiq-corral/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Sidekiq::Corral project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/molawson/sidekiq-corral/blob/main/CODE_OF_CONDUCT.md).

