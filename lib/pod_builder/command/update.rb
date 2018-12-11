require 'pod_builder/core'
require 'cfpropertylist'

module PodBuilder
  module Command
    class Update
      def self.call(options)          
        Configuration.check_inited
        PodBuilder::prepare_basepath
        
        podfile_path = PodBuilder::basepath("Podfile.restore")
        podfile_content = File.read(podfile_path)
        
        pod_entries = []
        podfile_content.each_line do |line|
          if pod_entry = pod_entry_in(line)
            if line.match(/(pb<)(.*?)(>)/) # is not prebuilt
              pod_entries.push(pod_entry)
            end
          end
        end
        
        pod_entries.uniq!
        
        Dir.glob(PodBuilder::basepath("Rome/**/*.framework")) do |framework_path|
          framework_name = File.basename(framework_path)
          plist_filename = File.join(framework_path, Configuration.framework_plist_filename)
          unless File.exist?(plist_filename)
            raise "Unable to extract item info for framework #{framework_name}. Please rebuild the framework manually!\n".red
          end
          
          plist = CFPropertyList::List.new(:file => plist_filename)
          data = CFPropertyList.native_types(plist.value)

          matches = data['entry'].gsub(" ", "").match(/(^pod')(.*?)(')(.*)/)
          raise "Unexpected error\n".red if matches&.size != 5          
          delete_regex = matches[1] + matches[2].split("/").first + matches[3]

          if data['is_prebuilt'] == false
            delete_regex += matches[4] 
          end

          pod_entries.select! { |x| x.match(delete_regex) == nil }
        end
        
        unless pod_entries.count > 0
          puts "Frameworks in sync!\n".green
          return true
        end

        ARGV.clear
        pod_entries.each { |x|
          matches = x.match(/(^pod')(.*?)(')/)
          raise "Unexpected error\n".red if matches&.size != 4          
          ARGV << matches[2]
        }

        options[:auto_resolve_dependencies] = true
        PodBuilder::Command::Build.call(options)
        
        # TODO: add auto dependencies resolution
      end        
      
     private
      
      def self.pod_entry_in(line)
        stripped_line = line.gsub("\"", "'").gsub(" ", "").gsub("\t", "").gsub("\n", "")
        matches = stripped_line.match(/(^pod')(.*?)(')(.*)/)
        
        if matches&.size == 5
          entry = matches[1] + matches[2].split("/").first + matches[3] + matches[4]
          return entry.split("#pb<").first
        else
          return nil
        end
      end
    end
  end
end