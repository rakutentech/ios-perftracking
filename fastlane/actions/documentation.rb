require 'fileutils'

module Fastlane
  module Actions
    class DocumentationAction < Action
      def self.run(params)
        module_name = params[:module_name]
        module_version = params[:module_version]

        UI.message("Generate documentation for #{module_name}-#{module_version}")

        array = module_version.split(/[.]/)
        short_version = array[0] + "." + array[1]

        doc_dir = module_name + "-" + short_version
        UI.message("documentation directory name: #{doc_dir}")

        Dir.chdir(ENV['WORKSPACE']) do
          FileUtils.mkdir_p('artifacts/docs')
          FileUtils.remove_dir 'artifacts/Documentation', :force => true
          sh("red-gendoc")
          FileUtils.mv 'documentation', "artifacts/docs/#{doc_dir}", :force => true
        end

      end

      def self.description
        "Generate documentation for sdk module"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :module_name,
                                       description: "name of the module"
                                       ),
          FastlaneCore::ConfigItem.new(key: :module_version,
                                       description: "version of the module"
                                       )
        ]
      end

      def self.output
      end

      def self.authors
        ["vietta"]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end

# vim:syntax=ruby:et:sts=2:sw=2:ts=2:ff=unix:
