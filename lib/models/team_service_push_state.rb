require 'sequel'

module Themis
  module Finals
    module Models
      class TeamServicePushState < ::Sequel::Model
        many_to_one :service
        many_to_one :team
      end
    end
  end
end