# Track deprecation warnings in test environment as early as possible, but pause processing of
# deprecations until all plugins are registered (prior to the finisher_hook initializer) to ensure
# the whitelist is fully configured. This is done in the after_initialize block below.
ASDeprecationTracker.pause!

Foreman::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  # Disable reloading for integration tests
  config.cache_classes = ARGV.grep(/test\/integration/).any?

  config.eager_load = true

  # Configure static asset server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {'Cache-Control' => 'public, max-age=3600'}

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = true
  ActionMailer::Base.deliveries.clear

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Should ANSI color codes be used when logging information
  config.colorize_logging = Foreman::Logging.config[:colorize]

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # log on mass assignment of unfiltered parameters
  config.action_controller.action_on_unpermitted_parameters = :log

  # Use default memory cache (32 MB top)
  config.cache_store = :memory_store

  # Enable automatic creation/migration of the test DB when running tests
  config.active_record.maintain_test_schema = true

  # Randomize the order test cases are executed.
  config.active_support.test_order = :random

  # Whitelist all plugin engines by default from raising errors on deprecation warnings for
  # compatibility, allow them to override it by adding an ASDT configuration file.
  config.after_initialize do
    Foreman::Plugin.all.each do |plugin|
      unless File.exist?(File.join(plugin.path, 'config', 'as_deprecation_whitelist.yaml'))
        ASDeprecationTracker.whitelist.add(engine: plugin.id.to_s.tr('-', '_'))
      end
    end
    ASDeprecationTracker.resume!
  end
end
