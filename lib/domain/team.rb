module VolgaCTF
  module Final
    module Domain
      def self.team(name, &block)
        team_dsl = TeamDSL.new name
        team_dsl.instance_eval &block
        @_teams << team_dsl.team
      end

      def self.get_teams
        @_teams
      end

      class Team
        attr_accessor :alias, :name, :network, :guest

        def initialize(team_alias)
          @alias = team_alias
          @name = name
          @network = nil
          @guest = false
        end
      end

      class TeamDSL
        attr_reader :team

        def initialize(team_alias)
          @team = Team.new team_alias
        end

        def name(name)
          @team.name = name
        end

        def network(network)
          @team.network = network
        end

        def guest(guest)
          @team.guest = guest
        end
      end

      protected
      @_teams = []
    end
  end
end
