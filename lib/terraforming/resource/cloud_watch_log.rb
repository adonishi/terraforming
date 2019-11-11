require "pp"
module Terraforming
  module Resource
    class CloudWatchLog
      include Terraforming::Util

      def self.tf(client: Aws::CloudWatchLogs::Client.new)
        self.new(client).tf
      end

      def self.tfstate(client: Aws::CloudWatchLogs::Client.new)
        self.new(client).tfstate
      end

      def initialize(client)
        @client = client
        @names = []
      end

      def tf
        apply_template(@client, "tf/cloud_watch_log")
      end

      def tfstate
        groups.inject({}) do |resources, group|
          resources["aws_cloudwatch_log_group.#{module_name_of(group.log_group_name)}"] = {
            "type" => "aws_cloudwatch_log_group",
            "primary" => {
              "id" => module_name_of(group.log_group_name),
              "attributes" => group_attributes(group)
            }
          }
          streams_for_group(group).each do |stream|
            id = module_name_of(stream.log_stream_name)
            resources["aws_cloudwatch_log_stream.#{id}"] = {
              "type" => "aws_cloudwatch_log_stream",
              "primary" => {
                "id" => id,
                "attributes" => {
                  "id" => id,
                  "name" => stream.log_stream_name,
                  "log_group_name" => group.log_group_name,
                  "arn" => stream.arn
                }
              }
            }
          end
          resources
        end
      end

      private

      def group_attributes(group)
        {
          "id" => module_name_of(group.log_group_name),
          "name" => group.log_group_name,
          "arn" => group.arn,
          "kms_key_id" => group.kms_key_id
          # "retention_in_days" => group.retention_in_days
        }
      end

      def groups
        @client.describe_log_groups.log_groups
      end

      def streams_for_group(group)
        sleep 0.3 # to avoid error: Rate exceeded (Aws::CloudWatchLogs::Errors::ThrottlingException)
        @client.describe_log_streams({ log_group_name: group.log_group_name }).log_streams
      end

      def module_name_of(id)
        name = normalize_module_name(id)
        name = 'id' + name if name =~ /\A[\-\d]/
        name += 'a' while @names.include? name
        @names << name
        name
      end
    end
  end
end
