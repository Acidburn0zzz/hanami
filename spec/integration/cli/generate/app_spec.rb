# frozen_string_literal: true

require "hanami/utils/string"

RSpec.describe "hanami generate", type: :integration do
  describe "app" do
    context "with app name" do
      it_behaves_like "a new app" do
        let(:input) { "admin" }
      end
    end

    context "with underscored app name" do
      it_behaves_like "a new app" do
        let(:input) { "cool_app" }
      end
    end

    context "with dashed app name" do
      it_behaves_like "a new app" do
        let(:input) { "awesome-app" }
      end
    end

    context "with camel case app name" do
      it_behaves_like "a new app" do
        let(:input) { "CaMElAPp" }
      end
    end

    context "without require_relative" do
      it "generates app" do
        with_project("bookshelf_generate_app_without_require_relative") do
          app      = "no_req_relative"
          app_name = Hanami::Utils::String.new(app).classify
          output   = [
            "insert  config/environment.rb"
          ]

          File.write(
            "config/environment.rb",
            File
              .read("config/environment.rb")
              .lines
              .reject { |l| l[/^require_relative '.*'\n$/] }
              .reject { |l| l[/^  mount Web::App, at: '\/'\n$/] }
              .join("")
          )

          run_cmd "hanami generate app #{app}", output

          #
          # config/environment.rb
          #
          expect("config/environment.rb").to have_file_content(%r{require_relative '../apps/#{app}/app'})
          expect("config/environment.rb").to have_file_content(%r{mount #{app_name}::App, at: '/no_req_relative'})
        end
      end
    end

    context "--app-base-url" do
      it "generates app" do
        with_project("bookshelf_generate_app_app_base_url") do
          app      = "api"
          app_name = Hanami::Utils::String.new(app).classify
          output   = [
            "insert  config/environment.rb"
          ]

          run_cmd "hanami generate app #{app} --app-base-url=/api/v1", output

          #
          # config/environment.rb
          #
          expect("config/environment.rb").to have_file_content(%r{require_relative '../apps/#{app}/app'})
          expect("config/environment.rb").to have_file_content(%r{mount #{app_name}::App, at: '/api/v1'})
        end
      end

      it "fails with missing argument" do
        with_project("bookshelf_generate_app_missing_app_base_url") do
          output = "`' is not a valid URL"
          run_cmd "hanami generate app foo --app-base-url=", output, exit_status: 1
        end
      end
    end

    context "erb" do
      it "generates app" do
        with_project("bookshelf_generate_app_erb", template: :erb) do
          app      = "admin"
          app_name = Hanami::Utils::String.new(app).classify
          output   = [
            "create  apps/#{app}/templates/app.html.erb"
          ]

          run_cmd "hanami generate app #{app}", output

          #
          # apps/admin/templates/app.html.erb
          #
          expect("apps/admin/templates/app.html.erb").to have_file_content <<~END
            <!DOCTYPE html>
            <html>
              <head>
                <title>#{app_name}</title>
                <%= favicon %>
              </head>
              <body>
                <%= yield %>
              </body>
            </html>
          END
          #
          # spec/admin/views/app_layout_spec.rb
          #
          expect("spec/admin/views/app_layout_spec.rb").to have_file_content(%r{Admin::Views::AppLayout})
        end
      end
    end # erb

    context "haml" do
      it "generates app" do
        with_project("bookshelf_generate_app_haml", template: :haml) do
          app      = "admin"
          app_name = Hanami::Utils::String.new(app).classify
          output   = [
            "create  apps/#{app}/templates/app.html.haml"
          ]

          run_cmd "hanami generate app #{app}", output

          #
          # apps/admin/templates/app.html.haml
          #
          expect("apps/admin/templates/app.html.haml").to have_file_content <<~END
            !!!
            %html
              %head
                %title #{app_name}
                = favicon
              %body
                = yield
          END

          #
          # spec/admin/views/app_layout_spec.rb
          #
          expect("spec/admin/views/app_layout_spec.rb").to have_file_content(%r{Admin::Views::AppLayout})
        end
      end
    end # haml

    context "slim" do
      it "generates app" do
        with_project("bookshelf_generate_app_slim", template: :slim) do
          app      = "admin"
          app_name = Hanami::Utils::String.new(app).classify
          output   = [
            "create  apps/#{app}/templates/app.html.slim"
          ]

          run_cmd "hanami generate app #{app}", output

          #
          # apps/admin/templates/app.html.slim
          #
          expect("apps/admin/templates/app.html.slim").to have_file_content <<~END
            doctype html
            html
              head
                title
                  | #{app_name}
                = favicon
              body
                = yield
          END

          #
          # spec/admin/views/app_layout_spec.rb
          #
          expect("spec/admin/views/app_layout_spec.rb").to have_file_content(%r{Admin::Views::AppLayout})
        end
      end
    end # slim

    it "prints help message" do
      with_project do
        output = <<~OUT
Command:
  hanami generate app

Usage:
  hanami generate app APP

Description:
  Generate an app

Arguments:
  APP                               # REQUIRED The app name (eg. `web`)

Options:
  --app-base-url=VALUE      # The app base URL (eg. `/api/v1`)
  --help, -h                        # Print this help

Examples:
  hanami generate app admin                              # Generate `admin` app
  hanami generate app api --app-base-url=/api/v1 # Generate `api` app and mount at `/api/v1`
OUT

        run_cmd 'hanami generate app --help', output
      end
    end
  end # app
end
