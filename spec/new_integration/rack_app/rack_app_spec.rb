# frozen_string_literal: true

require "rack/test"

RSpec.describe "Hanami web app", :app_integration do
  include Rack::Test::Methods

  let(:app) { Hanami.app }

  specify "Hanami.app returns a rack builder" do
    with_tmp_directory do
      write "config/app.rb", <<~RUBY
        require "hanami"

        module TestApp
          class App < Hanami::App
          end
        end
      RUBY

      write "config/routes.rb", <<~RUBY
        module TestApp
          class Routes < Hanami::Routes
            define do
              root to: ->(env) { [200, {}, ["OK"]] }
            end
          end
        end
      RUBY

      require "hanami/boot"

      expect(app).to be(TestApp::App)
    end
  end

  specify "Has rack monitor preconfigured with default request logging" do
    dir = Dir.mktmpdir

    with_tmp_directory(dir) do
      write "config/app.rb", <<~RUBY
        require "hanami"

        module TestApp
          class App < Hanami::App
            config.logger.stream = config.root.join("test.log")
          end
        end
      RUBY

      write "config/routes.rb", <<~RUBY
        module TestApp
          class Routes < Hanami::Routes
            define do
            end
          end
        end
      RUBY

      require "hanami/boot"

      expect(Hanami.app["rack.monitor"]).to be_instance_of(Dry::Monitor::Rack::Middleware)

      get "/"

      logs = -> { Pathname(dir).join("test.log").realpath.read }

      expect(logs.()).to match %r{GET 404 \d+ms 127.0.0.1 /}
    end
  end

  describe "Request logging when using a slice" do
    let(:app) { Main::Slice.rack_app }

    specify "Has rack monitor preconfigured with default request logging (when used via a slice)" do
      dir = Dir.mktmpdir

      with_tmp_directory(dir) do
        write "config/app.rb", <<~RUBY
          require "hanami"

          module TestApp
            class App < Hanami::App
              config.logger.stream = config.root.join("test.log")
            end
          end
        RUBY

        write "slices/main/config/routes.rb", <<~RUBY
          module Main
            class Routes < Hanami::Routes
              define do
              end
            end
          end
        RUBY

        require "hanami/boot"

        get "/"

        logs = -> { Pathname(dir).join("test.log").realpath.read }

        expect(logs.()).to match %r{GET 404 \d+ms 127.0.0.1 /}
      end
    end
  end

  specify "Routing to actions based on their container identifiers" do
    with_tmp_directory(Dir.mktmpdir) do
      write "config/app.rb", <<~RUBY
        require "hanami"

        module TestApp
          class App < Hanami::App
            config.logger.stream = File.new("/dev/null", "w")
          end
        end
      RUBY

      write "config/routes.rb", <<~RUBY
        module TestApp
          class Routes < Hanami::Routes
            define do
              get "/health", to: "health.show"

              get "/inline" do
                "Inline"
              end

              slice :main, at: "/" do
                root to: "home.index"
              end

              slice :admin, at: "/admin" do
                get "/dashboard", to: "dashboard.show"
              end
            end
          end
        end
      RUBY

      write "app/actions/health/show.rb", <<~RUBY
        require "hanami/action"

        module TestApp
          module Actions
            module Health
              class Show < Hanami::Action
                def handle(*, res)
                  res.body = "Health, OK"
                end
              end
            end
          end
        end
      RUBY

      write "slices/main/actions/home/index.rb", <<~RUBY
        require "hanami/action"

        module Main
          module Actions
            module Home
              class Index < Hanami::Action
                def handle(*, res)
                  res.body = "Hello world"
                end
              end
            end
          end
        end
      RUBY

      write "slices/admin/actions/dashboard/show.rb", <<~RUBY
        require "hanami/action"

        module Admin
          module Actions
            module Dashboard
              class Show < Hanami::Action
                def handle(*, res)
                  res.body = "Admin dashboard here"
                end
              end
            end
          end
        end
      RUBY

      require "hanami/boot"

      get "/"

      expect(last_response.status).to eq 200
      expect(last_response.body).to eq "Hello world"

      get "/inline"

      expect(last_response.status).to eq 200
      expect(last_response.body).to eq "Inline"

      get "/health"

      expect(last_response.status).to eq 200
      expect(last_response.body).to eq "Health, OK"

      get "/admin/dashboard"

      expect(last_response.status).to eq 200
      expect(last_response.body).to eq "Admin dashboard here"
    end
  end

  # TODO: is this test even needed, given this is standard hanami-router behavior?
  specify "It gives priority to the last declared route" do
    with_tmp_directory(Dir.mktmpdir) do
      write "config/app.rb", <<~RUBY
        require "hanami"

        module TestApp
          class App < Hanami::App
            config.logger.stream = File.new("/dev/null", "w")
          end
        end
      RUBY

      write "config/routes.rb", <<~RUBY
        module TestApp
          class Routes < Hanami::Routes
            define do
              root to: "home.index"

              slice :main, at: "/" do
                root to: "home.index"
              end
            end
          end
        end
      RUBY

      write "app/actions/home/index.rb", <<~RUBY
        require "hanami/action"

        module TestApp
          module Actions
            module Home
              class Index < Hanami::Action
                def handle(*, res)
                  res.body = "Hello from App"
                end
              end
            end
          end
        end
      RUBY

      write "slices/main/actions/home/index.rb", <<~RUBY
        require "hanami/action"

        module Main
          module Actions
            module Home
              class Index < Hanami::Action
                def handle(*, res)
                  res.body = "Hello from Slice"
                end
              end
            end
          end
        end
      RUBY

      require "hanami/boot"

      get "/"

      expect(last_response.status).to eq 200
      expect(last_response.body).to eq "Hello from Slice"
    end
  end

  specify "It does not choose actions from slice to route in app" do
    with_tmp_directory(Dir.mktmpdir) do
      write "config/app.rb", <<~RUBY
        require "hanami"

        module TestApp
          class App < Hanami::App
            config.logger.stream = File.new("/dev/null", "w")
          end
        end
      RUBY

      write "config/routes.rb", <<~RUBY
        module TestApp
          class Routes < Hanami::Routes
            define do
              get "/feedbacks", to: "feedbacks.index"

              slice :api, at: "/api" do
                get "/people", to: "people.index"
              end
            end
          end
        end
      RUBY

      write "app/action.rb", <<~RUBY
        # auto_register: false
        require "hanami/action"

        module TestApp
          class Action < Hanami::Action
          end
        end
      RUBY

      write "app/actions/feedbacks/index.rb", <<~RUBY
        module TestApp
          module Actions
            module Feedbacks
              class Index < TestApp::Action
                def handle(*, res)
                  res.body = "Feedbacks"
                end
              end
            end
          end
        end
      RUBY

      write "slices/api/action.rb", <<~RUBY
        module API
          class Action < TestApp::Action
          end
        end
      RUBY

      write "slices/api/actions/people/index.rb", <<~RUBY
        module API
          module Actions
            module People
              class Index < API::Action
                def handle(*, res)
                  res.body = "People"
                end
              end
            end
          end
        end
      RUBY

      require "hanami/boot"

      get "/api/people"

      expect(last_response.status).to eq 200
      expect(last_response.body).to eq "People"
    end
  end

  specify "For a booted app, rack_app raises an exception if a referenced action isn't registered in the app" do
    with_tmp_directory(Dir.mktmpdir) do
      write "config/app.rb", <<~RUBY
        require "hanami"

        module TestApp
          class App < Hanami::App
          end
        end
      RUBY

      write "config/routes.rb", <<~RUBY
        module TestApp
          class Routes < Hanami::Routes
            define do
              get "/missing", to: "missing.action"
            end
          end
        end
      RUBY

      require "hanami/boot"

      expect { Hanami.app.rack_app }.to raise_error do |exception|
        expect(exception).to be_kind_of(Hanami::Slice::Routing::UnknownActionError)
        expect(exception.message).to include("missing.action")
      end
    end
  end

  specify "For a booted app, rack_app raises an error if a referenced action isn't registered in a slice" do
    with_tmp_directory(Dir.mktmpdir) do
      write "config/app.rb", <<~RUBY
        require "hanami"

        module TestApp
          class App < Hanami::App
            register_slice :admin
          end
        end
      RUBY

      write "config/routes.rb", <<~RUBY
        module TestApp
          class Routes < Hanami::Routes
            define do
              slice :admin, at: "/admin" do
                get "/missing", to: "missing.action"
              end
            end
          end
        end
      RUBY

      require "hanami/boot"

      expect { Hanami.app.rack_app }.to raise_error do |exception|
        expect(exception).to be_kind_of(Hanami::Slice::Routing::UnknownActionError)
        expect(exception.message).to include("missing.action")
      end
    end
  end

  specify "For a non-booted app, rack_app does not raise an error if a referenced action isn't registered in the app" do
    with_tmp_directory(Dir.mktmpdir) do
      write "config/app.rb", <<~RUBY
        require "hanami"

        module TestApp
          class App < Hanami::App
          end
        end
      RUBY

      write "config/routes.rb", <<~RUBY
        module TestApp
          class Routes < Hanami::Routes
            define do
              get "/missing", to: "missing.action"
            end
          end
        end
      RUBY

      require "hanami/prepare"

      expect { Hanami.app.rack_app }.not_to raise_error

      expect { get "/missing" }.to raise_error do |exception|
        expect(exception).to be_kind_of(Hanami::Slice::Routing::UnknownActionError)
        expect(exception.message).to include("missing.action")
      end
    end
  end

  specify "For a non-booted app, rack_app does not raise an error if a referenced action isn't registered in a slice" do
    with_tmp_directory(Dir.mktmpdir) do
      write "config/app.rb", <<~RUBY
        require "hanami"

        module TestApp
          class App < Hanami::App
            register_slice :admin
          end
        end
      RUBY

      write "config/routes.rb", <<~RUBY
        module TestApp
          class Routes < Hanami::Routes
            define do
              slice :admin, at: "/admin" do
                get "/missing", to: "missing.action"
              end
            end
          end
        end
      RUBY

      require "hanami/prepare"

      expect { Hanami.app.rack_app }.not_to raise_error

      expect { get "/admin/missing" }.to raise_error do |exception|
        expect(exception).to be_kind_of(Hanami::Slice::Routing::UnknownActionError)
        expect(exception.message).to include("missing.action")
      end
    end
  end

  specify "rack_app raises an error if a referenced slice is not registered" do
    with_tmp_directory(Dir.mktmpdir) do
      write "config/app.rb", <<~RUBY
        require "hanami"

        module TestApp
          class App < Hanami::App
          end
        end
      RUBY

      write "config/routes.rb", <<~RUBY
        module TestApp
          class Routes < Hanami::Routes
            define do
              slice :foo, at: "/foo" do
                get "/bar", to: "bar.index"
              end
            end
          end
        end
      RUBY

      require "hanami/prepare"

      expect { Hanami.app.rack_app }.to raise_error do |exception|
        expect(exception).to be_kind_of(Hanami::SliceLoadError)
        expect(exception.message).to include("Slice 'foo' not found")
      end
    end
  end
end
