require File.expand_path(File.dirname(__FILE__) + '/check_type')

class Circonus
  class CheckType
    class Resmon < Circonus::CheckType
      Circonus::MetricScanner.register_type(:'resmon', self)

      RESMON_TYPE_TO_CIRCONUS_TYPE = {
        # TODO
        "i" => :numeric,
        "I" => :numeric,
        "l" => :numeric,
        "L" => :numeric,
        "n" => :numeric,
        "0" => :numeric, #wtf
        "s" => :text,
      }.freeze

      def all
        # Discovery via HTTP

        # TODO read SSl, path, etc from config
        url = "http://" + target + ":" + node[:resmon][:port].to_s + '/'

        xml = nil
        begin
          xml = open(url).read
        rescue Errno::ETIMEDOUT
          Chef::Log.warn("Resmon at #{target}:#{node[:resmon][:port]} timed out. Returning empty metrics list.")
          return Hash.new()
        rescue Errno::ECONNREFUSED
          Chef::Log.warn("Resmon at #{target}:#{node[:resmon][:port]} did not respond. Returning empty metrics list.")
          return Hash.new()
        end

        # pp xml
        doc = REXML::Document.new(xml)

        metric_info = Hash.new()
        doc.elements.each('ResmonResults/ResmonResult') do |result_ele|
          resmon_module = result_ele.attributes["module"]
          resmon_instance = result_ele.attributes["service"]
          prefix = resmon_module + '`' + resmon_instance

          # Every resmon metric has a numeric 'duration' metric
          metric_info[prefix + '`duration'] = { :label => prefix + '`duration', :type => :numeric }

          result_ele.elements.each('metric') do |metric_ele|
            name = prefix + '`' + metric_ele.attributes["name"]
            metric_info[name] = { :label => name, :type => RESMON_TYPE_TO_CIRCONUS_TYPE[metric_ele.attributes["type"]] }
          end
        end

        # pp metric_info
        return metric_info
      end
    end
  end
end
