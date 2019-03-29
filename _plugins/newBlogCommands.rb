module Octopress

  Post.class_eval do
    def path
      name = @options['path'] || "#{date_slug}-#{title_slug}.#{extension}"
      dir = File.join(site.source, '_posts', @options['dir'])
      FileUtils.mkdir_p dir
      File.join(dir, name)
    end
  end

  class NewPost < NewCommand

    def self.init_with_command(c)
      c.command(:post) do |c|
        c.syntax 'post [options]'
        c.description 'Add a new post to your Jekyll site.'
        c.option 'title', '-t', '--title TITLE', 'String to be added as the title in the YAML front-matter.'
        NewCommand.add_page_options c
        NewCommand.add_common_options c

        c.action do |args, options|
          options['title'] =
            Readline.readline( "Title: ", true) unless
            options.has_key?('title')
          options['path'] = createFileNameFromDateTitle(options)
          require 'pp'
          pp options
          Post.new(Octopress.site(options), options).write unless
            File.exists?(options['path'])
          system("nano +10 _posts/#{options['path']}")
        end
      end
    end

    def self.createFileNameFromDateTitle(options)
      title   = createFileNameFromTitle(options)
      date    = Date.today.strftime("%Y-%m-%d")
      dateDir = Date.today.strftime("%Y/%m")
      dateDir + '/' + date + '-' + title
    end

  end
end
