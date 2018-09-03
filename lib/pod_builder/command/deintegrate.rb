require 'pod_builder/core'

module PodBuilder
  module Command
    class Deintegrate
      def self.call(options)
        raise "\n\nPodBuilder not initialized!\n".red if !Configuration.exists

        prebuilt_podfile = File.join(Configuration.base_path, "Podfile")
        restored_podfile = File.join(PodBuilder::project_path, "Podfile")

        FileUtils.cp(prebuilt_podfile, restored_podfile)

        podfile_content = File.read(restored_podfile)
        podfile_lines = []
        pre_install_indx = -1
        podfile_content.each_line.with_index do |line, index|
          if Podfile::PODBUILDER_LOCK_ACTION.detect { |x| Podfile::strip_line(x) == Podfile::strip_line(line) }
            if pre_install_indx == -1
              pre_install_indx = index
            end
          else
            podfile_lines.push(line)
          end
        end

        if pre_install_indx > 0 &&
           Podfile::strip_line(podfile_lines[pre_install_indx - 1]).include?("pre_installdo|") &&
           Podfile::strip_line(podfile_lines[pre_install_indx]) == "end"
           podfile_lines.delete_at(pre_install_indx)
           podfile_lines.delete_at(pre_install_indx - 1)
        end

        FileUtils.rm_f(restored_podfile)
        File.write(restored_podfile, podfile_lines.join)
        Podfile.update_path_entires(restored_podfile, false)
        Podfile.update_project_entries(restored_podfile, false)

        PodBuilder::safe_rm_rf(Configuration.base_path)

        Dir.chdir(PodBuilder::project_path)
        system("pod install;")  

        license_base = PodBuilder::project_path(Configuration.license_filename)
        FileUtils.rm_f("#{license_base}.plist")
        FileUtils.rm_f("#{license_base}.md")

        puts "\n\n🎉 done!\n".green
        return true
      end
    end
  end
end
