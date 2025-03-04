# frozen_string_literal: true

RSpec.describe "assets", type: :integration do
  describe "helpers" do
    it "renders assets tags" do
      with_project do
        generate "action web home#index --url=/"

        rewrite "apps/web/templates/app.html.erb", <<~EOF
          <!DOCTYPE html>
          <html>
            <head>
              <title>Web</title>
              <%= favicon %>
              <%= stylesheet 'app' %>
            </head>
            <body>
              <%= yield %>
              <%= javascript 'app' %>
            </body>
          </html>
        EOF

        rewrite "apps/web/templates/home/index.html.erb", <<~EOF
          <%= image('app.jpg') %>
          <%= video('movie.mp4') %>
          <%=
          video do
            text "Your browser does not support the video tag"
            source src: view.asset_path('movie.mp4'), type: 'video/mp4'
            source src: view.asset_path('movie.ogg'), type: 'video/ogg'
          end
          %>
        EOF

        server do
          visit "/"

          expect(page.body).to include(%(<link href="/assets/favicon.ico" rel="shortcut icon" type="image/x-icon">))
          expect(page.body).to include(%(<link href="/assets/app.css" type="text/css" rel="stylesheet">))
          expect(page.body).to include(%(<script src="/assets/app.js" type="text/javascript"></script>))

          expect(page.body).to include(%(<img src="/assets/app.jpg" alt="App">))
          expect(page.body).to include(%(<video src="/assets/movie.mp4"></video>))
          expect(page.body).to include(%(<video>\nYour browser does not support the video tag\n<source src="/assets/movie.mp4" type="video/mp4">\n<source src="/assets/movie.ogg" type="video/ogg">\n</video>))
        end
      end
    end
  end
end
