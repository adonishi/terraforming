# require "pp"
module Terraforming
  module Resource
    class CloudWatchEvent
      include Terraforming::Util

      def self.tf(client: Aws::CloudWatchEvents::Client.new)
        self.new(client).tf
      end

      def self.tfstate(client: Aws::CloudWatchEvents::Client.new)
        self.new(client).tfstate
      end

      def initialize(client)
        @client = client
        @names = []
      end

      def tf
        apply_template(@client, "tf/cloud_watch_event")
      end

      def tfstate
        rules.inject({}) do |resources, rule|
          resources["aws_cloudwatch_event_rule.#{module_name_of(rule)}"] = {
            "type" => "aws_cloudwatch_metric_event",
            "primary" => {
              "id" => rule.name,
              "attributes" => rule_attributes(rule)
            }
          }
          targets_for_rule(rule.name).each do |target|
            attributes = target.to_h
            attributes["rule"] = rule.name
            attributes["target_id"] = attributes.delete(:id)
            attributes["id"] = attributes["rule"] + "-" + attributes["target_id"]
            # TODO: support for other nested values

            resources["aws_cloudwatch_event_target.#{module_name_of(target)}"] = {
              "type" => "aws_cloudwatch_event_target",
              "primary" => {
                "id" => target.id,
                "attributes" => attributes
              }
            }
          end
          resources
        end
      end

      private

      def rule_attributes(rule)
        {
          "id" => rule.name,
          "name" => rule.name,
          "description" => rule.description,
          "schedule_expression" => rule.schedule_expression,
          "is_enabled" => (rule.state != 'DISABLED') ? 'true' : 'false',
          "event_pattern" => rule.event_pattern
        }
      end

      def rules
        events = @client.list_rules.rules.map { |r| r[:name] }
        events.map { |e| @client.describe_rule({ name: e }) }
      end

      def targets_for_rule(rule)
        @client.list_targets_by_rule({ rule: rule }).targets
      end

      def module_name_of(event)
        id = event.to_h[:name] || event.to_h[:id]
        name = normalize_module_name(id)
        name = 'id' + name if name =~ /\A[\-\d]/
        name += 'a' while @names.include? name
        @names << name
        name
      end
    end
  end
end
